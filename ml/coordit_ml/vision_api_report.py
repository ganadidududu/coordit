"""Replay frozen API outputs against unchanged public labels; actual cost is never replaced by a token estimate."""

import hashlib
import json
import statistics
from pathlib import Path

import numpy as np
from pydantic import TypeAdapter

from coordit_ml.external_pilot import TARGETS
from coordit_ml.external_pilot_metrics import PhotoMetrics, photo_metrics, summarize_photos
from coordit_ml.provenance import REGISTRY_ROOT, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import BoundaryModel, PipelineError, read_registry
from coordit_ml.vision_api_inputs import load_public_photos, request_bytes, reserve_total
from coordit_ml.vision_api_types import ApiAttempt, BenchmarkConfig


class ApiModelScore(BoundaryModel):
    """Accuracy, measured latency and observed billing keep distinct denominators."""

    requested_model: str
    returned_models: list[str]
    providers: list[str]
    attempts: int
    valid_annotation_responses: int
    valid_response_rate: float
    metric_status: str
    accuracy_including_failed_calls: dict[str, dict[str, float | int | None]]
    lengths_on_same_pairs_supplied_by_all_models: dict[str, dict[str, float | int | None]]
    api_roundtrip_seconds_all_attempts: dict[str, float]
    provider_reported_cost_usd: dict[str, float | int | bool | None]
    tokens: dict[str, int]
    per_photo: list[PhotoMetrics]


def score_api_benchmark(config: BenchmarkConfig, attempts_path: Path, output: Path) -> Path:
    """Retain every visible target, failed call, abstention and reported charge in the same comparison."""
    _ = reserve_total(config)
    receipt, public_photos = load_public_photos(config)
    pixels = {photo.case.case_id: photo for photo in public_photos}
    attempts_hash = sha256(attempts_path)
    attempts = TypeAdapter(list[ApiAttempt]).validate_json(attempts_path.read_bytes())
    expected = {(model, case.case_id) for model in config.models for case in receipt.cases}
    observed = {(a.model_requested, a.case_id) for a in attempts}
    if len(attempts) != len(observed) or observed != expected:
        raise PipelineError("API benchmark attempts must cover the exact model/photo grid without repeats")
    indexed = {(a.model_requested, a.case_id): a for a in attempts}
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    dataset = PublisherTestDataset(receipt.preparation.manifest, registry)
    records = {record.image_id: record for _, record in dataset.samples}
    rows: dict[str, list[PhotoMetrics]] = {}
    for model in config.models:
        photos: list[PhotoMetrics] = []
        for case in receipt.cases:
            attempt = indexed[model, case.case_id]
            if attempt.image_sha256 != case.image_sha256:
                raise PipelineError("API output was generated for another image")
            if attempt.request_sha256 != hashlib.sha256(request_bytes(model, pixels[case.case_id], config)).hexdigest():
                raise PipelineError("API output used another prompt, model, image or inference configuration")
            proposals: dict[str, tuple[float, float] | None] = dict.fromkeys(TARGETS[case.category])
            if attempt.annotation is not None:
                names = [p.landmark_type for p in attempt.annotation.points]
                if attempt.failure is not None or len(set(names)) != len(names) or set(names) != set(proposals):
                    raise PipelineError("API answer has invalid target names or contradictory failure state")
                proposals.update({
                    p.landmark_type: None if p.x is None or p.y is None else (p.x, p.y)
                    for p in attempt.annotation.points
                })
            photos.append(photo_metrics(case.case_id, records[case.source_image_id], proposals))
        rows[model] = photos
    supplied_pairs = [
        {(r.case_id, p.dimension) for r in photos for p in r.lengths if p.predicted_pixels is not None}
        for photos in rows.values()
    ]
    common = supplied_pairs[0].intersection(*supplied_pairs[1:])
    models: list[ApiModelScore] = []
    for model, photos in rows.items():
        calls = [a for a in attempts if a.model_requested == model]
        times = [a.elapsed_seconds for a in calls]
        costs = [a.response.usage.cost for a in calls if a.response and a.response.usage
                 and a.response.usage.cost is not None]
        usable = [a for a in calls if a.annotation is not None]
        common_photos = [r.model_copy(update={
            "lengths": [p for p in r.lengths if (r.case_id, p.dimension) in common],
        }) for r in photos]
        models.append(ApiModelScore.model_validate({
            "requested_model": model,
            "returned_models": sorted({a.response.model for a in calls if a.response and a.response.model}),
            "providers": sorted({a.response.provider for a in calls if a.response and a.response.provider}),
            "attempts": len(calls), "valid_annotation_responses": len(usable),
            "valid_response_rate": len(usable) / len(calls),
            "metric_status": "measured" if usable else "not_measured_no_valid_annotations",
            "accuracy_including_failed_calls": summarize_photos(photos),
            "lengths_on_same_pairs_supplied_by_all_models": {
                name: value for name, value in summarize_photos(common_photos).items() if "/" in name
            },
            "api_roundtrip_seconds_all_attempts": {
                "mean": statistics.mean(times), "median": statistics.median(times),
                "p95_sample_quantile": float(np.quantile(times, 0.95)), "max": max(times),
            },
            "provider_reported_cost_usd": {
                "total_known": sum(costs), "calls_with_cost": len(costs),
                "billing_complete": len(costs) == len(calls),
                "mean_per_scheduled_photo": sum(costs) / len(calls) if len(costs) == len(calls) else None,
                "known_cost_per_valid_response": sum(costs) / len(usable) if usable else None,
            },
            "tokens": {
                "prompt": sum(a.response.usage.prompt_tokens for a in calls if a.response and a.response.usage),
                "completion_including_reasoning": sum(
                    a.response.usage.completion_tokens for a in calls if a.response and a.response.usage
                ),
            },
            "per_photo": [r.model_dump() for r in photos],
        }))
    report = {
        "provider": "OpenRouter", "config": config.model_dump(mode="json"),
        "attempts_sha256": attempts_hash, "images_per_model": len(receipt.cases),
        "models": [model.model_dump() for model in models],
        "total_provider_reported_cost_usd": sum(
            a.response.usage.cost or 0 for a in attempts if a.response and a.response.usage
        ),
        "normalization": "normalized square-input diagonal; PCK@0.05; no calibrated centimeter tolerance",
        "nme_missing_points": "Report native supplied-only NME and explicit missing-point penalty=1 separately",
        "cm_accuracy": None, "training_data_created": False, "deployment_approved": False,
        "aihub_images_transmitted": False, "phase_3_changed": False,
        "attribution": receipt.attribution,
        "limitations": [
            "Eight reused development photos; not a new independent garment or device study",
            "Publisher anatomical labels are not certified tailoring seam or cm truth",
            "One request per photo/model, no inference retries or favorable-output selection",
            "Identical prompt, original pixels, high detail and low effort; effective compute may differ",
            "Requested model IDs may be aliases; response model/provider IDs are preserved, not invented snapshots",
            "Latency includes this Mac-to-OpenRouter round trip, not the complete mobile upload/AR workflow",
            "Eight latency samples per model give a descriptive P95 only, not a service guarantee",
            "Reported cost is actual response usage.cost credits; credit-purchase fees, taxes and own hosting excluded",
            "Public-pretraining exposure and physical garment/session independence are unknown",
        ],
    }
    with output.open("x") as stream:
        _ = stream.write(json.dumps(report, indent=2, allow_nan=False) + "\n")
    return output
