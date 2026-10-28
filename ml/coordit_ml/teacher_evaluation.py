"""Frozen final-checkpoint comparisons on the same untouched public evaluation photographs."""

import json
from collections import defaultdict
from pathlib import Path

import torch

from coordit_ml.artifacts import Artifact
from coordit_ml.external_pilot import TARGETS, PilotBaseline, PilotReceipt
from coordit_ml.external_pilot_metrics import PhotoMetrics, photo_metrics, summarize_photos
from coordit_ml.finetuning import initialize
from coordit_ml.history import HistoryPin, load_history
from coordit_ml.provenance import REGISTRY_ROOT, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import LANDMARKS, BoundaryModel, PipelineError, read_registry
from coordit_ml.seam_comparison import LandmarkMetric
from coordit_ml.training import load_model


class TeacherEvaluation(BoundaryModel):
    """No best-epoch selection or teacher annotations are allowed in the evaluation corpus."""

    manifest: Path
    manifest_sha256: str
    pilot_packet: Path
    pilot_packet_sha256: str
    models: list[PilotBaseline]
    output: Path


class TeacherModelScore(BoundaryModel):
    """Common unique targets and legacy mapped targets are explicitly different denominators."""

    name: str
    checkpoint_sha256: str
    artifact_sha256: str
    common_unique_targets: dict[str, dict[str, float | int | None]]
    legacy_all_mapped_targets: dict[str, LandmarkMetric]
    mask_iou_per_category: dict[str, float]
    macro_miou: float
    previous_eight_photo_subset: dict[str, dict[str, float | int | None]]


def score_teacher_model(
    spec: PilotBaseline, dataset: PublisherTestDataset, pilot_ids: frozenset[str],
) -> TeacherModelScore:
    """One forward pass per photo scores all visible GT regardless of model confidence."""
    model = load_model(spec.model.directory)
    initialize(model, spec.model)
    dataset.image_size = model.input_size
    points: list[PhotoMetrics] = []
    pilot: list[PhotoMetrics] = []
    legacy: dict[str, list[float]] = defaultdict(list)
    masks: dict[str, list[float]] = defaultdict(list)
    with torch.inference_mode():
        for index, (_, record) in enumerate(dataset.samples):
            sample = dataset[index]
            prediction = model.forward(sample.pixels.unsqueeze(0))
            proposed = {
                name: (float(prediction.points[0, LANDMARKS.index(name), 0]),
                       float(prediction.points[0, LANDMARKS.index(name), 1]))
                for name in TARGETS[record.category]
            }
            row = photo_metrics(record.image_id, record, proposed)
            points.append(row)
            if record.image_id in pilot_ids:
                pilot.append(row)
            error = (prediction.points[0] - sample.points).square().sum(-1).sqrt() / 2**0.5
            legacy[record.category].extend(float(v) for v in error[sample.visibility > 0])
            if record.segmentation_supervised:
                inferred, truth = prediction.mask[0].sigmoid() >= 0.5, sample.mask >= 0.5
                masks[record.category].append(
                    float((inferred & truth).sum() / (inferred | truth).sum().clamp_min(1))
                )
    mean_masks = {name: sum(values) / len(values) for name, values in masks.items()}
    return TeacherModelScore(
        name=spec.name, checkpoint_sha256=spec.model.checkpoint_sha256,
        artifact_sha256=spec.model.artifact_sha256,
        common_unique_targets=summarize_photos(points),
        legacy_all_mapped_targets={
            name: LandmarkMetric(points=len(values), pck_005=sum(v <= 0.05 for v in values) / len(values),
                                 nme=sum(values) / len(values))
            for name, values in legacy.items()
        },
        mask_iou_per_category=mean_masks, macro_miou=sum(mean_masks.values()) / len(mean_masks),
        previous_eight_photo_subset=summarize_photos(pilot),
    )


def evaluate_teacher_models(config: TeacherEvaluation) -> Path:
    """Reaudit actual training histories against the full test pool before any metric is computed."""
    if sha256(config.manifest) != config.manifest_sha256 or sha256(config.pilot_packet) != config.pilot_packet_sha256:
        raise PipelineError("Evaluation corpus or previous pilot packet changed")
    if not config.models or len({m.name for m in config.models}) != len(config.models):
        raise PipelineError("Comparison models must be nonempty and uniquely named")
    torch.set_num_threads(2)
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    dataset = PublisherTestDataset(config.manifest, registry)
    history = load_history([
        HistoryPin(artifact=m.model.directory / "artifact.json", sha256=m.model.artifact_sha256)
        for m in config.models
    ])
    if any(history.overlaps(record) for _, record in dataset.samples):
        raise PipelineError("Evaluation photo overlaps the compared models' training history")
    pilot = PilotReceipt.model_validate_json(config.pilot_packet.read_bytes())
    ids = {record.image_id: record for _, record in dataset.samples}
    if any(case.source_image_id not in ids or ids[case.source_image_id].sha256 != case.image_sha256
           for case in pilot.cases):
        raise PipelineError("Previous pilot is not an unchanged subset of this evaluation corpus")
    pilot_ids = frozenset(case.source_image_id for case in pilot.cases)
    models = [score_teacher_model(m, dataset, pilot_ids) for m in config.models]
    artifacts = {
        m.name: Artifact.model_validate_json((m.model.directory / "artifact.json").read_bytes()).model_dump()
        for m in config.models
    }
    report = {
        "evaluation": config.model_dump(mode="json"), "images": len(dataset),
        "evaluation_images_in_training": 0, "independent_cm_study": False,
        "models": [m.model_dump() for m in models], "artifacts": artifacts,
        "cm_accuracy": None, "deployment_approved": False, "candidate_promoted": False,
        "limitations": [
            "Frozen development evaluation, repeatedly used; no new independent real-device study",
            "Physical garment/session IDs and public teacher pretraining overlap remain unresolved",
            "Primary PCK/NME omit duplicate side_waist; legacy mapped metrics retain it",
            "PCK threshold 0.05 of normalized square-input diagonal is not a 1cm tolerance",
            "Pixel segment errors are projected 2D distances, not AR cm error",
            "New teacher-only endpoints lack independent GT and are not included in accuracy claims",
            "AI Hub is local mask/classification supervision only; no AI Hub seam accuracy is measured",
            "No final-checkpoint test score was used for epoch or hyperparameter selection",
        ],
    }
    with config.output.open("x") as stream:
        _ = stream.write(json.dumps(report, indent=2, allow_nan=False) + "\n")
    return config.output
