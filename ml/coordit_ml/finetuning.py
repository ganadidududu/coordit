"""Reviewed initialization from preserved checkpoints, distinct from exact-run resume."""

from pathlib import Path

from coordit_ml.artifacts import Artifact, read_checkpoint
from coordit_ml.model_factory import PerceptionModel
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, audit_records, sha256
from coordit_ml.schema import BoundaryModel, PipelineError, read_registry


class ParentCheckpoint(BoundaryModel):
    """Explicit immutable baseline selected for initialization, never rewritten in place."""

    directory: Path
    checkpoint_sha256: str
    artifact_sha256: str
    allow_resolution_transfer: bool = False


def initialize(model: PerceptionModel, parent: ParentCheckpoint) -> None:
    """Revalidate original source grants now, then copy model weights with a fresh optimizer."""
    checkpoint = parent.directory / "checkpoint.pt"
    metadata_path = parent.directory / "artifact.json"
    if sha256(checkpoint) != parent.checkpoint_sha256 or sha256(metadata_path) != parent.artifact_sha256:
        raise PipelineError("Parent checkpoint or metadata differs from explicit pin")
    metadata = Artifact.model_validate_json(metadata_path.read_bytes())
    spatial_versions = {
        "coordit-spatial-multitask-v2", "coordit-spatial-multitask-v3-256", "coordit-spatial-multitask-v3-512",
        "coordit-spatial-multitask-v4-256-context",
    }
    compatible_resolution_transfer = (
        parent.allow_resolution_transfer
        and model.model_version in spatial_versions
        and metadata.architecture in spatial_versions
    )
    expected_parent_size = {
        "coordit-tiny-multitask-v1": 64, "coordit-spatial-multitask-v2": 128,
        "coordit-spatial-multitask-v3-256": 256, "coordit-spatial-multitask-v3-512": 512,
        "coordit-spatial-multitask-v4-256-context": 256,
    }[metadata.architecture]
    if (
        metadata.checkpoint_sha256 != parent.checkpoint_sha256
        or (model.model_version != metadata.architecture and not compatible_resolution_transfer)
        or metadata.input_size != expected_parent_size
        or model.category_heads != metadata.category_heads
    ):
        raise PipelineError("Parent checkpoint architecture/hash mismatch")
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    for pin in metadata.manifests:
        manifest = Path(pin.path)
        if sha256(manifest) != pin.sha256:
            raise PipelineError("Parent training manifest changed")
        for record in audit_records(manifest, registry):
            _ = approved_entry(registry, record.source_dataset)
    state = read_checkpoint(checkpoint)
    _ = model.load_state_dict(state.model, strict=True)
