from pathlib import Path

import pytest
import torch

from coordit_ml.finetuning import ParentCheckpoint, initialize
from coordit_ml.heatmap_network import GarmentHeatmapNet
from coordit_ml.high_resolution import GarmentHeatmapNet256Context
from coordit_ml.model_factory import create_model
from coordit_ml.provenance import sha256
from coordit_ml.schema import PipelineError
from coordit_ml.synthetic import generate
from coordit_ml.training import TrainingConfig, load_model, train


def test_high_resolution_preserves_parent_weights_and_requires_explicit_transfer(tmp_path: Path) -> None:
    # Given a completed low-resolution checkpoint with fixed architecture and source pins.
    manifest = generate(tmp_path / "source", 1)
    directory = tmp_path / "low-resolution"
    _ = train(
        TrainingConfig(
            manifests=[manifest],
            output=directory,
            epochs=1,
            batch_size=1,
            max_steps=1,
            architecture="coordit-spatial-multitask-v2",
        )
    )
    parent = ParentCheckpoint(
        directory=directory,
        checkpoint_sha256=sha256(directory / "checkpoint.pt"),
        artifact_sha256=sha256(directory / "artifact.json"),
    )
    high = create_model("coordit-spatial-multitask-v3-256", category_heads=False)
    # When explicitly transferring the spatial family, then all weights and parent bytes remain exact.
    with pytest.raises(PipelineError, match="architecture"):
        initialize(high, parent)
    initialize(high, parent.model_copy(update={"allow_resolution_transfer": True}))
    low = load_model(directory)
    assert all(torch.equal(a, b) for a, b in zip(low.parameters(), high.parameters(), strict=True))
    assert sha256(directory / "checkpoint.pt") == parent.checkpoint_sha256
    assert sha256(directory / "artifact.json") == parent.artifact_sha256


def test_high_resolution_training_and_loading_keep_actual_spatial_outputs(tmp_path: Path) -> None:
    # Given approved authored fixture data and a genuinely higher-resolution architecture.
    manifest = generate(tmp_path / "source", 1)
    config = TrainingConfig(
        manifests=[manifest],
        output=tmp_path / "high",
        epochs=1,
        batch_size=1,
        max_steps=1,
        architecture="coordit-spatial-multitask-v3-256",
    )
    # When taking an actual optimization step and loading the saved artifact.
    _ = train(config)
    model = load_model(config.output)
    result = model.forward(torch.zeros(1, 3, model.input_size, model.input_size))
    # Then the saved model really consumes 256 RGB and emits 128 heatmaps, not renamed 128 inference.
    assert model.input_size == 256
    assert result.mask.shape[-2:] == (256, 256)
    assert result.heatmaps is not None
    assert result.heatmaps.shape[-2:] == (128, 128)
    assert bool(torch.isfinite(result.points).all())


def test_resolution_transfer_never_allows_an_unrelated_architecture(tmp_path: Path) -> None:
    # Given an actually trained tiny-v1 parent whose architecture cannot supply spatial-v3 weights.
    manifest = generate(tmp_path / "source", 1)
    directory = tmp_path / "tiny"
    _ = train(TrainingConfig(manifests=[manifest], output=directory, epochs=1, batch_size=1, max_steps=1))
    parent = ParentCheckpoint(
        directory=directory,
        checkpoint_sha256=sha256(directory / "checkpoint.pt"),
        artifact_sha256=sha256(directory / "artifact.json"),
        allow_resolution_transfer=True,
    )
    # When explicitly requesting a resolution transfer, then family compatibility still blocks it.
    with pytest.raises(PipelineError, match="architecture"):
        initialize(create_model("coordit-spatial-multitask-v3-256", category_heads=False), parent)


def test_context_convolution_preserves_low_resolution_sampling_on_a_doubled_image() -> None:
    # Given identical filters at low resolution and on a nearest-neighbor doubled image.
    low, high = GarmentHeatmapNet(), GarmentHeatmapNet256Context()
    _ = high.load_state_dict(low.state_dict(), strict=True)
    pixels = torch.rand(1, 3, 32, 32)
    doubled = pixels.repeat_interleave(2, dim=2).repeat_interleave(2, dim=3)
    # When the high-resolution encoder samples with expanded context.
    original = low.encoder0.first.forward(pixels)
    expanded = high.encoder0.first.forward(doubled)[:, :, ::2, ::2]
    # Then sampling covers the same original spatial neighborhood, rather than a tighter one.
    assert torch.allclose(original, expanded, atol=1e-6)
