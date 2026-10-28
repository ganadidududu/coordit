"""Local unseen-photo scoring requires manually reviewed blind annotations, never model pseudo-labels."""

import json
from pathlib import Path
from typing import final

from coordit_ml.aihub_review_queue import AnnotationTask
from coordit_ml.finetuning import ParentCheckpoint
from coordit_ml.history import HistoryPin, load_history
from coordit_ml.network import ApprovedDataset
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, sha256
from coordit_ml.schema import BoundaryModel, PipelineError, Record, Registry, read_registry
from coordit_ml.seam_comparison import score
from coordit_ml.seam_reviews import SeamReview


class BlindEvaluation(BoundaryModel):
    """All images, review evidence and both comparison models are pinned before scoring."""

    tasks: Path
    tasks_sha256: str
    reviews: Path
    reviews_sha256: str
    history: list[HistoryPin]
    baseline: ParentCheckpoint
    candidate: ParentCheckpoint
    output: Path


@final
class BlindAIHubDataset(ApprovedDataset):
    """The normal loader cannot read the held-out source identity, even after manual annotation."""

    def __init__(self, config: BlindEvaluation, registry: Registry) -> None:
        """Reject suggested/edited split labels, missing human truth and any recorded training overlap."""
        super().__init__([], registry, "test")
        grant = approved_entry(registry, "aihub-71501")
        if sha256(config.tasks) != config.tasks_sha256 or sha256(config.reviews) != config.reviews_sha256:
            raise PipelineError("Blind annotation task or review hash changed")
        tasks = {
            task.record.image_id: task
            for line in config.tasks.read_text().splitlines()
            for task in [AnnotationTask.model_validate_json(line)]
        }
        history = load_history(
            config.history
            + [
                HistoryPin(artifact=parent.directory / "artifact.json", sha256=parent.artifact_sha256)
                for parent in (config.baseline, config.candidate)
            ]
        )
        root = config.tasks.parent.resolve()
        seen: set[str] = set()
        for line in config.reviews.read_text().splitlines():
            review = SeamReview.model_validate_json(line)
            if review.image_id not in tasks or review.image_id in seen:
                raise PipelineError("Unknown or duplicate blind review photo")
            seen.add(review.image_id)
            task = tasks[review.image_id]
            record = task.record
            image = (root / record.file_name).resolve()
            if (
                task.purpose != "blind_holdout_candidate"
                or task.proposed_points
                or record.split != "test"
                or record.source_dataset != "aihub71501-evaluation-only-v1"
                or not image.is_relative_to(root)
                or sha256(image) != record.sha256
                or review.image_sha256 != record.sha256
                or record.original_license != grant.data_license
                or record.category not in grant.categories
                or history.overlaps(record)
            ):
                raise PipelineError("Blind image identity, role, rights or training history mismatch")
            if not review.points or any(
                point.review_status != "verified"
                or point.landmark.visibility != 2
                or not point.reviewer.strip()
                or point.protocol != "coordit-upper-seam-v1"
                or not point.evidence.strip()
                for point in review.points
            ):
                raise PipelineError("Blind scoring requires visible human-verified seam truth")
            fields = record.model_dump()
            fields["keypoints"] = [point.landmark.model_dump() for point in review.points]
            self.samples.append((root, Record.model_validate(fields)))
        if not self.samples:
            raise PipelineError("No human-verified blind labels; PCK/NME cannot be calculated")


def evaluate_aihub_blind(config: BlindEvaluation) -> Path:
    """Only actual reviewed coordinates yield metrics; no-label inputs never create a zero/passing score."""
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    dataset = BlindAIHubDataset(config, registry)
    baseline, candidate = score(config.baseline, dataset), score(config.candidate, dataset)
    report = {
        "tasks_sha256": config.tasks_sha256,
        "reviews_sha256": config.reviews_sha256,
        "baseline": baseline.model_dump(),
        "candidate": candidate.model_dump(),
        "source_photos_unseen_by_recorded_training": True,
        "independent_study": False,
        "limitations": [
            "small locally reviewed sample; producer garment/session identity not independently certified",
            "PCK/NME use resized-input diagonal; this is not centimeter or AR sensor accuracy",
        ],
        "cm_accuracy": None,
        "deployment_approved": False,
    }
    with config.output.open("x") as output:
        _ = output.write(json.dumps(report, indent=2, allow_nan=False) + "\n")
    return config.output
