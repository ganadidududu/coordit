from pathlib import Path
from typing import Literal

import pytest

from coordit_ml.aihub_review_queue import AnnotationTask
from coordit_ml.provenance import read_records, sha256
from coordit_ml.schema import PipelineError
from coordit_ml.synthetic import generate
from coordit_ml.via_annotation import PointShape, ViaImage, ViaRegion
from coordit_ml.via_reviews import ViaExport, ViaImport, import_via_reviews


def _review_fixture(tmp_path: Path, state: Literal["proposal", "verified"]) -> ViaImport:
    manifest = generate(tmp_path / "source", 1)
    record = read_records(manifest)[0]
    task = AnnotationTask(record=record, purpose="blind_holdout_candidate", proposed_points=[])
    index = manifest.parent / "tasks.jsonl"
    _ = index.write_text(task.model_dump_json() + "\n")
    image = ViaImage(
        filename=Path(record.file_name).name,
        size=(manifest.parent / record.file_name).stat().st_size,
        regions=[
            ViaRegion(
                shape_attributes=PointShape(cx=12, cy=20),
                region_attributes={"landmark_type": "shoulder_left", "visibility": "2", "review_status": state},
            )
        ],
        file_attributes={
            "coordit_image_id": record.image_id,
            "image_sha256": record.sha256,
            "purpose": "blind_holdout_candidate",
            "review_complete": "yes",
            "reviewer": "fixture-reviewer",
            "protocol": "coordit-upper-seam-v1",
            "evidence": "authored fixture pixel",
        },
    )
    project = tmp_path / "project.json"
    _ = project.write_text(
        ViaExport.model_validate({"_via_img_metadata": {"test": image.model_dump()}}).model_dump_json(by_alias=True)
    )
    return ViaImport(tasks=index, tasks_sha256=sha256(index), project=project, output=tmp_path / "verified")


def test_model_proposal_cannot_become_verified_ground_truth(tmp_path: Path) -> None:
    # Given an image-level complete flag but a region which remains an unreviewed proposal.
    config = _review_fixture(tmp_path, "proposal")
    # When importing, then human point verification is still required.
    with pytest.raises(PipelineError, match="Unverified"):
        _ = import_via_reviews(config)


def test_verified_holdout_labels_are_separated_from_training_labels(tmp_path: Path) -> None:
    # Given a manually verified point in a fixed blind task.
    config = _review_fixture(tmp_path, "verified")
    # When importing, then the point is written only to the held-out review stream.
    _ = import_via_reviews(config)
    assert (config.output / "blind_holdout_candidate.jsonl").is_file()
    assert not (config.output / "training_review.jsonl").exists()


def test_editing_via_purpose_cannot_promote_holdout_photo_into_training(tmp_path: Path) -> None:
    # Given an exported project whose editable purpose has been changed after task freezing.
    config = _review_fixture(tmp_path, "verified")
    exported = ViaExport.model_validate_json(config.project.read_bytes())
    image = exported.images["test"]
    changed = image.model_copy(update={"file_attributes": {**image.file_attributes, "purpose": "training_review"}})
    _ = config.project.write_text(
        ViaExport.model_validate({"_via_img_metadata": {"test": changed.model_dump()}}).model_dump_json(by_alias=True)
    )
    # When importing, then the immutable original task wins and the attempted split change fails.
    with pytest.raises(PipelineError, match="purpose"):
        _ = import_via_reviews(config)


def test_changed_local_pixels_cannot_receive_old_verified_coordinates(tmp_path: Path) -> None:
    # Given a reviewed source whose pixels have since been replaced at the same path.
    config = _review_fixture(tmp_path, "verified")
    task = AnnotationTask.model_validate_json(config.tasks.read_text().strip())
    _ = (config.tasks.parent / task.record.file_name).write_bytes(b"different crop")
    # When importing, then matching editable metadata cannot override the actual pixel hash.
    with pytest.raises(PipelineError, match="identity"):
        _ = import_via_reviews(config)
