from pathlib import Path

import pytest
import torch

from coordit_ml.augmentation import Augmentation
from coordit_ml.external_pilot import ExternalPoint
from coordit_ml.network import Prediction
from coordit_ml.provenance import read_records, sha256
from coordit_ml.schema import LANDMARKS, Landmark, PipelineError
from coordit_ml.synthetic import generate
from coordit_ml.teacher_annotations import TeacherPin, read_teacher, require_training_artf
from coordit_ml.teacher_evaluation import TeacherEvaluation, evaluate_teacher_models
from coordit_ml.teacher_supervision import TeacherTargets, WeakPoint, eligible_point, require_brightness_only


@pytest.mark.parametrize(("source", "split", "path"), [
    ("aihub-71501", "train", "train/photo.png"),
    ("artf-publisher-test-evaluation-only-v1", "test", "test/photo.png"),
    ("artf-1.0.1", "train", "test/renamed-as-train.png"),
    ("artf-1.0.1", "validation", "train/photo.png"),
])
def test_external_training_packet_rejects_private_or_evaluation_source(
    tmp_path: Path, source: str, split: str, path: str,
) -> None:
    # Given a fixture carrying a disallowed source identity or original partition.
    record = read_records(generate(tmp_path / "fixture", 1))[0].model_copy(update={
        "source_dataset": source, "category": "tshirt", "split": split,
        "source_path": path, "original_license": "CC-BY-4.0",
    })
    # When preparing external teacher inputs, then renaming cannot authorize that photo.
    with pytest.raises(PipelineError, match="public aRTF training"):
        require_training_artf(record)


@pytest.mark.parametrize(("visibility", "x", "reason"), [
    (1, 0.5, "publisher_not_visible"), (2, 0.9, "publisher_disagreement"),
])
def test_teacher_cannot_override_occluded_or_conflicting_publisher_point(
    visibility: int, x: float, reason: str,
) -> None:
    # Given a numeric teacher proposal conflicting with a preserved publisher label.
    original = Landmark.model_validate({
        "landmark_type": "shoulder_left", "x": 0.5, "y": 0.5,
        "visibility": visibility, "source": "publisher",
    })
    proposal = ExternalPoint(landmark_type="shoulder_left", x=x, y=0.5, status="visible_proposal")
    # When filtering a weak target, then the existing label remains authoritative.
    point, status = eligible_point(proposal, original)
    assert point is None
    assert status == reason
    assert original.source == "publisher"


def test_changed_teacher_response_fails_before_reading_private_training_data(tmp_path: Path) -> None:
    # Given a response changed after its recorded pre-training hash.
    packet, response = tmp_path / "packet.json", tmp_path / "response.json"
    _ = packet.write_text("{}")
    _ = response.write_text("changed")
    pin = TeacherPin(
        packet=packet, packet_sha256=sha256(packet), predictions=response, predictions_sha256="0" * 64,
    )
    # When loading supervision, then the changed response is rejected before source access.
    with pytest.raises(PipelineError, match="frozen predictions changed"):
        _ = read_teacher(pin, [])


def test_uncertain_teacher_target_has_smaller_gradient_without_touching_other_heads() -> None:
    # Given identical model predictions and a new uncertain versus visible weak endpoint.
    points = torch.full((1, len(LANDMARKS), 2), 0.5, requires_grad=True)
    maps = torch.zeros(1, len(LANDMARKS), 8, 8, requires_grad=True)
    category = torch.zeros(1, 13, requires_grad=True)
    mask = torch.zeros(1, 1, 16, 16, requires_grad=True)
    visibility = torch.zeros(1, len(LANDMARKS), requires_grad=True)
    prediction = Prediction(category, mask, points, visibility, maps)
    uncertain = TeacherTargets({"train": (WeakPoint("hem_center", 0.3, 0.8, 0.25),)}, {}, 0.25)
    visible = TeacherTargets({"train": (WeakPoint("hem_center", 0.3, 0.8, 1),)}, {}, 0.25)
    # When backpropagating the weak loss, then confidence scales it and unrelated predictions receive no gradients.
    loss = uncertain.objective(prediction, ["train"])
    _ = loss.backward()
    assert float(loss.detach()) == pytest.approx(float(visible.objective(prediction, ["train"]).detach()) / 4)
    assert maps.grad is not None
    assert float(maps.grad.abs().sum()) > 0
    assert points.grad is not None
    assert float(points.grad.abs().sum()) > 0
    assert mask.grad is None
    assert category.grad is None
    assert visibility.grad is None


def test_unannotated_photo_has_zero_weak_loss() -> None:
    # Given no teacher proposals for this real training photo.
    prediction = Prediction(
        torch.zeros(1, 13), torch.zeros(1, 1, 16, 16), torch.full((1, len(LANDMARKS), 2), 0.5),
        torch.zeros(1, len(LANDMARKS)), torch.zeros(1, len(LANDMARKS), 8, 8),
    )
    teacher = TeacherTargets({"another_photo": (WeakPoint("hem_center", 0.3, 0.8, 1),)}, {}, 0.25)
    # When computing the optional objective, then no coordinate or visibility label is fabricated.
    assert float(teacher.objective(prediction, ["unannotated"])) == 0


def test_geometry_augmentation_cannot_misalign_teacher_coordinates() -> None:
    # Given image rotation while weak points remain in original coordinates.
    policy = Augmentation(rotation_degrees=10, shift_fraction=0, scale_min=1, scale_max=1)
    # When configuring teacher training, then the incompatible run is rejected before an optimizer update.
    with pytest.raises(PipelineError, match="brightness-only"):
        require_brightness_only(policy)


def test_changed_evaluation_corpus_is_rejected_before_scoring(tmp_path: Path) -> None:
    # Given evaluation bytes that no longer match the predeclared photo/label manifest.
    manifest = tmp_path / "evaluation.jsonl"
    _ = manifest.write_text("changed after freeze")
    config = TeacherEvaluation(
        manifest=manifest, manifest_sha256="0" * 64,
        pilot_packet=tmp_path / "unread-packet.json", pilot_packet_sha256="0" * 64,
        models=[], output=tmp_path / "must-not-exist.json",
    )
    # When requesting metrics, then changed inputs cannot silently change the denominator.
    with pytest.raises(PipelineError, match="Evaluation corpus"):
        _ = evaluate_teacher_models(config)
    assert not config.output.exists()


def test_abstention_never_becomes_an_invisible_training_label() -> None:
    # Given a teacher that cannot locate a new hem endpoint.
    proposal = ExternalPoint(landmark_type="hem_center", x=None, y=None, status="abstain")
    # When preparing the weak objective, then neither an invented coordinate nor negative visibility is produced.
    accepted, reason = eligible_point(proposal, None)
    assert accepted is None
    assert reason == "abstained"
