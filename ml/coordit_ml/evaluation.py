"""Per-category perception metrics and an independent tape-measure release gate."""

import csv
import json
import math
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import torch

from coordit_ml.network import ApprovedDataset
from coordit_ml.provenance import REGISTRY_ROOT, sha256
from coordit_ml.schema import CATEGORIES, CLASSES, BoundaryModel, PipelineError, read_registry
from coordit_ml.training import load_model


class MetricRow(BoundaryModel):
    """Per-category development metrics with explicit missing values."""

    images: int
    classification_accuracy: float | None
    segmentation_iou: float | None
    landmark_pck_005: float | None
    landmark_nme: float | None
    landmark_missing_rate: float | None
    inference_ms_mean: float | None
    status: str


def evaluate(directory: Path, manifest: Path, split: str = "test") -> Path:
    """Report real and synthetic domains separately; no unsupported category gets a passing score."""
    torch.set_num_threads(2)
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    dataset = ApprovedDataset([manifest], registry, split)
    if not len(dataset):
        raise PipelineError("Requested evaluation split is empty")
    model = load_model(directory)
    metrics: dict[str, list[tuple[float, float, float, float, float, float]]] = defaultdict(list)
    confusion = [[0 for _ in CLASSES] for _ in CLASSES]
    with torch.inference_mode():
        for index, (_, record) in enumerate(dataset.samples):
            sample = dataset[index]
            started = time.perf_counter()
            prediction = model.forward(sample.pixels.unsqueeze(0))
            elapsed = (time.perf_counter() - started) * 1000
            label, inferred = int(sample.category), int(prediction.category.argmax(1)[0])
            confusion[label][inferred] += 1
            mask, truth = prediction.mask[0].sigmoid() >= 0.5, sample.mask >= 0.5
            union = (mask | truth).sum().item()
            iou = (mask & truth).sum().item() / max(1, union)
            visible = sample.visibility > 0
            errors = (prediction.points[0] - sample.points).square().sum(1).sqrt()[visible] / (2**0.5)
            pck = float((errors <= 0.05).float().mean()) if len(errors) else float("nan")
            nme = float(errors.mean()) if len(errors) else float("nan")
            missing = (
                float((prediction.visibility[0].sigmoid()[visible] < 0.5).float().mean())
                if len(errors)
                else float("nan")
            )
            domain = "synthetic" if record.acquisition_metadata.synthetic else "real"
            values = (float(label == inferred), iou, pck, nme, missing, elapsed)
            for key in (
                f"{domain}/{record.category}",
                f"background/{record.acquisition_metadata.background}",
                f"occlusion/{record.acquisition_metadata.occlusion}",
                f"wrinkles/{record.acquisition_metadata.wrinkles}",
            ):
                metrics[key].append(values)
    rows: dict[str, MetricRow] = {}
    for domain in ("real", "synthetic"):
        for category in CATEGORIES:
            key = f"{domain}/{category}"
            if key not in metrics:
                rows[key] = MetricRow(
                    images=0,
                    classification_accuracy=None,
                    segmentation_iou=None,
                    landmark_pck_005=None,
                    landmark_nme=None,
                    landmark_missing_rate=None,
                    inference_ms_mean=None,
                    status="unverified",
                )
    for key, values in metrics.items():
        columns = [[value[index] for value in values] for index in range(6)]
        averages = [
            sum(v for v in column if math.isfinite(v)) / max(1, sum(math.isfinite(v) for v in column))
            if any(math.isfinite(v) for v in column)
            else None
            for column in columns
        ]
        rows[key] = MetricRow(
            images=len(values),
            classification_accuracy=averages[0],
            segmentation_iou=averages[1],
            landmark_pck_005=averages[2],
            landmark_nme=averages[3],
            landmark_missing_rate=averages[4],
            inference_ms_mean=averages[5],
            status="development_only",
        )
    f1: list[float] = []
    for index in range(len(CLASSES)):
        denominator = sum(confusion[index]) + sum(row[index] for row in confusion)
        if denominator:
            f1.append(2 * confusion[index][index] / denominator)
    report = {
        "split": split,
        "manifest_sha256": sha256(manifest),
        "checkpoint_sha256": sha256(directory / "checkpoint.pt"),
        "macro_f1_present_classes": sum(f1) / len(f1),
        "segmentation_miou_present_groups": float(
            np.mean(
                [
                    row.segmentation_iou
                    for key, row in rows.items()
                    if key.startswith(("real/", "synthetic/")) and row.images and row.segmentation_iou is not None
                ]
            )
        ),
        "parameter_bytes": sum(p.numel() * p.element_size() for p in model.parameters()),
        "cm_accuracy": "unverified: no independent tape-measured evaluation",
        "deployment_approved": False,
        "rows": {key: row.model_dump() for key, row in rows.items()},
    }
    output = directory / f"metrics-{split}.json"
    _ = output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    return output


class TapeMeasurement(BoundaryModel):
    """Independent tape measurement and one prediction attempt."""

    garment_id: str
    category: str
    method: str
    dimension: str
    ground_truth_cm: float
    predicted_cm: float | None
    independent: bool
    synthetic: bool


def evaluate_centimeters(csv_path: Path) -> dict[str, dict[str, float | int | bool | None]]:
    """A release gate needs >=20 independent real garments for EACH category/method/part."""
    groups: dict[str, list[TapeMeasurement]] = defaultdict(list)
    with csv_path.open() as stream:
        for row in csv.DictReader(stream):
            parsed = TapeMeasurement.model_validate({**row, "predicted_cm": row["predicted_cm"] or None})
            if not parsed.independent or parsed.synthetic or parsed.category not in CATEGORIES:
                raise PipelineError("Centimeter gate requires independent REAL tape-measured garments")
            groups[f"{parsed.method}/{parsed.category}/{parsed.dimension}"].append(parsed)
    if not groups:
        raise PipelineError("No tape measurements supplied")
    report: dict[str, dict[str, float | int | bool | None]] = {}
    for key, rows in groups.items():
        errors = [r.predicted_cm - r.ground_truth_cm for r in rows if r.predicted_cm is not None]
        absolute = [abs(error) for error in errors]
        garments = len({r.garment_id for r in rows})
        mae = float(np.mean(absolute)) if absolute else None
        p95 = float(np.percentile(absolute, 95)) if absolute else None
        report[key] = {
            "garments": garments,
            "attempts": len(rows),
            "success_rate": len(errors) / len(rows),
            "recapture_rate": 1 - len(errors) / len(rows),
            "mae_cm": mae,
            "median_absolute_error_cm": float(np.median(absolute)) if absolute else None,
            "p95_absolute_error_cm": p95,
            "bias_cm": float(np.mean(errors)) if errors else None,
            "accuracy_target_met": garments >= 20 and mae is not None and mae <= 1 and p95 is not None and p95 <= 2,
        }
    return report
