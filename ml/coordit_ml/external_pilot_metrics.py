"""Identical visible-target metrics for external proposals and local model outputs; no centimeter claims."""

import math
from collections import defaultdict
from collections.abc import Mapping

from coordit_ml.external_pilot import TARGETS
from coordit_ml.schema import BoundaryModel, PipelineError, Record, dimension_landmarks


class PixelLength(BoundaryModel):
    """Original-image projected segment; a missing prediction never becomes zero error."""

    dimension: str
    ground_truth_pixels: float
    predicted_pixels: float | None
    absolute_error_pixels: float | None
    relative_error: float | None


class PhotoMetrics(BoundaryModel):
    """All visible publisher targets remain in the denominator, including external abstentions."""

    case_id: str
    category: str
    point_errors: dict[str, float | None]
    lengths: list[PixelLength]


def photo_metrics(
    case_id: str,
    record: Record,
    proposals: Mapping[str, tuple[float, float] | None],
) -> PhotoMetrics:
    """Compute normalized-square point errors and original-pixel length errors from the same GT."""
    if set(proposals) != set(TARGETS[record.category]):
        raise PipelineError("Proposal target set differs from the predeclared common target set")
    truth = {
        p.landmark_type: p
        for p in record.keypoints
        if p.visibility == 2 and p.landmark_type in TARGETS[record.category]
    }
    errors: dict[str, float | None] = {}
    for name, point in truth.items():
        inferred = proposals[name]
        errors[name] = (
            None if inferred is None else math.hypot(inferred[0] - point.x, inferred[1] - point.y) / math.sqrt(2)
        )
    lengths: list[PixelLength] = []
    for dimension, (start, end) in dimension_landmarks(record.category).items():
        if start not in truth or end not in truth:
            continue
        a, b = truth[start], truth[end]
        actual = math.hypot((a.x - b.x) * record.width, (a.y - b.y) * record.height)
        p, q = proposals[start], proposals[end]
        inferred_length = (
            None if p is None or q is None else math.hypot((p[0] - q[0]) * record.width, (p[1] - q[1]) * record.height)
        )
        lengths.append(
            PixelLength(
                dimension=dimension,
                ground_truth_pixels=actual,
                predicted_pixels=inferred_length,
                absolute_error_pixels=None if inferred_length is None else abs(inferred_length - actual),
                relative_error=None
                if inferred_length is None or actual == 0
                else abs(inferred_length - actual) / actual,
            )
        )
    return PhotoMetrics(case_id=case_id, category=record.category, point_errors=errors, lengths=lengths)


def summarize_photos(photos: list[PhotoMetrics]) -> dict[str, dict[str, float | int | None]]:
    """Observed NME is conditional; explicit diagonal-upper-bound penalty prevents abstention cherry-picking."""
    groups: dict[str, list[PhotoMetrics]] = defaultdict(list)
    for photo in photos:
        groups[photo.category].append(photo)
        groups["all"].append(photo)
    result: dict[str, dict[str, float | int | None]] = {}
    for category, rows in groups.items():
        errors = [value for row in rows for value in row.point_errors.values()]
        observed = [value for value in errors if value is not None]
        result[category] = {
            "images": len(rows),
            "visible_gt_points": len(errors),
            "supplied_points": len(observed),
            "abstentions_on_visible_gt": len(errors) - len(observed),
            "coverage": len(observed) / len(errors) if errors else None,
            "pck_005_all_visible_gt": sum(e <= 0.05 for e in observed) / len(errors) if errors else None,
            "nme_supplied_only": sum(observed) / len(observed) if observed else None,
            "nme_with_abstention_penalty_1": (sum(observed) + len(errors) - len(observed)) / len(errors)
            if errors
            else None,
        }
        dimensions = {length.dimension for row in rows for length in row.lengths}
        for dimension in sorted(dimensions):
            lengths = [length for row in rows for length in row.lengths if length.dimension == dimension]
            pixel_errors = [p.absolute_error_pixels for p in lengths if p.absolute_error_pixels is not None]
            relative_errors = [p.relative_error for p in lengths if p.relative_error is not None]
            result[f"{category}/{dimension}"] = {
                "eligible_pairs": len(lengths),
                "supplied_pairs": len(pixel_errors),
                "failed_pairs": len(lengths) - len(pixel_errors),
                "coverage": len(pixel_errors) / len(lengths),
                "mean_absolute_error_pixels_supplied_only": sum(pixel_errors) / len(pixel_errors)
                if pixel_errors
                else None,
                "mean_relative_error_supplied_only": sum(relative_errors) / len(relative_errors)
                if relative_errors
                else None,
            }
    return result


def matched_length_summaries(
    scores: Mapping[str, list[PhotoMetrics]],
    external_name: str,
) -> dict[str, dict[str, dict[str, float | int | None]]]:
    """Secondary matched-pair errors share the same images; primary failures remain in the full summary."""
    shared_pairs = {
        (row.case_id, length.dimension)
        for row in scores[external_name]
        for length in row.lengths
        if length.predicted_pixels is not None
    }
    reports: dict[str, dict[str, dict[str, float | int | None]]] = {}
    for name, rows in scores.items():
        matched = [
            row.model_copy(
                update={
                    "lengths": [length for length in row.lengths if (row.case_id, length.dimension) in shared_pairs],
                }
            )
            for row in rows
        ]
        reports[name] = {key: value for key, value in summarize_photos(matched).items() if "/" in key}
    return reports
