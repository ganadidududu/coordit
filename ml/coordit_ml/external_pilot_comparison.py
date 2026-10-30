"""Score frozen external proposals only after the public-photo packet and responses are pinned."""

import json
from pathlib import Path

import torch
from PIL import Image

from coordit_ml.external_pilot import TARGETS, ExternalPredictions, PilotReceipt, require_public_artf
from coordit_ml.external_pilot_metrics import PhotoMetrics, matched_length_summaries, photo_metrics, summarize_photos
from coordit_ml.finetuning import initialize
from coordit_ml.history import HistoryPin, load_history
from coordit_ml.network import image_tensor
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import LANDMARKS, BoundaryModel, PipelineError, read_registry
from coordit_ml.training import load_model


class ExternalComparison(BoundaryModel):
    """Response hash must be frozen before GT comparison; source images remain local except public payloads."""

    receipt: Path
    receipt_sha256: str
    predictions: Path
    predictions_sha256: str
    protocol: Path
    output: Path


def compare_external_pilot(config: ExternalComparison) -> Path:
    """No confidence filtering, no inferred hidden GT, no AI Hub egress and no automatic training import."""
    if sha256(config.receipt) != config.receipt_sha256 or sha256(config.predictions) != config.predictions_sha256:
        raise PipelineError("Pilot packet or frozen external responses changed")
    receipt = PilotReceipt.model_validate_json(config.receipt.read_bytes())
    external = ExternalPredictions.model_validate_json(config.predictions.read_bytes())
    if external.receipt_sha256 != config.receipt_sha256 or external.protocol_sha256 != sha256(config.protocol):
        raise PipelineError("External response protocol or packet differs from the frozen experiment")
    if sha256(receipt.preparation.manifest) != receipt.manifest_sha256:
        raise PipelineError("Pilot source truth changed after image sampling")
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    entry = approved_entry(registry, "artf-1.0.1")
    dataset = PublisherTestDataset(receipt.preparation.manifest, registry)
    records = {record.image_id: record for _, record in dataset.samples}
    predictions = {item.case_id: item for item in external.predictions}
    if len(predictions) != len(external.predictions) or set(predictions) != {case.case_id for case in receipt.cases}:
        raise PipelineError("Missing, duplicate or unexpected external image response")
    root = config.receipt.parent.resolve()
    external_scores: list[PhotoMetrics] = []
    for case in receipt.cases:
        record = records[case.source_image_id]
        require_public_artf(record, entry.data_license)
        pixels = (root / case.image_file).resolve()
        response = predictions[case.case_id]
        if (
            not pixels.is_relative_to(root)
            or sha256(pixels) != record.sha256
            or case.image_sha256 != record.sha256
            or response.image_sha256 != record.sha256
            or case.category != record.category
            or (case.width, case.height) != (record.width, record.height)
        ):
            raise PipelineError("Pilot image identity or dimensions changed")
        proposals = {
            point.landmark_type: None if point.x is None or point.y is None else (point.x, point.y)
            for point in response.points
        }
        if len(proposals) != len(response.points):
            raise PipelineError("Duplicate external landmark names")
        external_scores.append(photo_metrics(case.case_id, record, proposals))
    all_scores = {"external_visual_assistant": external_scores}
    torch.set_num_threads(2)
    for baseline in receipt.preparation.baselines:
        history = load_history(
            [HistoryPin(artifact=baseline.model.directory / "artifact.json", sha256=baseline.model.artifact_sha256)]
        )
        if any(history.overlaps(records[case.source_image_id]) for case in receipt.cases):
            raise PipelineError("Compared model has trained on pilot photos")
        model = load_model(baseline.model.directory)
        initialize(model, baseline.model)
        rows: list[PhotoMetrics] = []
        with torch.inference_mode():
            for case in receipt.cases:
                record = records[case.source_image_id]
                with Image.open(root / case.image_file) as image:
                    prediction = model.forward(image_tensor(image, model.input_size).unsqueeze(0))
                points = {
                    name: (
                        float(prediction.points[0, LANDMARKS.index(name), 0]),
                        float(prediction.points[0, LANDMARKS.index(name), 1]),
                    )
                    for name in TARGETS[record.category]
                }
                rows.append(photo_metrics(case.case_id, record, points))
        if baseline.name in all_scores:
            raise PipelineError("Baseline names must be unique")
        all_scores[baseline.name] = rows
    report = {
        "receipt_sha256": config.receipt_sha256,
        "predictions_sha256": config.predictions_sha256,
        "protocol_sha256": external.protocol_sha256,
        "execution": external.execution,
        "model_identity": external.model_identity,
        "exact_model_revision": external.exact_model_revision,
        "baselines": [b.model_dump(mode="json") for b in receipt.preparation.baselines],
        "source_manifest_sha256": receipt.manifest_sha256,
        "attribution": receipt.attribution,
        "license": receipt.license,
        "images": len(receipt.cases),
        "summary": {name: summarize_photos(rows) for name, rows in all_scores.items()},
        "matched_lengths_on_external_supplied_pairs": matched_length_summaries(all_scores, "external_visual_assistant"),
        "per_photo": {name: [row.model_dump() for row in rows] for name, rows in all_scores.items()},
        "cm_accuracy": None,
        "deployment_approved": False,
        "training_data_created": False,
        "aihub_images_transmitted": False,
        "limitations": [
            "Single interactive assistant trial; no separate provider API invocation or exact model revision",
            "No labels or baseline points supplied in image payloads; protocol self-report, not independent blinding",
            "Eight development photos; public-model pretraining overlap and garment/session independence unknown",
            "Publisher anatomical points, not certified tailoring seam ground truth; pixel lengths are not cm",
            "Unique common targets omit duplicate side_waist; these scores differ from prior 561-photo target sets",
            "Abstention NME penalty is an explicit upper bound of 1, not a measured missing-point coordinate error",
        ],
    }
    with config.output.open("x") as output:
        _ = output.write(json.dumps(report, indent=2, allow_nan=False) + "\n")
    return config.output
