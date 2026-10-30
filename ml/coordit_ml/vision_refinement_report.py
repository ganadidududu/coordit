"""Paired public-photo scores with visible-only AR usability, abstentions and uncalibrated pixel lengths."""

import hashlib
import json
import math
import statistics
from pathlib import Path

from pydantic import TypeAdapter

from coordit_ml.external_pilot import TARGETS
from coordit_ml.external_pilot_metrics import PhotoMetrics, PixelLength, photo_metrics, summarize_photos
from coordit_ml.provenance import REGISTRY_ROOT, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import BoundaryModel, PipelineError, Record, read_registry
from coordit_ml.vision_api_inputs import load_public_photos, request_bytes
from coordit_ml.vision_api_types import ApiAnnotation, ApiAttempt
from coordit_ml.vision_refinement_runner import RefinementConfig, verify_refinement


class MetricProfile(BoundaryModel):
    """Same target denominator for tentative coordinates and visible-only point usage."""

    legacy_square_normalization: dict[str, dict[str, float | int | None]]
    native_pixels: dict[str, float | int | None]
    per_photo: list[PhotoMetrics]


class ModelRefinementScore(BoundaryModel):
    """Paired per-model outcomes with actual added cost and complete two-pass time."""

    model: str
    images: int
    scheduled_images: int
    preflight_rejections: int
    not_executed: int
    variants: dict[str, dict[str, MetricProfile]]
    additional_calls: int
    failures: int
    additional_provider_cost_usd: float
    two_pass_provider_cost_usd: float
    cost_complete: bool
    mean_additional_seconds: float | None
    mean_two_pass_seconds: float | None
    providers: list[str]


def usable_proposals(
    annotation: ApiAnnotation | None, category: str, *, visible_only: bool
) -> dict[str, tuple[float, float] | None]:
    """The app rejects uncertain points; measure that coverage separately from speculative coordinate accuracy."""
    result: dict[str, tuple[float, float] | None] = dict.fromkeys(TARGETS[category])
    if annotation:
        for point in annotation.points:
            if point.x is not None and point.y is not None and (not visible_only or point.status == "visible_proposal"):
                result[point.landmark_type] = (point.x, point.y)
    return result


def measurement_metrics(case_id: str, record: Record, proposals: dict[str, tuple[float, float] | None]) -> PhotoMetrics:
    """Include the documented waist_left/side_waist alias for projected shorts outseam, never infer new GT."""
    result = photo_metrics(case_id, record, proposals)
    truth = {p.landmark_type: p for p in record.keypoints if p.visibility == 2}
    if record.category != "shorts" or "waist_left" not in truth or "side_hem" not in truth:
        return result
    a, b = truth["waist_left"], truth["side_hem"]
    length = math.hypot((a.x - b.x) * record.width, (a.y - b.y) * record.height)
    p, q = proposals["waist_left"], proposals["side_hem"]
    predicted = (
        None if p is None or q is None else math.hypot((p[0] - q[0]) * record.width, (p[1] - q[1]) * record.height)
    )
    segment = PixelLength(
        dimension="outseam",
        ground_truth_pixels=length,
        predicted_pixels=predicted,
        absolute_error_pixels=None if predicted is None else abs(predicted - length),
        relative_error=None if predicted is None or length == 0 else abs(predicted - length) / length,
    )
    return result.model_copy(update={"lengths": [*result.lengths, segment]})


