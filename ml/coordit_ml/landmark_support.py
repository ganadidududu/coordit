"""Unsupervised output heads cannot become measurement landmarks at inference time."""

from pathlib import Path

from coordit_ml.artifacts import Artifact
from coordit_ml.provenance import read_records


def trained_landmarks(directory: Path, category: str) -> frozenset[str]:
    """Use only visible labels in samples actually exposed to this run; never infer support from confidence."""
    artifact = Artifact.model_validate_json((directory / "artifact.json").read_bytes())
    exposed = set(artifact.seen_image_ids)
    return frozenset(
        point.landmark_type
        for pin in artifact.manifests
        for record in read_records(Path(pin.path))
        if record.category == category and record.image_id in exposed
        for point in record.keypoints if point.visibility == 2
    )
