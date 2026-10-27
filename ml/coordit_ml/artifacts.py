"""Typed local model artifacts; checkpoint payloads are restricted and never downloaded."""

from pathlib import Path
from typing import ClassVar, Literal

import torch
from pydantic import ConfigDict
from torch import Tensor

from coordit_ml.schema import BoundaryModel


class ManifestPin(BoundaryModel):
    """A corpus identity is pinned by content."""

    path: str
    sha256: str


class OptimizerState(BoundaryModel):
    """AdamW numeric/tensor state with no executable Python objects."""

    state: dict[int, dict[str, Tensor | float | int]]
    param_groups: list[dict[str, list[int] | tuple[float, float] | float | bool | None]]
    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, arbitrary_types_allowed=True)


class CheckpointState(BoundaryModel):
    """Parse the result of the weights-only Torch boundary once."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, arbitrary_types_allowed=True)
    model: dict[str, Tensor]
    optimizer: OptimizerState
    rng: Tensor
    epoch: int


class Artifact(BoundaryModel):
    """Deployment approval is a separate future process; smoke artifacts cannot assert it."""

    architecture: Literal["coordit-tiny-multitask-v1"]
    fingerprint: str
    checkpoint_sha256: str
    epoch: int
    device: str
    category_heads: bool
    deployment_approved: Literal[False]
    purpose: Literal["cpu_smoke", "development_training"]
    app_artifact: None
    server_artifact: str
    manifests: list[ManifestPin]
    registry_sha256: str
    dataset_images: int
    images_seen_this_epoch: int
    unique_images_seen_this_epoch: int
    seen_image_ids: list[str]
    steps: int
    loss: float
    categories_seen: dict[str, int]
    synthetic_images_seen: int
    code_license: str
    weights_license: str
    training_config_json: str


def read_checkpoint(path: Path) -> CheckpointState:
    """Only trusted local files enter torch.load; arbitrary pickle globals are forbidden."""
    raw: dict[str, dict[str, Tensor] | Tensor | int | OptimizerState] = torch.load(
        path, map_location="cpu", weights_only=True
    )
    return CheckpointState.model_validate(raw)
