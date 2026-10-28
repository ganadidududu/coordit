"""Pinned baseline/candidate comparison on identical real photos; explicit training overlap."""

import json
from collections import defaultdict
from pathlib import Path

import torch

from coordit_ml.artifacts import Artifact
from coordit_ml.finetuning import ParentCheckpoint, initialize
from coordit_ml.history import HistoryPin, load_history
from coordit_ml.model_factory import create_model
from coordit_ml.network import ApprovedDataset
from coordit_ml.provenance import REGISTRY_ROOT, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import LANDMARKS, BoundaryModel, PipelineError, read_registry


class SeamComparison(BoundaryModel):
    """Both hashes are fixed before evaluation; reporting never alters a parent run directory."""

    baseline: ParentCheckpoint
    candidate: ParentCheckpoint
    manifest: Path
    split: str = "train"
    output: Path
    evaluation_only_publisher_test: bool = False


class LandmarkMetric(BoundaryModel):
    """Visible labeled points only, with normalized resized-input diagonal as denominator."""

    points: int
    pck_005: float
    nme: float


class ModelScore(BoundaryModel):
    """No seam/centimeter accuracy is inferred from mask overlap."""

    checkpoint_sha256: str
    images: int
    images_seen_in_training: int
    real_images: int
    synthetic_images: int
    per_category: dict[str, LandmarkMetric]
    per_landmark: dict[str, LandmarkMetric]
    mask_iou_per_category: dict[str, float]
    macro_miou_present_categories: float | None


def score(parent: ParentCheckpoint, dataset: ApprovedDataset) -> ModelScore:
    """Revalidate source rights and compare all visible points independently of predicted visibility."""
    metadata = Artifact.model_validate_json((parent.directory / "artifact.json").read_bytes())
    model = create_model(metadata.architecture, metadata.category_heads)
    initialize(model, parent)
    _ = model.eval()
    dataset.image_size = model.input_size
    errors: dict[str, list[float]] = defaultdict(list)
    point_errors: dict[str, list[float]] = defaultdict(list)
    mask_scores: dict[str, list[float]] = defaultdict(list)
    with torch.inference_mode():
        for index, (_, record) in enumerate(dataset.samples):
            sample = dataset[index]
            prediction = model.forward(sample.pixels.unsqueeze(0))
            error = (prediction.points[0] - sample.points).square().sum(1).sqrt() / (2**0.5)
            for position, name in enumerate(LANDMARKS):
                if sample.visibility[position] > 0:
                    value = float(error[position])
                    errors[record.category].append(value)
                    point_errors[name].append(value)
            if record.segmentation_supervised:
                inferred, truth = prediction.mask[0].sigmoid() >= 0.5, sample.mask >= 0.5
                mask_scores[record.category].append(
                    float((inferred & truth).sum() / (inferred | truth).sum().clamp_min(1))
                )
    category_scores = {
        category: LandmarkMetric(
            points=len(values),
            pck_005=sum(value <= 0.05 for value in values) / len(values),
            nme=sum(values) / len(values),
        )
        for category, values in errors.items()
    }
    landmarks = {
        name: LandmarkMetric(
            points=len(values),
            pck_005=sum(value <= 0.05 for value in values) / len(values),
            nme=sum(values) / len(values),
        )
        for name, values in point_errors.items()
    }
    masks = {category: sum(values) / len(values) for category, values in mask_scores.items()}
    seen = set(metadata.seen_image_ids)
    return ModelScore(
        checkpoint_sha256=parent.checkpoint_sha256,
        images=len(dataset),
        images_seen_in_training=sum(record.image_id in seen for _, record in dataset.samples),
        real_images=sum(not record.acquisition_metadata.synthetic for _, record in dataset.samples),
        synthetic_images=sum(record.acquisition_metadata.synthetic for _, record in dataset.samples),
        per_category=category_scores,
        per_landmark=landmarks,
        mask_iou_per_category=masks,
        macro_miou_present_categories=sum(masks.values()) / len(masks) if masks else None,
    )


def compare_seams(config: SeamComparison) -> Path:
    """Training/development comparisons cannot grant independent accuracy or production approval."""
    torch.set_num_threads(2)
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    dataset = (
        PublisherTestDataset(config.manifest, registry)
        if config.evaluation_only_publisher_test
        else ApprovedDataset([config.manifest], registry, config.split)
    )
    if not len(dataset):
        raise PipelineError("Comparison split is empty")
    if config.evaluation_only_publisher_test:
        current_history = load_history(
            [
                HistoryPin(artifact=parent.directory / "artifact.json", sha256=parent.artifact_sha256)
                for parent in (config.baseline, config.candidate)
            ]
        )
        if any(current_history.overlaps(record) for _, record in dataset.samples):
            raise PipelineError("Scored model has trained on the requested test photos")
    baseline, candidate = score(config.baseline, dataset), score(config.candidate, dataset)
    result = {
        "manifest_sha256": sha256(config.manifest),
        "split": config.split,
        "coordinate_error_normalization": "128x128 resized input diagonal, not original-photo pixels or cm",
        "independent_evaluation": False,
        "reason": (
            "Unseen by recorded training history; publisher test family overlaps earlier heuristic development"
            if config.evaluation_only_publisher_test
            else "Pilot development pool; original aRTF training photos already used in earlier mask experiments"
        ),
        "baseline": baseline.model_dump(),
        "candidate": candidate.model_dump(),
        "cm_accuracy": None,
        "deployment_approved": False,
    }
    with config.output.open("x") as output:
        _ = output.write(json.dumps(result, indent=2, allow_nan=False) + "\n")
    return config.output
