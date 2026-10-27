"""Versioned procedural scenes with semantic construction and varied backgrounds."""

from pathlib import Path

from coordit_ml.provenance import group_splits, perceptual_hash, sha256, write_records
from coordit_ml.schema import CATEGORIES, PipelineError, Record
from coordit_ml.synthetic import render_scene
from coordit_ml.synthetic_details import add_details


def generate_v2(destination: Path, per_category: int = 120, seed: int = 257) -> Path:
    """Create new garment identities without re-counting resized/augmented originals."""
    if per_category < 1:
        raise PipelineError("per_category must be positive")
    destination.mkdir(parents=True, exist_ok=False)
    (destination / "images").mkdir()
    (destination / "masks").mkdir()
    records: list[Record] = []
    for category in CATEGORIES:
        for index in range(per_category):
            identity = f"coordit-procedural-v2:{seed}:{category}:{index}"
            record = render_scene(destination, identity, category)
            add_details(destination, record)
            image = destination / record.file_name
            records.append(
                record.model_copy(
                    update={
                        "source_dataset": "coordit-procedural-v2",
                        "source_url": "repo:ml/coordit_ml/synthetic_v2.py",
                        "sha256": sha256(image),
                        "perceptual_hash": perceptual_hash(image),
                    }
                )
            )
    manifest = destination / "records.jsonl"
    write_records(manifest, group_splits(records))
    return manifest
