"""Join local frozen-frame trials to tape truth without mixing automatic and corrected accuracy."""

import csv
import json
import math
from collections.abc import Iterable
from datetime import datetime
from pathlib import Path
from typing import Annotated, Literal

from pydantic import Field, model_validator

from coordit_ml.centimeter_evaluation import TapeMeasurement, evaluate_centimeters
from coordit_ml.schema import CATEGORIES, BoundaryModel, PipelineError, dimension_landmarks


class FieldPoint(BoundaryModel):
    """Normalized upright image coordinates, never screen coordinates."""

    x: Annotated[float, Field(ge=0, le=1)]
    y: Annotated[float, Field(ge=0, le=1)]


class FieldVector(BoundaryModel):
    """Frozen world position in meters."""

    x: float
    y: float
    z: float


class FieldEvidence(BoundaryModel):
    """Shared sensor metadata; its presence is not independent proof of physical accuracy."""

    frame_id: str
    timestamp: Annotated[float, Field(gt=0)]
    plane_id: str | None = None
    tracking_quality: Literal["normal", "tracking"]
    stable_plane_seconds: Annotated[float, Field(ge=1)]
    camera_motion_baseline_meters: Annotated[float, Field(ge=0.03)]
    camera_intrinsics: Annotated[list[float], Field(min_length=9, max_length=9)]
    camera_pose: Annotated[list[float], Field(min_length=16, max_length=16)]
    plane_pose: Annotated[list[float], Field(min_length=16, max_length=16)]
    image_width: Annotated[int, Field(gt=0)]
    image_height: Annotated[int, Field(gt=0)]
    orientation: Literal["up", "right", "down", "left"]
    corrected: bool


class FieldMeasurement(BoundaryModel):
    """Missing measurements remain failed attempts; they are never replaced with tape truth."""

    dimension: str
    predicted_cm: Annotated[float, Field(gt=0, le=300)] | None = None
    start2d: FieldPoint | None = None
    end2d: FieldPoint | None = None
    start3d: FieldVector | None = None
    end3d: FieldVector | None = None


class FieldTrial(BoundaryModel):
    """One stage of an identifiable physical attempt, with explicit algorithm and human truth."""

    garment_id: Annotated[str, Field(min_length=1)]
    attempt_id: Annotated[str, Field(min_length=1)]
    category: str
    method: Literal["arPlane", "card", "lidar"]
    stage: Literal["automatic", "manual"]
    algorithm_version: Annotated[str, Field(min_length=1)]
    recorded_at: datetime
    frame_id: str | None = None
    ar_evidence: FieldEvidence | None = None
    length_basis: str
    measurements: list[FieldMeasurement]
    failure_reason: str | None = None
    platform: Literal["ios", "android"]
    device: Annotated[str, Field(min_length=1)]
    background: Annotated[str, Field(min_length=1)]
    lighting: Annotated[str, Field(min_length=1)]
    ground_truth_cm: dict[str, Annotated[float, Field(gt=0, le=300)]]
    independent: bool
    synthetic: bool

    @model_validator(mode="after")
    def measurement_contract(self) -> "FieldTrial":
        """Require category/part/basis agreement and original frame evidence for measured AR."""
        if self.category not in CATEGORIES:
            raise PipelineError("Unsupported field category")
        expected = set(dimension_landmarks(self.category))
        if set(self.ground_truth_cm) != expected or {m.dimension for m in self.measurements} != expected:
            raise PipelineError("Incomplete or mismatched field measurement schema")
        if len(self.measurements) != len(expected):
            raise PipelineError("Duplicate measurement part")
        for part in self.measurements:
            if part.predicted_cm is not None:
                if part.start3d is None or part.end3d is None or part.start2d is None or part.end2d is None:
                    raise PipelineError("Measured value requires both original world and image endpoints")
                distance = (
                    math.dist(
                        (part.start3d.x, part.start3d.y, part.start3d.z),
                        (part.end3d.x, part.end3d.y, part.end3d.z),
                    )
                    * 100
                )
                if abs(distance - part.predicted_cm) > 0.01:
                    raise PipelineError("Exported cm differs from the actual 3D endpoint distance")
        lower = self.category in {"pants", "jeans", "shorts", "skirt"}
        if self.length_basis not in ({"waist_to_hem"} if lower else {"high_shoulder_to_hem", "back_neck_to_hem"}):
            raise PipelineError("Invalid measurement basis")
        if (
            self.method == "arPlane"
            and any(m.predicted_cm is not None for m in self.measurements)
            and (self.ar_evidence is None or self.frame_id != self.ar_evidence.frame_id)
        ):
            raise PipelineError("Measured AR requires matching frozen frame evidence")
        return self


