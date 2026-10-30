"""Diagnostic coordinate variants on frozen public evaluation photos, never edits to ground truth."""

import json
from collections import defaultdict
from pathlib import Path

import torch
from torch import Tensor

from coordit_ml.finetuning import ParentCheckpoint, initialize
from coordit_ml.history import HistoryPin, load_history
from coordit_ml.provenance import REGISTRY_ROOT, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import LANDMARKS, BoundaryModel, PipelineError, read_registry
from coordit_ml.seam_comparison import LandmarkMetric
from coordit_ml.training import load_model


class CoordinateAudit(BoundaryModel):
    """Audit a pinned baseline without label repair or model selection approval."""

    model: ParentCheckpoint
    manifest: Path
    output: Path


def peak_coordinates(heatmaps: Tensor) -> Tensor:
    """Return heatmap-cell centers of maximum logits; diagnostic alternative to global expectation."""
    height, width = heatmaps.shape[-2:]
    indices = heatmaps.flatten(2).argmax(-1)
    return torch.stack(((indices % width + 0.5) / width, (indices // width + 0.5) / height), dim=-1)


def coordinate_variants(points: Tensor, heatmaps: Tensor) -> dict[str, Tensor]:
    """Swap endpoint names or image axes only for diagnosis, never overwrite scored labels."""
    permutation = list(range(len(LANDMARKS)))
    for left, right in (
        ("shoulder_left", "shoulder_right"),
        ("armpit_left", "armpit_right"),
        ("waist_left", "waist_right"),
        ("hip_left", "hip_right"),
    ):
        a, b = LANDMARKS.index(left), LANDMARKS.index(right)
        permutation[a], permutation[b] = b, a
    return {
        "original": points,
        "endpoint_names_swapped": points[:, permutation],
        "mirror_x": torch.stack((1 - points[..., 0], points[..., 1]), dim=-1),
        "mirror_y": torch.stack((points[..., 0], 1 - points[..., 1]), dim=-1),
        "rotate_180": 1 - points,
        "transpose_xy": points.flip(-1),
        "heatmap_argmax_diagnostic": peak_coordinates(heatmaps),
    }


def audit_coordinates(config: CoordinateAudit) -> Path:
    """Measure competing systematic-error hypotheses with identical visible targets on unchanged photos."""
    torch.set_num_threads(2)
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    dataset = PublisherTestDataset(config.manifest, registry)
    history = load_history(
        [
            HistoryPin(
                artifact=config.model.directory / "artifact.json",
                sha256=config.model.artifact_sha256,
            )
        ]
    )
    if any(history.overlaps(record) for _, record in dataset.samples):
        raise PipelineError("Coordinate diagnostic photos overlap model training")
    model = load_model(config.model.directory)
    initialize(model, config.model)
    dataset.image_size = model.input_size
    errors: dict[str, list[float]] = defaultdict(list)
    width_errors: dict[str, list[float]] = defaultdict(list)
    with torch.inference_mode():
        for index, (_, record) in enumerate(dataset.samples):
            sample = dataset[index]
            prediction = model.forward(sample.pixels.unsqueeze(0))
            if prediction.heatmaps is None:
                raise PipelineError("Coordinate diagnostics require spatial heatmaps")
            for name, variant in coordinate_variants(prediction.points, prediction.heatmaps).items():
                values = ((variant[0] - sample.points).square().sum(-1).sqrt() / (2**0.5))[sample.visibility > 0]
                errors[f"{record.category}/{name}"].extend(float(value) for value in values)
            pairs = [(a, b) for a, b in ((0, 1), (2, 3), (8, 9)) if bool((sample.visibility[[a, b]] > 0).all())]
            indices = [position for pair in pairs for position in pair]
            swapped_points = coordinate_variants(prediction.points, prediction.heatmaps)["endpoint_names_swapped"][0]
            matched_points = prediction.points[0]
            if indices and (
                (swapped_points[indices] - sample.points[indices]).square().sum()
                < (matched_points[indices] - sample.points[indices]).square().sum()
            ):
                matched_points = swapped_points
            for start, end in pairs:
                truth = sample.points[[start, end]]
                inferred = prediction.points[0, [start, end]]
                errors[f"{record.category}/ordered_bilateral_only"].extend(
                    float(value) for value in (inferred - truth).square().sum(-1).sqrt() / (2**0.5)
                )
                errors[f"{record.category}/global_side_swap_oracle_bilateral_only"].extend(
                    float(value) for value in (matched_points[[start, end]] - truth).square().sum(-1).sqrt() / (2**0.5)
                )
                original_pixels = torch.tensor([record.width, record.height])
                actual_width = float(((truth[0] - truth[1]) * original_pixels).square().sum().sqrt())
                if actual_width > 0:
                    width_errors[f"{record.category}/{LANDMARKS[start]}/{LANDMARKS[end]}"].append(
                        abs(float(((inferred[0] - inferred[1]) * original_pixels).square().sum().sqrt()) - actual_width)
                        / actual_width
                    )
    report = {
        "checkpoint_sha256": config.model.checkpoint_sha256,
        "manifest_sha256": sha256(config.manifest),
        "images": len(dataset),
        "diagnostic_only": True,
        "ground_truth_modified": False,
        "cm_accuracy": None,
        "normalization": "normalized square-input diagonal",
        "per_category_variant": {
            name: LandmarkMetric(
                points=len(values), pck_005=sum(v <= 0.05 for v in values) / len(values), nme=sum(values) / len(values)
            ).model_dump()
            for name, values in errors.items()
            if values
        },
        "projected_2d_pair_length_mean_relative_error_not_cm": {
            name: sum(values) / len(values) for name, values in width_errors.items()
        },
        "limitation": (
            "One global side permutation per garment is an oracle diagnostic on jointly visible bilateral targets; "
            "never substitute for ordered PCK or inference"
        ),
    }
    with config.output.open("x") as output:
        _ = output.write(json.dumps(report, indent=2) + "\n")
    return config.output
