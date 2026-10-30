"""Small from-scratch multi-task baseline; no pretrained weights or external model code."""

from pathlib import Path
from typing import ClassVar, NamedTuple, final, override

import numpy as np
import torch
from PIL import Image, ImageDraw
from torch import Tensor, nn
from torch.nn import functional as F
from torch.utils.data import Dataset

from coordit_ml.provenance import audit_records, check_separation
from coordit_ml.schema import CLASSES, LANDMARKS, Record, Registry


class Sample(NamedTuple):
    """One image and its masked multi-task labels."""

    pixels: Tensor
    category: Tensor
    mask: Tensor
    points: Tensor
    visibility: Tensor
    mask_supervision: Tensor


class Prediction(NamedTuple):
    """Category logits, mask logits, normalized points and visibility logits."""

    category: Tensor
    mask: Tensor
    points: Tensor
    visibility: Tensor
    heatmaps: Tensor | None = None


class ApprovedDataset(Dataset[Sample]):
    """Every sample comes from an audited, approved manifest, including evaluation samples."""

    def __init__(self, manifests: list[Path], registry: Registry, split: str) -> None:
        """Audit all corpora before exposing a tensor sample."""
        self.samples: list[tuple[Path, Record]] = []
        self.image_size: int = 64
        all_records: list[Record] = []
        for manifest in manifests:
            records = audit_records(manifest, registry)
            all_records.extend(records)
            self.samples.extend((manifest.parent, record) for record in records if record.split == split)

        check_separation(all_records)

    def __len__(self) -> int:
        """Return the number of samples in the requested split."""
        return len(self.samples)

    @override
    def __getitem__(self, index: int) -> Sample:
        root, record = self.samples[index]
        with Image.open(root / record.file_name) as image:
            pixels = image_tensor(image, self.image_size)
        if record.mask_file_name:
            with Image.open(root / record.mask_file_name) as image:
                mask = image.convert("L").resize((self.image_size, self.image_size), Image.Resampling.NEAREST)
        else:
            mask = Image.new("L", (record.width, record.height))
            for polygon in record.segmentation:
                ImageDraw.Draw(mask).polygon(list(zip(polygon[::2], polygon[1::2], strict=True)), fill=255)
            mask = mask.resize((self.image_size, self.image_size), Image.Resampling.NEAREST)
        points = torch.zeros(len(LANDMARKS), 2)
        visibility = torch.full((len(LANDMARKS),), -1.0)
        for point in record.keypoints:
            position = LANDMARKS.index(point.landmark_type)
            points[position] = torch.tensor([point.x, point.y])
            visibility[position] = float(point.visibility == 2)
        return Sample(
            pixels,
            torch.tensor(CLASSES.index(record.category)),
            torch.tensor(np.array(mask, dtype=np.float32) / 255).unsqueeze(0),
            points,
            visibility,
            torch.tensor(float(record.segmentation_supervised)),
        )


def image_tensor(image: Image.Image, size: int = 64) -> Tensor:
    """The model contract is upright RGB, top-left normalized, resized to the versioned architecture input."""
    pixels = np.array(image.convert("RGB").resize((size, size)), dtype=np.float32) / 255
    return torch.tensor(pixels).permute(2, 0, 1)


@final
class GarmentNet(nn.Module):
    """Compare shared or per-category landmark heads with identical backbone and masks."""

    input_size: ClassVar[int] = 64
    model_version: ClassVar[str] = "coordit-tiny-multitask-v1"

    def __init__(self, category_heads: bool = False) -> None:
        """Initialize every parameter randomly with the recorded architecture."""
        super().__init__()
        self.category_heads = category_heads
        self.conv1 = nn.Conv2d(3, 16, 3, 2, 1)
        self.conv2 = nn.Conv2d(16, 32, 3, 2, 1)
        self.conv3 = nn.Conv2d(32, 64, 3, 2, 1)
        self.classifier = nn.Linear(64, len(CLASSES))
        self.segmenter = nn.Conv2d(64, 1, 1)
        self.geometry = nn.Linear(64 * 8 * 8, 128)
        heads = len(CLASSES) if category_heads else 1
        self.landmarks = nn.Linear(128, heads * len(LANDMARKS) * 2)
        self.visibility = nn.Linear(128, len(LANDMARKS))

    @override
    def forward(self, pixels: Tensor, categories: Tensor | None = None) -> Prediction:
        features = F.relu(self.conv1.forward(pixels))
        features = F.relu(self.conv2.forward(features))
        features = F.relu(self.conv3.forward(features))
        classification = self.classifier.forward(features.mean(dim=(2, 3)))
        geometry = F.relu(self.geometry.forward(features.flatten(1)))
        points = self.landmarks.forward(geometry).sigmoid()
        if self.category_heads:
            heads = points.reshape(-1, len(CLASSES), len(LANDMARKS), 2)
            selected = classification.argmax(dim=1) if categories is None else categories
            points = heads[torch.arange(len(pixels), device=pixels.device), selected]
        else:
            points = points.reshape(-1, len(LANDMARKS), 2)
        return Prediction(
            classification,
            F.interpolate(self.segmenter.forward(features), size=(64, 64), mode="bilinear", align_corners=False),
            points,
            self.visibility.forward(geometry),
        )


def loss(prediction: Prediction, target: Sample) -> Tensor:
    """Unmapped publisher keypoints never become seam ground truth; occluded points stay masked."""
    visible = (target.visibility > 0).float()
    known = (target.visibility >= 0).float()
    landmark_loss = ((prediction.points - target.points).square().sum(dim=2) * visible).sum() / visible.sum().clamp_min(
        1
    )
    visibility_loss = (
        F.binary_cross_entropy_with_logits(prediction.visibility, target.visibility.clamp_min(0), reduction="none")
        * known
    ).sum() / known.sum().clamp_min(1)
    return (
        F.cross_entropy(prediction.category, target.category)
        + segmentation_loss(prediction.mask, target)
        + 5 * landmark_loss
        + 0.2 * visibility_loss
    )


def segmentation_loss(logits: Tensor, target: Sample, *, dice: bool = False) -> Tensor:
    """Missing masks produce zero supervision, never an all-background pseudo ground truth."""
    bce = F.binary_cross_entropy_with_logits(logits, target.mask, reduction="none").mean(dim=(1, 2, 3))
    if dice:
        probability = logits.sigmoid()
        overlap = (probability * target.mask).sum(dim=(1, 2, 3))
        bce = bce + 1 - (2 * overlap + 1) / (probability.sum(dim=(1, 2, 3)) + target.mask.sum(dim=(1, 2, 3)) + 1)
    return (bce * target.mask_supervision).sum() / target.mask_supervision.sum().clamp_min(1)


def batch(dataset: ApprovedDataset, indices: list[int], device: str) -> Sample:
    """Small explicit batches keep CPU smoke runs and deterministic resume reproducible."""
    samples = [dataset[index] for index in indices]
    return Sample(*(torch.stack(values).to(device) for values in zip(*samples, strict=True)))