def compare_refinement(config: RefinementConfig, output: Path, *, allow_partial: bool = False) -> Path:
    """Score frozen proposals against unchanged targets; never edit coordinates using these results."""
    receipt, photos = load_public_photos(config.baseline)
    refined = verify_refinement(config, allow_partial=allow_partial)
    parents = TypeAdapter(list[ApiAttempt]).validate_json(config.parent_attempts.read_bytes())
    baseline = {(p.model_requested, p.case_id): p for p in parents}
    reviewed = {(r.attempt.model_requested, r.attempt.case_id): r for r in refined}
    dataset = PublisherTestDataset(receipt.preparation.manifest, read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json"))
    records = {r.image_id: r for _, r in dataset.samples}
    results: list[ModelRefinementScore] = []
    for model in config.baseline.models:
        variants: dict[str, dict[str, MetricProfile]] = {}
        paired = [
            p
            for p in photos
            if (model, p.case.case_id) in reviewed
            and reviewed[model, p.case.case_id].attempt.http_status not in (401, 402, 403)
        ]
        for stage in ("baseline_full_cohort", "baseline", "self_review"):
            profiles: dict[str, MetricProfile] = {}
            for visible in (False, True):
                metrics: list[PhotoMetrics] = []
                pixel_errors: list[float] = []
                pixel_normalized: list[float] = []
                eligible = 0
                for photo in photos if stage == "baseline_full_cohort" else paired:
                    key = model, photo.case.case_id
                    parent = baseline[key]
                    if (
                        parent.request_sha256
                        != hashlib.sha256(request_bytes(model, photo, config.baseline)).hexdigest()
                    ):
                        raise PipelineError("Baseline request does not match the audited photo/protocol")
                    annotation = reviewed[key].original_annotation if stage == "self_review" else parent.annotation
                    proposals = usable_proposals(annotation, photo.case.category, visible_only=visible)
                    record = records[photo.case.source_image_id]
                    metrics.append(measurement_metrics(photo.case.case_id, record, proposals))
                    for truth in record.keypoints:
                        if truth.visibility != 2 or truth.landmark_type not in proposals:
                            continue
                        eligible += 1
                        prediction = proposals[truth.landmark_type]
                        if prediction:
                            distance = math.hypot(
                                (prediction[0] - truth.x) * record.width, (prediction[1] - truth.y) * record.height
                            )
                            pixel_errors.append(distance)
                            pixel_normalized.append(distance / math.hypot(record.width, record.height))
                profiles["visible_only_ar_usable" if visible else "all_coordinate_proposals"] = (
                    MetricProfile.model_validate(
                        {
                            "legacy_square_normalization": summarize_photos(metrics),
                            "native_pixels": {
                                "visible_gt": eligible,
                                "supplied": len(pixel_errors),
                                "mae_pixels_supplied_only": statistics.mean(pixel_errors) if pixel_errors else None,
                                "nme_image_diagonal_supplied_only": statistics.mean(pixel_normalized)
                                if pixel_normalized
                                else None,
                                "pck_002_all_gt": sum(e <= 0.02 for e in pixel_normalized) / eligible
                                if eligible
                                else None,
                                "pck_005_all_gt": sum(e <= 0.05 for e in pixel_normalized) / eligible
                                if eligible
                                else None,
                            },
                            "per_photo": [r.model_dump() for r in metrics],
                        }
                    )
                )
            variants[stage] = profiles
        all_calls = [r.attempt for r in refined if r.attempt.model_requested == model]
        calls = [reviewed[model, p.case.case_id].attempt for p in paired]
        originals = [baseline[model, p.case.case_id] for p in paired]
        review_costs = [a.response.usage.cost for a in all_calls if a.response and a.response.usage]
        parent_costs = [a.response.usage.cost for a in originals if a.response and a.response.usage]
        all_costs = [*review_costs, *parent_costs]
        results.append(
            ModelRefinementScore.model_validate(
                {
                    "model": model,
                    "images": len(paired),
                    "scheduled_images": len(photos),
                    "preflight_rejections": sum(a.http_status in (401, 402, 403) for a in all_calls),
                    "not_executed": len(photos) - len(paired),
                    "variants": variants,
                    "additional_calls": len(all_calls),
                    "failures": sum(a.failure is not None for a in all_calls),
                    "additional_provider_cost_usd": sum(c for c in review_costs if c is not None),
                    "two_pass_provider_cost_usd": sum(c for c in all_costs if c is not None),
                    "cost_complete": len(all_costs) == len(all_calls) + len(calls)
                    and all(c is not None for c in all_costs),
                    "mean_additional_seconds": statistics.mean(a.elapsed_seconds for a in calls) if calls else None,
                    "mean_two_pass_seconds": statistics.mean(
                        a.elapsed_seconds + b.elapsed_seconds for a, b in zip(calls, originals, strict=True)
                    )
                    if calls
                    else None,
                    "providers": sorted({a.response.provider for a in calls if a.response and a.response.provider}),
                }
            )
        )
    report = {
        "config": config.model_dump(mode="json"),
        "parent_attempts_sha256": config.parent_attempts_sha256,
        "refinements_sha256": sha256(config.output / "refinements.json")
        if (config.output / "refinements.json").exists()
        else None,
        "refinement_receipts_sha256": {
            p.name: sha256(p) for p in sorted(config.output.glob("*.mapped.json"))
        },
        "models": [r.model_dump() for r in results],
        "comparison_is_partial": allow_partial,
        "cm_accuracy": None,
        "training_data_created": False,
        "deployment_approved": False,
        "aihub_images_transmitted": 0,
        "phase_3_changed": False,
        "attribution": receipt.attribution,
        "limitations": [
            "Publisher anatomical labels are not certified stitching/seam or centimeter truth",
            "Scene/image split is not proof of physical garment independence or unknown pretraining exposure",
            "3x resizing allocates a larger view; it does not create original high-resolution detail",
            "No favorable-result selection, model substitution, invisible-point filling or inference retry",
        ],
    }
    with output.open("x") as stream:
        _ = stream.write(json.dumps(report, indent=2, allow_nan=False) + "\n")
    return output
