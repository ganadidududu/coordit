from pathlib import Path

from coordit_ml.landmark_support import trained_landmarks
from coordit_ml.provenance import read_records, write_records
from coordit_ml.schema import CATEGORIES
from coordit_ml.synthetic import generate
from coordit_ml.training import TrainingConfig, train


def test_mask_only_checkpoint_does_not_claim_supported_landmarks(tmp_path: Path) -> None:
    # Given actual generated images with deliberately absent semantic supervision.
    original = generate(tmp_path / "data", 1)
    records = [record.model_copy(update={"keypoints": []}) for record in read_records(original)]
    manifest = original.parent / "mask-only.jsonl"
    write_records(manifest, records)
    directory = tmp_path / "model"
    _ = train(TrainingConfig(manifests=[manifest], output=directory, epochs=1, batch_size=2, max_steps=1))
    # When checking category support, then randomly initialized pose heads have no eligible outputs.
    assert all(not trained_landmarks(directory, category) for category in CATEGORIES)
