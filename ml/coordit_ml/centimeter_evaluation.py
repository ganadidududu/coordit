"""Complete per-category tape-measure gate; failed attempts cannot inflate apparent accuracy."""

import csv
from collections import defaultdict
from pathlib import Path
from typing import Annotated, Literal

import numpy as np
from pydantic import Field

from coordit_ml.schema import CATEGORIES, BoundaryModel, PipelineError, dimension_landmarks


class TapeMeasurement(BoundaryModel):
    """One actual attempt against an independently measured, identifiable physical garment."""

    garment_id: Annotated[str, Field(min_length=1)]
    category: str
    method: Literal["arPlane", "lidar", "card"]
    dimension: str
    ground_truth_cm: Annotated[float, Field(gt=0, le=300)]
    predicted_cm: Annotated[float, Field(gt=0, le=300)] | None
    independent: bool
    synthetic: bool
    confidence: Annotated[float, Field(ge=0, le=1)] | None = None
    device: str = "unrecorded"
    background: str = "unrecorded"


def evaluate_centimeters(csv_path: Path) -> dict[str, dict[str, float | int | bool | None]]:
    """Require all 11 categories/parts and >=20 successful independent garments per part.

    Accuracy gates use garment-balanced errors so repeated easy shots cannot dominate.
    A 95% success floor is a conservative project policy, not a validated error guarantee.
    """
    groups: dict[str, list[TapeMeasurement]] = defaultdict(list)
    with csv_path.open() as stream:
        for row in csv.DictReader(stream):
            parsed = TapeMeasurement.model_validate({**row, "predicted_cm": row["predicted_cm"] or None})
            if not parsed.independent or parsed.synthetic or parsed.category not in CATEGORIES:
                raise PipelineError("Centimeter gate requires independent REAL tape-measured garments")
            if parsed.dimension not in dimension_landmarks(parsed.category):
                raise PipelineError("Category has no such measurement dimension")
            groups[f"{parsed.method}/{parsed.category}/{parsed.dimension}"].append(parsed)
    if not groups:
        raise PipelineError("No tape measurements supplied")
    methods = {key.split("/")[0] for key in groups}
    for method in methods:
        for category in CATEGORIES:
            for dimension in dimension_landmarks(category):
                _ = groups.setdefault(f"{method}/{category}/{dimension}", [])
    report: dict[str, dict[str, float | int | bool | None]] = {}
    for key, rows in groups.items():
        garment_errors: dict[str, list[float]] = defaultdict(list)
        for row in rows:
            if row.predicted_cm is not None:
                garment_errors[row.garment_id].append(row.predicted_cm - row.ground_truth_cm)
        # Each garment contributes equally; use every attempt's absolute error, preserving tails.
        weights = [1 / (len(garment_errors) * len(errors)) for errors in garment_errors.values() for _ in errors]
        errors = [error for values in garment_errors.values() for error in values]
        absolute = [abs(error) for error in errors]
        mae = float(np.average(absolute, weights=weights)) if absolute else None
        p95 = float(np.percentile(absolute, 95)) if absolute else None
        success = len(errors) / len(rows) if rows else 0.0
        report[key] = {
            "garments": len({r.garment_id for r in rows}),
            "successful_garments": len(garment_errors),
            "attempts": len(rows),
            "success_rate": success,
            "recapture_rate": 1 - success,
            "mae_cm": mae,
            "median_absolute_error_cm": float(np.median(absolute)) if absolute else None,
            "p95_absolute_error_cm": p95,
            "bias_cm": float(np.average(errors, weights=weights)) if errors else None,
            "accuracy_target_met": len(garment_errors) >= 20
            and success >= 0.95
            and mae is not None
            and mae <= 1
            and p95 is not None
            and p95 <= 2,
        }
    return report
