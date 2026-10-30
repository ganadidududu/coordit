"""Weak teacher targets remain separate from publisher truth, masks, visibility and centimeter labels."""

import math
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import assert_never

import torch
from torch import Tensor
from torch.nn import functional

from coordit_ml.augmentation import Augmentation
from coordit_ml.external_pilot import ExternalPoint
from coordit_ml.network import Prediction
from coordit_ml.schema import LANDMARKS, Landmark, PipelineError, Record
from coordit_ml.teacher_annotations import TeacherPin, read_teacher


def require_brightness_only(augmentation: Augmentation | None) -> None:
    """Reject misaligned teacher coordinates before any optimizer step or output creation."""
    if augmentation and (
        augmentation.rotation_degrees or augmentation.shift_fraction
        or augmentation.scale_min != 1 or augmentation.scale_max != 1
    ):
        raise PipelineError("Teacher targets currently require brightness-only augmentation")


def load_teacher(
    pin: TeacherPin | None, samples: list[tuple[Path, Record]], augmentation: Augmentation | None,
) -> "TeacherTargets | None":
    """Optional integration leaves existing runs unchanged and rejects incompatible image warps."""
    if pin is None:
        return None
    require_brightness_only(augmentation)
    return TeacherTargets.load(pin, [record for _, record in samples])


@dataclass(frozen=True, slots=True)
class WeakPoint:
    """A suggestion has bounded loss weight and never receives human-verified visibility."""

    name: str
    x: float
    y: float
    weight: float


def eligible_point(point: ExternalPoint, original: Landmark | None) -> tuple[WeakPoint | None, str]:
    """Known occlusions and disagreements with publisher truth cannot become teacher supervision."""
    if point.x is None or point.y is None:
        return None, "abstained"
    if original is not None:
        if original.visibility != 2:
            return None, "publisher_not_visible"
        if math.hypot(point.x - original.x, point.y - original.y) / math.sqrt(2) > 0.05:
            return None, "publisher_disagreement"
    match point.status:
        case "visible_proposal":
            weight = 1.0
        case "uncertain_proposal":
            weight = 0.25
        case "abstain":
            return None, "abstained"
        case unreachable:
            assert_never(unreachable)
    return WeakPoint(point.landmark_type, point.x, point.y, weight), (
        "accepted_existing_target" if original else "accepted_new_unverified_target"
    )


@dataclass(frozen=True, slots=True)
class TeacherTargets:
    """Pinned proposals add only a bounded coordinate/heatmap objective on public training images."""

    by_image: dict[str, tuple[WeakPoint, ...]]
    counts: dict[str, int]
    loss_weight: float

    def exposures(self, image_ids: list[str]) -> int:
        """Count actual teacher-bearing photo exposures, never pretend repeats are new photos."""
        return sum(bool(self.by_image.get(image_id)) for image_id in image_ids)

    @classmethod
    def load(cls, pin: TeacherPin, records: list[Record]) -> "TeacherTargets":
        """Parse external inputs once, then retain no private pixels or invented supervised labels."""
        packet, response = read_teacher(pin, records)
        indexed = {r.image_id: r for r in records}
        cases = {c.case_id: c for c in packet.cases}
        counts: Counter[str] = Counter()
        by_image: dict[str, tuple[WeakPoint, ...]] = {}
        for prediction in response.predictions:
            record = indexed[cases[prediction.case_id].source_image_id]
            originals = {p.landmark_type: p for p in record.keypoints}
            points: list[WeakPoint] = []
            for point in prediction.points:
                accepted, reason = eligible_point(point, originals.get(point.landmark_type))
                counts[reason] += 1
                if accepted:
                    points.append(accepted)
            by_image[record.image_id] = tuple(points)
        if not any(by_image.values()):
            raise PipelineError("No eligible teacher targets; cannot report teacher training")
        return cls(by_image, dict(counts), pin.loss_weight)

    def objective(self, prediction: Prediction, image_ids: list[str]) -> Tensor:
        """Teacher abstentions/occlusions contribute zero; no teacher mask, cm or visibility BCE is invented."""
        maps = prediction.heatmaps
        if maps is None:
            raise PipelineError("Teacher training requires a spatial heatmap architecture")
        coordinates = torch.zeros_like(prediction.points)
        weights = torch.zeros_like(prediction.visibility)
        for row, image_id in enumerate(image_ids):
            for point in self.by_image.get(image_id, ()):
                column = LANDMARKS.index(point.name)
                coordinates[row, column, 0] = point.x
                coordinates[row, column, 1] = point.y
                weights[row, column] = point.weight
        height, width = maps.shape[-2:]
        gy, gx = torch.meshgrid(
            (torch.arange(height, device=maps.device) + 0.5) / height,
            (torch.arange(width, device=maps.device) + 0.5) / width,
            indexing="ij",
        )
        dx = gx.flatten()[None, None, :] - coordinates[:, :, 0, None]
        dy = gy.flatten()[None, None, :] - coordinates[:, :, 1, None]
        heat_truth = (-(dx.square() + dy.square()) / (2 * 0.025**2)).softmax(-1)
        heat_error = -(heat_truth * maps.flatten(2).log_softmax(-1)).sum(-1)
        coordinate_error = functional.smooth_l1_loss(prediction.points, coordinates, reduction="none").sum(-1)
        # Normalize by count, not summed confidence, so uncertain-only batches retain their smaller weight.
        return self.loss_weight * ((heat_error + 10 * coordinate_error) * weights).sum() / (
            (weights > 0).sum().clamp_min(1)
        )
