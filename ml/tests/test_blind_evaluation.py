from pathlib import Path

import pytest

from coordit_ml.aihub_blind_evaluation import BlindEvaluation, evaluate_aihub_blind
from coordit_ml.finetuning import ParentCheckpoint
from coordit_ml.history import HistoryPin
from coordit_ml.provenance import sha256
from coordit_ml.schema import PipelineError
from coordit_ml.synthetic import generate
from coordit_ml.training import TrainingConfig, train


def test_no_human_blind_annotations_produces_no_metrics_file(tmp_path: Path) -> None:
    # Given a real CPU fixture checkpoint and a still-empty local blind review.
    manifest = generate(tmp_path / "source", 1)
    model = tmp_path / "model"
    _ = train(TrainingConfig(manifests=[manifest], output=model, epochs=1, batch_size=2, max_steps=1))
    parent = ParentCheckpoint(
        directory=model,
        checkpoint_sha256=sha256(model / "checkpoint.pt"),
        artifact_sha256=sha256(model / "artifact.json"),
    )
    tasks, reviews = tmp_path / "tasks.jsonl", tmp_path / "reviews.jsonl"
    _ = tasks.write_text("")
    _ = reviews.write_text("")
    config = BlindEvaluation(
        tasks=tasks,
        tasks_sha256=sha256(tasks),
        reviews=reviews,
        reviews_sha256=sha256(reviews),
        history=[HistoryPin(artifact=model / "artifact.json", sha256=parent.artifact_sha256)],
        baseline=parent,
        candidate=parent,
        output=tmp_path / "metrics.json",
    )
    # When scoring, then absent human ground truth is a blocking failure, not PCK zero or a passing result.
    with pytest.raises(PipelineError, match="No human-verified"):
        _ = evaluate_aihub_blind(config)
    assert not config.output.exists()
