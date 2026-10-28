"""Supervise known projected endpoint distances; no absolute centimeter truth is inferred."""

import torch
from torch import Tensor
from torch.nn import functional

from coordit_ml.network import Prediction, Sample
from coordit_ml.schema import LANDMARKS, dimension_landmarks


def projected_pair_loss(prediction: Prediction, target: Sample, pixel_aspects: Tensor) -> Tensor:
    """Use true source width/height so non-square photographs do not distort the length objective."""
    # All canonical endpoint pairs; visibility masks omit unknown/occluded schema parts.
    pairs = sorted(
        {pair for category in ("tshirt", "pants", "skirt") for pair in dimension_landmarks(category).values()}
    )
    total = prediction.points.sum() * 0
    count = torch.zeros((), device=prediction.points.device)
    scale = torch.stack((pixel_aspects, torch.ones_like(pixel_aspects)), dim=-1)
    for left, right in pairs:
        a, b = LANDMARKS.index(left), LANDMARKS.index(right)
        visible = ((target.visibility[:, a] > 0) & (target.visibility[:, b] > 0)).float()
        truth = ((target.points[:, a] - target.points[:, b]) * scale).square().sum(-1).sqrt()
        # epsilon avoids undefined derivatives if predicted endpoints coincide exactly.
        inferred = (((prediction.points[:, a] - prediction.points[:, b]) * scale).square().sum(-1) + 1e-12).sqrt()
        valid = visible * (truth > 0.025).float()
        relative = (inferred - truth) / truth.clamp_min(0.025)
        values = functional.smooth_l1_loss(relative, torch.zeros_like(relative), reduction="none")
        total = total + (values * valid).sum()
        count = count + valid.sum()
    return total / count.clamp_min(1)
