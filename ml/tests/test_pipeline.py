import base64
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from coordit_ml.acquisition import convert_artf
from coordit_ml.approval import Approval, approve_dataset
from coordit_ml.centimeter_evaluation import evaluate_centimeters
from coordit_ml.network import ApprovedDataset
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, audit_records, read_records, sha256, write_records
from coordit_ml.schema import PipelineError, Status, dimension_landmarks, read_registry
from coordit_ml.service import app
from coordit_ml.synthetic import generate
from coordit_ml.training import TrainingConfig, train


@pytest.fixture
def corpus(tmp_path: Path) -> Path:
    return generate(tmp_path / "data", per_category=2)


def test_loader_rejects_pending_blocked_and_unknown_sources() -> None:
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    for source in ("open-images-v7", "deepfashion2", "unreviewed-upload"):
        with pytest.raises(PipelineError):
            approved_entry(registry, source)


def test_all_eleven_procedural_categories_have_explicit_semantics(corpus: Path) -> None:
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    records = audit_records(corpus, registry)
    assert {record.category for record in records} == set(registry.categories)
    skirt = next(record for record in records if record.category == "skirt")
    assert set(skirt.measurement_ground_truth) == {"waist_width", "hip_width", "total_length"}
    assert "crotch" not in {point.landmark_type for point in skirt.keypoints}
    assert "rise" not in dimension_landmarks("skirt")


def test_hash_tampering_fails_before_training(corpus: Path) -> None:
    record = read_records(corpus)[0]
    (corpus.parent / record.file_name).write_bytes(b"changed-image")
    with pytest.raises(PipelineError, match="hash mismatch"):
        audit_records(corpus, read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json"))


def test_same_garment_in_two_splits_is_rejected(corpus: Path) -> None:
    records = read_records(corpus)
    target = records[0]
    other = records[1].model_copy(
        update={"garment_id": target.garment_id, "split": "test" if target.split == "train" else "train"}
    )
    manifest = corpus.parent / "contaminated.jsonl"
    write_records(manifest, [target, other])
    with pytest.raises(PipelineError, match="group leakage"):
        audit_records(manifest, read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json"))


def test_evaluation_partition_never_enters_training(corpus: Path) -> None:
    original = read_records(corpus)[0]
    contaminated = original.model_copy(
        update={
            "source_dataset": "artf-1.0.1",
            "category": "tshirt",
            "original_license": "CC-BY-4.0",
            "source_path": "test/location_2/tshirts/related-crop.png",
        }
    )
    manifest = corpus.parent / "denied.jsonl"
    write_records(manifest, [contaminated])
    with pytest.raises(PipelineError, match="Evaluation contamination"):
        audit_records(manifest, read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json"))


def test_empty_manifest_and_unreviewed_archive_are_failures(tmp_path: Path) -> None:
    empty = tmp_path / "empty.jsonl"
    empty.write_text("")
    with pytest.raises(PipelineError, match="empty"):
        audit_records(empty, read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json"))
    with pytest.raises(PipelineError, match="reviewed publisher"):
        convert_artf(empty, tmp_path / "out", read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json"))


def test_source_keypoints_are_not_silently_treated_as_seams(corpus: Path) -> None:
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    original = read_records(corpus)[0]
    record = original.model_copy(update={"keypoints": [], "source_keypoints": original.keypoints, "split": "train"})
    manifest = corpus.parent / "source-only.jsonl"
    write_records(manifest, [record])
    sample = ApprovedDataset([manifest], registry, "train")[0]
    assert (sample.visibility == -1).all()


def test_cpu_checkpoint_resume_refuses_changed_data(corpus: Path, tmp_path: Path) -> None:
    config = TrainingConfig(manifests=[corpus], output=tmp_path / "model", epochs=1, batch_size=4, max_steps=1)
    checkpoint = train(config)
    assert checkpoint.stat().st_size > 1000
    with pytest.raises(PipelineError, match="fingerprint mismatch"):
        train(config.model_copy(update={"resume": True, "epochs": 2, "seed": 99}))
    assert train(config.model_copy(update={"resume": True, "epochs": 2})) == checkpoint


def test_tape_gate_rejects_synthetic_or_nonindependent_data(tmp_path: Path) -> None:
    csv = tmp_path / "tape.csv"
    _ = csv.write_text("""garment_id,category,method,dimension,ground_truth_cm,predicted_cm,independent,synthetic
a,tshirt,arPlane,chest_width,50,50,true,true
""")
    with pytest.raises(PipelineError, match="independent REAL"):
        evaluate_centimeters(csv)


def test_service_is_closed_until_explicit_development_configuration(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("COORDIT_ML_DEVELOPMENT", raising=False)
    with TestClient(app) as client:
        response = client.post("/v1/landmarks", json={})
    assert response.status_code == 503
    assert response.json()["detail"] == "model_not_deployment_approved"


def test_service_enforces_auth_consent_and_model_installation(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("COORDIT_ML_DEVELOPMENT", "true")
    monkeypatch.setenv("COORDIT_ML_API_TOKEN", "a" * 32)
    monkeypatch.delenv("COORDIT_ML_MODEL_DIRECTORY", raising=False)
    payload = {"image_base64": base64.b64encode(b"photo").decode(), "processing_consent": False}
    with TestClient(app) as client:
        assert client.post("/v1/landmarks", json=payload).status_code == 401
        headers = {"Authorization": "Bearer " + "a" * 32}
        assert client.post("/v1/landmarks", json=payload, headers=headers).status_code == 403
        missing = client.post("/v1/landmarks", json={**payload, "processing_consent": True}, headers=headers)
        assert missing.status_code == 503
        assert missing.json()["detail"] == "model_not_installed"


def test_combining_manifests_cannot_bypass_duplicate_checks(corpus: Path) -> None:
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    with pytest.raises(PipelineError, match="Duplicate across corpora"):
        ApprovedDataset([corpus, corpus], registry, "train")


def test_approval_cannot_grant_training_to_noncommercial_data(tmp_path: Path) -> None:
    original = REGISTRY_ROOT / "DATASET_MANIFEST.json"
    copied = tmp_path / "registry.json"
    _ = copied.write_bytes(original.read_bytes())
    registry = read_registry(copied)
    candidate = next(entry for entry in registry.datasets if entry.id == "open-images-v7")
    proposal = candidate.model_copy(
        update={"status": Status.APPROVED, "data_license": "CC-BY-NC-4.0", "permissions": ["train"]}
    )
    review = Approval(
        expected_registry_sha256=sha256(copied),
        reviewer="contract-test",
        original_evidence_urls=[candidate.original_url],
        dataset=proposal,
    )
    path = tmp_path / "review.json"
    _ = path.write_text(review.model_dump_json())
    with pytest.raises(PipelineError, match="License requires"):
        approve_dataset(copied, path)
