"""Reject geometrically unsupported research proposals before a mobile device can apply them."""

import math

import torch

from coordit_ml.schema import Landmark, dimension_landmarks


def rejection_reason(category: str, points: list[Landmark], mask: torch.Tensor) -> str | None:
    """Raw scores are rejection heuristics, never calibrated accuracy or a centimeter interval."""
    dimensions = dimension_landmarks(category)
    if not dimensions:
        return "unsupported_auxiliary_category"
    height, width = mask.shape
    foreground = mask.nonzero()
    fraction = len(foreground) / (height * width)
    if not 0.025 <= fraction <= 0.9:
        return "invalid_segmentation_coverage"
    lookup = {point.landmark_type: point for point in points}
    for start_name, end_name in dimensions.values():
        start, end = lookup.get(start_name), lookup.get(end_name)
        if start is None or end is None or start.visibility != 2 or end.visibility != 2:
            return "landmarks_missing_or_occluded"
        if min(start.confidence, end.confidence) < 0.7:
            return "landmark_score_too_low"
        if math.hypot(start.x - end.x, start.y - end.y) < 0.025:
            return "collapsed_measurement_segment"
        for point in (start, end):
            distance = (
                ((foreground[:, 1] / width - point.x).square() + (foreground[:, 0] / height - point.y).square())
                .min()
                .sqrt()
            )
            if float(distance) > 0.06:
                return "landmark_outside_garment_mask"
    return None
