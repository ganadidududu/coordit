"""Spatial garment perception with skip-connected masks and semantic heatmaps."""

from typing import ClassVar, final, override

import torch
from torch import Tensor, nn
from torch.nn import functional as F

from coordit_ml.network import Prediction, Sample, segmentation_loss
from coordit_ml.schema import CLASSES, LANDMARKS, PipelineError


@final
class ConvBlock(nn.Module):
    """Preserve spatial detail with two normalized convolutions."""

    def __init__(self, incoming: int, outgoing: int) -> None:
        """Create a convolution block without any pretrained parameters."""
        super().__init__()
        self.first = nn.Conv2d(incoming, outgoing, 3, padding=1)
        self.second = nn.Conv2d(outgoing, outgoing, 3, padding=1)
        self.norm1 = nn.GroupNorm(4, outgoing)
        self.norm2 = nn.GroupNorm(4, outgoing)

    @override
    def forward(self, pixels: Tensor) -> Tensor:
        """Encode image features while retaining their pixel locations."""
        features = F.silu(self.norm1.forward(self.first.forward(pixels)))
        return F.silu(self.norm2.forward(self.second.forward(features)))


@final
class GarmentHeatmapNet(nn.Module):
    """Share a spatial encoder between category, mask and optional category-specific pose heads."""

    input_size: ClassVar[int] = 128
    model_version: ClassVar[str] = "coordit-spatial-multitask-v2"

    def __init__(self, category_heads: bool = False) -> None:
        """Initialize the encoder, skip decoder and semantic heatmap heads from scratch."""
        super().__init__()
        self.category_heads = category_heads
        self.encoder0 = ConvBlock(3, 16)
        self.encoder1 = ConvBlock(16, 32)
        self.encoder2 = ConvBlock(32, 64)
        self.encoder3 = ConvBlock(64, 96)
        self.decoder2 = ConvBlock(160, 64)
        self.decoder1 = ConvBlock(96, 32)
        self.decoder0 = ConvBlock(48, 16)
        self.classifier = nn.Linear(96 * 4 * 4, len(CLASSES))
        self.mask = nn.Conv2d(16, 1, 1)
        self.heatmap = nn.Conv2d(32, len(LANDMARKS) * (len(CLASSES) if category_heads else 1), 1)
        self.visibility = nn.Linear(96, len(LANDMARKS))

    @override
    def forward(self, pixels: Tensor, categories: Tensor | None = None) -> Prediction:
        """Return continuous normalized points and their underlying semantic heatmaps."""
        e0 = self.encoder0.forward(pixels)
        e1 = self.encoder1.forward(F.avg_pool2d(e0, 2))
        e2 = self.encoder2.forward(F.avg_pool2d(e1, 2))
        e3 = self.encoder3.forward(F.avg_pool2d(e2, 2))
        classes = self.classifier.forward(F.adaptive_avg_pool2d(e3, (4, 4)).flatten(1))
        d2 = self.decoder2.forward(
            torch.cat((F.interpolate(e3, size=e2.shape[-2:], mode="bilinear", align_corners=False), e2), dim=1)
        )
        d1 = self.decoder1.forward(
            torch.cat((F.interpolate(d2, size=e1.shape[-2:], mode="bilinear", align_corners=False), e1), dim=1)
        )
        d0 = self.decoder0.forward(
            torch.cat((F.interpolate(d1, size=e0.shape[-2:], mode="bilinear", align_corners=False), e0), dim=1)
        )
        maps = self.heatmap.forward(d1)
        if self.category_heads:
            maps = maps.reshape(-1, len(CLASSES), len(LANDMARKS), maps.shape[-2], maps.shape[-1])
            chosen = classes.argmax(1) if categories is None else categories
            maps = maps[torch.arange(pixels.shape[0], device=pixels.device), chosen]
        probability = maps.flatten(2).softmax(-1)
        height, width = maps.shape[-2:]
        y = (torch.arange(height, dtype=pixels.dtype, device=pixels.device) + 0.5) / height
        x = (torch.arange(width, dtype=pixels.dtype, device=pixels.device) + 0.5) / width
        gy, gx = torch.meshgrid(y, x, indexing="ij")
        coordinates = torch.stack(((probability * gx.flatten()).sum(-1), (probability * gy.flatten()).sum(-1)), dim=-1)
        return Prediction(
            classes, self.mask.forward(d0), coordinates, self.visibility.forward(e3.mean(dim=(2, 3))), maps
        )


def spatial_loss(prediction: Prediction, target: Sample) -> Tensor:
    """Balance foreground masks and supervise only explicitly visible semantic landmarks."""
    visible = (target.visibility > 0).float()
    known = (target.visibility >= 0).float()
    point_loss = (
        F.smooth_l1_loss(prediction.points, target.points, reduction="none").sum(-1) * visible
    ).sum() / visible.sum().clamp_min(1)
    heatmaps = prediction.heatmaps
    if heatmaps is None:
        raise PipelineError("Spatial architecture did not return heatmaps")
    height, width = heatmaps.shape[-2:]
    y = (torch.arange(height, device=heatmaps.device) + 0.5) / height
    x = (torch.arange(width, device=heatmaps.device) + 0.5) / width
    gy, gx = torch.meshgrid(y, x, indexing="ij")
    dx = gx.flatten()[None, None, :] - target.points[:, :, 0, None]
    dy = gy.flatten()[None, None, :] - target.points[:, :, 1, None]
    truth = (-(dx.square() + dy.square()) / (2 * (0.025**2))).softmax(-1)
    heatmap_loss = (-(truth * heatmaps.flatten(2).log_softmax(-1)).sum(-1) * visible).sum() / visible.sum().clamp_min(1)
    visibility_loss = (
        F.binary_cross_entropy_with_logits(prediction.visibility, target.visibility.clamp_min(0), reduction="none")
        * known
    ).sum() / known.sum().clamp_min(1)
    return (
        F.cross_entropy(prediction.category, target.category)
        + segmentation_loss(prediction.mask, target, dice=True)
        + 10 * point_loss
        + heatmap_loss
        + 0.2 * visibility_loss
    )