class FieldExport(BoundaryModel):
    """No image payload or training consent is part of the field test export."""

    schema_version: Literal[1]
    purpose: Literal["local_ar_accuracy_evaluation_not_training"]
    trials: Annotated[list[FieldTrial], Field(min_length=1)]


def _write_stage_csv(trials: list[FieldTrial], path: Path) -> None:
    with path.open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerows(
            [
                [
                    "garment_id",
                    "category",
                    "method",
                    "dimension",
                    "ground_truth_cm",
                    "predicted_cm",
                    "independent",
                    "synthetic",
                    "device",
                    "background",
                ]
            ]
        )
        for trial in trials:
            for part in trial.measurements:
                row = TapeMeasurement(
                    garment_id=trial.garment_id,
                    category=trial.category,
                    method=trial.method,
                    dimension=part.dimension,
                    ground_truth_cm=trial.ground_truth_cm[part.dimension],
                    predicted_cm=part.predicted_cm,
                    independent=True,
                    synthetic=False,
                    device=trial.device,
                    background=trial.background,
                )
                writer.writerows(
                    [
                        [
                            row.garment_id,
                            row.category,
                            row.method,
                            row.dimension,
                            row.ground_truth_cm,
                            row.predicted_cm,
                            True,
                            False,
                            row.device,
                            row.background,
                        ]
                    ]
                )


def _point_displacements(pairs: Iterable[list[FieldTrial]]) -> list[float]:
    displacements: list[float] = []
    for pair in pairs:
        automatic = next((t for t in pair if t.stage == "automatic"), None)
        manual = next((t for t in pair if t.stage == "manual"), None)
        if automatic is None or manual is None:
            continue
        after_by_part = {part.dimension: part for part in manual.measurements}
        for before in automatic.measurements:
            after = after_by_part[before.dimension]
            for a, b in ((before.start2d, after.start2d), (before.end2d, after.end2d)):
                if a is not None and b is not None:
                    displacements.append(math.hypot(a.x - b.x, a.y - b.y) / math.sqrt(2))
    return displacements


def field_report(source: Path, output: Path) -> Path:
    """Read one export or a directory, refuse duplicated/synthetic data, and emit separate stage reports."""
    paths = sorted(source.glob("*.json")) if source.is_dir() else [source]
    trials = [trial for path in paths for trial in FieldExport.model_validate_json(path.read_bytes()).trials]
    if not trials:
        raise PipelineError("No field exports supplied")
    identities: set[tuple[str, str, str]] = set()
    pairs: dict[tuple[str, str], list[FieldTrial]] = {}
    for trial in trials:
        if trial.synthetic or not trial.independent:
            raise PipelineError("Field accuracy requires independent REAL garments; simulator fixtures are refused")
        identity = (trial.platform, trial.attempt_id, trial.stage)
        if identity in identities:
            raise PipelineError("Duplicate attempt/stage across exports; use each attempt once")
        identities.add(identity)
        pair = pairs.setdefault((trial.platform, trial.attempt_id), [])
        if pair and any(
            getattr(pair[0], name) != getattr(trial, name)
            for name in ("frame_id", "garment_id", "category", "method", "ground_truth_cm", "length_basis", "device")
        ):
            raise PipelineError("Automatic/manual pair changed frame, garment, truth or measurement basis")
        pair.append(trial)
    output.mkdir(parents=True, exist_ok=False)
    stage_reports = {}
    for stage in ("automatic", "manual"):
        selected = [trial for trial in trials if trial.stage == stage]
        if not selected:
            continue
        csv_path = output / f"{stage}.csv"
        _write_stage_csv(selected, csv_path)
        stage_reports[stage] = evaluate_centimeters(csv_path)
    displacements = _point_displacements(pairs.values())
    result = output / "report.json"
    _ = result.write_text(
        json.dumps(
            {
                "trial_stages": len(trials),
                "physical_attempts": len(pairs),
                "stages": stage_reports,
                "automatic_manual_point_displacement_mean_input_diagonal": sum(displacements) / len(displacements)
                if displacements
                else None,
                "point_comparison_scope": (
                    "correction displacement, not independent landmark ground truth or cm accuracy"
                ),
                "deployment_approved": False,
            },
            indent=2,
            allow_nan=False,
        )
        + "\n"
    )
    return result
