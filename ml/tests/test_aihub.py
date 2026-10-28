"""Artificial contract fixtures, never represented as downloaded or trained AI Hub data."""

import json
from pathlib import Path

import pytest
from PIL import Image

from coordit_ml.aihub import QuarantinedPair, SourceLabel, audit_aihub, measurement_targets
from coordit_ml.aihub_conversion import AIHubConversion, convert_aihub
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, audit_records
from coordit_ml.schema import PipelineError, Record, Status, read_registry


def _label(name: str = "sample") -> str:
    return json.dumps(
        {
            "dataset": {
                "dataset.name": name,
                "dataset.image_path": f"./원천데이터/{name}.jpg",
                "dataset.width": 60,
                "dataset.height": 80,
            },
            "metadata.model": {"metadata.model.shoulders_width": "999", "metadata.model.breast_size_female": "900"},
            "metadata.clothes": {
                "metadata.clothes.type": "02top_04shirt",
                "metadata.top.front_length": "66.0",
                "metadata.top.chest_size": "102.0",
                "metadata.top.shoulder_width": "40.0",
                "metadata.top.sleeve_length": "54.0",
                "metadata.pants.front_rise_length": "null",
            },
            "annotation": [{"annotation_type": "Polygon", "annotation_point": [10, 10, 50, 10, 50, 70, 10, 70]}],
        }
    )


def test_clothing_targets_never_use_wearer_body_or_halve_circumference() -> None:
    parsed = SourceLabel.model_validate_json(_label())
    targets = {target.source_field: target for target in measurement_targets(parsed.clothes)}
    assert targets["metadata.top.shoulder_width"].value == 40
    assert targets["metadata.top.chest_size"].value == 102
    assert targets["metadata.top.chest_size"].quantity == "circumference"
    assert all(target.protocol_verified and not target.coordit_endpoints_verified for target in targets.values())
    assert not any("model" in name or "rise" in name for name in targets)


def test_publisher_zero_not_applicable_measurement_is_not_a_zero_cm_target() -> None:
    parsed = SourceLabel.model_validate_json(_label().replace('"54.0"', '"0.0"'))
    targets = measurement_targets(parsed.clothes)
    assert not any(target.source_field == "metadata.top.sleeve_length" for target in targets)
    assert any(target.source_field == "metadata.top.shoulder_width" for target in targets)


def test_private_pairs_produce_quarantine_not_training_records(tmp_path: Path) -> None:
    source = tmp_path / "private"
    source.mkdir()
    _ = (source / "sample.json").write_text(_label())
    Image.new("RGB", (60, 80), "red").save(source / "sample.jpg")
    report = audit_aihub(source, tmp_path / "audit")
    assert report.matched_unique_images == 1
    assert report.approved_training_images == 0
    assert report.seam_ground_truth_images == 0
    pair = QuarantinedPair.model_validate_json((tmp_path / "audit/quarantined_pairs.jsonl").read_text())
    assert pair.semantic_landmark_count == 0
    assert pair.split == "quarantine"
    assert not pair.training_eligible
    with pytest.raises(ValueError, match="validation error"):
        _ = Record.model_validate_json(pair.model_dump_json())


def test_missing_actual_pairs_fail_instead_of_claiming_empty_download(tmp_path: Path) -> None:
    with pytest.raises(PipelineError, match="No actual AI Hub labels"):
        _ = audit_aihub(tmp_path, tmp_path / "empty")
    _ = (tmp_path / "sample.json").write_text(_label())
    with pytest.raises(PipelineError, match="No image/label pairs matched"):
        _ = audit_aihub(tmp_path, tmp_path / "missing")


def test_conflicting_same_filename_cannot_silently_join_wrong_photo(tmp_path: Path) -> None:
    for folder, color in [("a", "red"), ("b", "blue")]:
        directory = tmp_path / folder
        directory.mkdir()
        Image.new("RGB", (60, 80), color).save(directory / "sample.jpg")
    _ = (tmp_path / "sample.json").write_text(_label())
    with pytest.raises(PipelineError, match="Ambiguous image filename"):
        _ = audit_aihub(tmp_path, tmp_path / "ambiguous")


def test_aihub_cannot_enter_training_before_specific_rights_review() -> None:
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    entry = approved_entry(registry, "aihub-71501")
    assert entry.permissions == ["train", "modify"]
    pending = registry.model_copy(
        update={
            "datasets": [
                row.model_copy(update={"status": Status.PENDING}) if row.id == entry.id else row
                for row in registry.datasets
            ]
        }
    )
    with pytest.raises(PipelineError, match="not approved"):
        _ = approved_entry(pending, "aihub-71501")
    expanded = registry.model_copy(
        update={
            "datasets": [
                row.model_copy(update={"permissions": ["train", "redistribute"]}) if row.id == entry.id else row
                for row in registry.datasets
            ]
        }
    )
    with pytest.raises(PipelineError, match="source/deployment rights excluded"):
        _ = approved_entry(expanded, "aihub-71501")


def test_cm_metadata_stays_traceable_without_fabricating_seam_or_cm_regression_truth(tmp_path: Path) -> None:
    source = tmp_path / "source"
    source.mkdir()
    name = "01_sou_000001_000001_front_01outer_01coat_woman"
    _ = (source / f"{name}.json").write_text(_label(name).replace("02top_04shirt", "01outer_01coat"))
    Image.new("RGB", (60, 80), "red").save(source / f"{name}.jpg")
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    manifest = convert_aihub(AIHubConversion(source=source, output=tmp_path / "approved"), registry)
    records = audit_records(manifest, registry)
    assert len(records) == 1
    assert records[0].keypoints == []
    assert records[0].measurement_ground_truth == {}
    assert records[0].segmentation_supervised
    assert records[0].split == "train"
    pair = QuarantinedPair.model_validate_json((manifest.parent / "source_measurements.jsonl").read_text())
    assert any(target.source_field == "metadata.top.chest_size" and target.value == 102 for target in pair.targets)


def test_custom_training_grant_requires_unchanged_pinned_agreement(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    monkeypatch.setattr("coordit_ml.provenance.REGISTRY_ROOT", tmp_path)
    with pytest.raises(PipelineError, match="pinned local-training agreement"):
        _ = approved_entry(registry, "aihub-71501")


def test_same_photo_with_conflicting_cm_is_excluded_entirely(tmp_path: Path) -> None:
    for name, value, color in [("first", "54.0", "red"), ("second", "55.0", "red"), ("unique", "54.0", "blue")]:
        _ = (tmp_path / f"{name}.json").write_text(_label(name).replace('"54.0"', f'"{value}"'))
        Image.new("RGB", (60, 80), color).save(tmp_path / f"{name}.jpg")
    report = audit_aihub(tmp_path, tmp_path / "review")
    assert report.conflicting_duplicate_images == 1
    assert report.matched_unique_images == 1
    pair = QuarantinedPair.model_validate_json((tmp_path / "review/quarantined_pairs.jsonl").read_text())
    assert pair.source_name == "unique"
