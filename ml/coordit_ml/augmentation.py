"""Coordinate-preserving geometry and lighting augmentation; no new semantic labels are invented."""

import math
import random
from typing import Annotated

import torch
from pydantic import Field
from torch.nn import functional

from coordit_ml.network import Sample
from coordit_ml.schema import BoundaryModel, PipelineError


class Augmentation(BoundaryModel):
    """Small rigid image changes retain the publisher's side definitions; mirroring is intentionally absent."""

    rotation_degrees: Annotated[float, Field(ge=0, le=45)] = 20
    shift_fraction: Annotated[float, Field(ge=0, le=0.2)] = 0.06
    scale_min: Annotated[float, Field(gt=0)] = 0.85
    scale_max: Annotated[float, Field(gt=0)] = 1.15
    brightness_min: Annotated[float, Field(gt=0)] = 0.7
    brightness_max: Annotated[float, Field(gt=0)] = 1.3


class Warp(BoundaryModel):
    """Forward image transform in normalized top-left coordinates, about the image center."""

    angle_degrees: float
    scale: Annotated[float, Field(gt=0)]
    tx: float
    ty: float
    brightness: Annotated[float, Field(gt=0)]


def apply_warps(target: Sample, warps: list[Warp]) -> Sample:
    """Warp RGB, mask and all known points together; cropped landmarks cannot become visible truth."""
    if len(warps) != len(target.pixels):
        raise PipelineError("Each sample needs one explicit augmentation transform")
    matrices: list[list[list[float]]] = []
    inverse: list[list[list[float]]] = []
    for warp in warps:
        angle = math.radians(warp.angle_degrees)
        c, s = math.cos(angle), math.sin(angle)
        matrices.append([[warp.scale * c, -warp.scale * s], [warp.scale * s, warp.scale * c]])
        inverse.append(
            [
                [c / warp.scale, s / warp.scale, -2 * (c * warp.tx + s * warp.ty) / warp.scale],
                [-s / warp.scale, c / warp.scale, -2 * (-s * warp.tx + c * warp.ty) / warp.scale],
            ]
        )
    device = target.pixels.device
    forward = torch.tensor(matrices, device=device, dtype=target.pixels.dtype)
    theta = torch.tensor(inverse, device=device, dtype=target.pixels.dtype)
    shift = torch.tensor([[w.tx, w.ty] for w in warps], device=device, dtype=target.pixels.dtype)
    grid = functional.affine_grid(theta, list(target.pixels.shape), align_corners=False)
    pixels = functional.grid_sample(target.pixels, grid, align_corners=False, padding_mode="zeros")
    coverage = functional.grid_sample(
        torch.ones_like(target.pixels[:, :1]), grid, align_corners=False, padding_mode="zeros"
    )
    pixels = pixels + (1 - coverage) * target.pixels.mean(dim=(2, 3), keepdim=True)
    brightness = torch.tensor([w.brightness for w in warps], device=device, dtype=target.pixels.dtype)
    pixels = (pixels * brightness[:, None, None, None]).clamp(0, 1)
    mask = functional.grid_sample(target.mask, grid, mode="nearest", align_corners=False, padding_mode="zeros")
    points = torch.bmm(target.points - 0.5, forward.transpose(1, 2)) + 0.5 + shift[:, None, :]
    outside = ((points < 0) | (points > 1)).any(dim=2)
    visibility = torch.where(outside & (target.visibility >= 0), 0.0, target.visibility)
    return Sample(pixels, target.category, mask, points.clamp(0, 1), visibility, target.mask_supervision)


def augment_batch(target: Sample, policy: Augmentation, generator: random.Random) -> Sample:
    """Recorded epoch RNG produces deterministic transforms for exact-run resume."""
    if policy.scale_min > policy.scale_max or policy.brightness_min > policy.brightness_max:
        raise PipelineError("Augmentation ranges are reversed")
    warps = [
        Warp(
            angle_degrees=generator.uniform(-policy.rotation_degrees, policy.rotation_degrees),
            scale=generator.uniform(policy.scale_min, policy.scale_max),
            tx=generator.uniform(-policy.shift_fraction, policy.shift_fraction),
            ty=generator.uniform(-policy.shift_fraction, policy.shift_fraction),
            brightness=generator.uniform(policy.brightness_min, policy.brightness_max),
        )
        for _ in target.pixels
    ]
    return apply_warps(target, warps)
