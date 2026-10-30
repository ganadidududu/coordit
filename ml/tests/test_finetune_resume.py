from pathlib import Path

from coordit_ml.artifacts import Artifact
from coordit_ml.finetuning import ParentCheckpoint
from coordit_ml.provenance import sha256
from coordit_ml.synthetic import generate
from coordit_ml.training import TrainingConfig, train


def test_initialized_run_resumes_its_optimizer_and_epoch_without_reinitializing_parent(tmp_path: Path) -> None:
    # Given a completed baseline and one complete epoch in a separate fine-tuning run.
    manifest = generate(tmp_path / "scenes", 1)
    baseline = tmp_path / "baseline"
    _ = train(TrainingConfig(manifests=[manifest], output=baseline, epochs=1, batch_size=2, max_steps=1))
    parent = ParentCheckpoint(
        directory=baseline,
        checkpoint_sha256=sha256(baseline / "checkpoint.pt"),
        artifact_sha256=sha256(baseline / "artifact.json"),
    )
    config = TrainingConfig(
        manifests=[manifest],
        output=tmp_path / "fine-tuned",
        epochs=1,
        batch_size=2,
        max_steps=1,
        initialize_from=parent,
    )
    _ = train(config)
    first = Artifact.model_validate_json((config.output / "artifact.json").read_bytes())
    # When resuming that initialized run with identical data/config and a higher epoch limit.
    _ = train(config.model_copy(update={"resume": True, "epochs": 2}))
    # Then epoch one completes and the original parent is still intact.
    resumed = Artifact.model_validate_json((config.output / "artifact.json").read_bytes())
    assert first.epoch == 0
    assert resumed.epoch == 1
    assert resumed.parent_checkpoint_sha256 == parent.checkpoint_sha256
    assert sha256(baseline / "checkpoint.pt") == parent.checkpoint_sha256
    assert sha256(baseline / "artifact.json") == parent.artifact_sha256
