from datetime import UTC, datetime
from pathlib import Path
from typing import ClassVar

import pytest
from pydantic import BaseModel, ConfigDict, ValidationError

from coordit_ml.field_evaluation import (
    FieldExport,
    FieldMeasurement,
    FieldPoint,
    FieldTrial,
    FieldVector,
    field_report,
)
from coordit_ml.schema import PipelineError, dimension_landmarks


class MetricProbe(BaseModel):
    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    mae_cm: float | None
    attempts: int
    success_rate: float
    accuracy_target_met: bool


class ReportProbe(BaseModel):
    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    physical_attempts: int
    stages: dict[str, dict[str, MetricProbe]]
    deployment_approved: bool


def trial(stage: str = "automatic", predicted_cm: float = 41) -> FieldTrial:
    return FieldTrial.model_validate(
        {
            "garment_id": "unit-test-fixture",
            "attempt_id": "fixture-attempt",
            "category": "tshirt",
            "method": "card",
            "stage": stage,
            "algorithm_version": "fixture",
            "recorded_at": datetime(2026, 10, 27, tzinfo=UTC),
            "length_basis": "high_shoulder_to_hem",
            "measurements": [
                FieldMeasurement(
                    dimension=key,
                    predicted_cm=predicted_cm,
                    start2d=FieldPoint(x=0.2, y=0.5),
                    end2d=FieldPoint(x=0.6, y=0.5),
                    start3d=FieldVector(x=0, y=0, z=0),
                    end3d=FieldVector(x=predicted_cm / 100, y=0, z=0),
                )
                for key in dimension_landmarks("tshirt")
            ],
            "platform": "ios",
            "device": "fixture",
            "background": "fixture",
            "lighting": "fixture",
            "ground_truth_cm": dict.fromkeys(dimension_landmarks("tshirt"), 40),
            "independent": True,
            "synthetic": False,
        }
    )


def write_export(path: Path, trials: list[FieldTrial]) -> None:
    _ = path.write_text(
        FieldExport(
            schema_version=1,
            purpose="local_ar_accuracy_evaluation_not_training",
            trials=trials,
        ).model_dump_json()
    )


def test_report_keeps_automatic_error_separate_from_manual_correction(tmp_path: Path) -> None:
    source = tmp_path / "export.json"
    write_export(source, [trial(), trial("manual", 40)])
    result = ReportProbe.model_validate_json(field_report(source, tmp_path / "results").read_bytes())
    assert result.physical_attempts == 1
    assert result.stages["automatic"]["card/tshirt/chest_width"].mae_cm == 1
    assert result.stages["manual"]["card/tshirt/chest_width"].mae_cm == 0
    assert result.stages["manual"]["card/tshirt/chest_width"].accuracy_target_met is False
    assert result.deployment_approved is False


@pytest.mark.parametrize("change", [{"synthetic": True}, {"independent": False}])
def test_simulator_or_non_independent_trials_cannot_pass_as_physical_evidence(
    tmp_path: Path,
    change: dict[str, bool],
) -> None:
    source = tmp_path / "export.json"
    write_export(source, [trial().model_copy(update=change)])
    with pytest.raises(PipelineError, match="independent REAL"):
        _ = field_report(source, tmp_path / "results")


def test_reexported_attempts_and_changed_tape_truth_are_refused(tmp_path: Path) -> None:
    source = tmp_path / "export.json"
    write_export(source, [trial(), trial()])
    with pytest.raises(PipelineError, match="Duplicate attempt"):
        _ = field_report(source, tmp_path / "duplicate")
    write_export(source, [trial(), trial("manual").model_copy(update={"garment_id": "different-garment"})])
    with pytest.raises(PipelineError, match="changed frame"):
        _ = field_report(source, tmp_path / "changed")


def test_mislabeled_skirt_and_cm_without_matching_geometry_are_refused() -> None:
    original = trial().model_dump()
    with pytest.raises(PipelineError, match="measurement schema"):
        _ = FieldTrial.model_validate({**original, "category": "skirt", "length_basis": "waist_to_hem"})
    rows = [part.model_copy(update={"predicted_cm": 5}) for part in trial().measurements]
    with pytest.raises(PipelineError, match="3D endpoint distance"):
        _ = FieldTrial.model_validate({**original, "measurements": rows})
    with pytest.raises(ValidationError):
        _ = FieldMeasurement(dimension="chest_width", predicted_cm=-1)
    with pytest.raises(PipelineError, match="frozen frame evidence"):
        _ = FieldTrial.model_validate({**original, "method": "arPlane"})


@pytest.mark.parametrize("stage", ["automatic", "manual"])
def test_failed_measurements_remain_in_the_success_denominator(tmp_path: Path, stage: str) -> None:
    source = tmp_path / "export.json"
    before = trial(stage)
    missing = [FieldMeasurement(dimension=key) for key in dimension_landmarks("tshirt")]
    failure = before.model_copy(update={"attempt_id": "failed-attempt", "measurements": missing})
    write_export(source, [before, failure])
    result = ReportProbe.model_validate_json(field_report(source, tmp_path / "results").read_bytes())
    row = result.stages[stage]["card/tshirt/chest_width"]
    assert row.attempts == 2
    assert row.success_rate == 0.5
    assert row.accuracy_target_met is False
