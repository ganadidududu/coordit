"""Versioned model construction keeps old checkpoints loadable."""

from typing import Literal, assert_never

from torch import Tensor

from coordit_ml.heatmap_network import GarmentHeatmapNet, spatial_loss
from coordit_ml.high_resolution import GarmentHeatmapNet256, GarmentHeatmapNet256Context, GarmentHeatmapNet512
from coordit_ml.network import GarmentNet, Prediction, Sample, loss

Architecture = Literal[
    "coordit-tiny-multitask-v1", "coordit-spatial-multitask-v2",
    "coordit-spatial-multitask-v3-256", "coordit-spatial-multitask-v3-512",
    "coordit-spatial-multitask-v4-256-context",
]
PerceptionModel = GarmentNet | GarmentHeatmapNet


def create_model(architecture: Architecture, category_heads: bool) -> PerceptionModel:
    """Construct the architecture recorded in the artifact, never guess from a filename."""
    match architecture:
        case "coordit-tiny-multitask-v1":
            return GarmentNet(category_heads)
        case "coordit-spatial-multitask-v2":
            return GarmentHeatmapNet(category_heads)
        case "coordit-spatial-multitask-v3-256":
            return GarmentHeatmapNet256(category_heads)
        case "coordit-spatial-multitask-v3-512":
            return GarmentHeatmapNet512(category_heads)
        case "coordit-spatial-multitask-v4-256-context":
            return GarmentHeatmapNet256Context(category_heads)
        case unreachable:
            assert_never(unreachable)


def model_loss(architecture: Architecture, prediction: Prediction, target: Sample) -> Tensor:
    """Preserve the v1 objective while adding spatial supervision for v2."""
    match architecture:
        case "coordit-tiny-multitask-v1":
            return loss(prediction, target)
        case (
            "coordit-spatial-multitask-v2" | "coordit-spatial-multitask-v3-256"
            | "coordit-spatial-multitask-v3-512" | "coordit-spatial-multitask-v4-256-context"
        ):
            return spatial_loss(prediction, target)
        case unreachable:
            assert_never(unreachable)
