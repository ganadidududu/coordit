"""Explicit publisher-to-measurement landmark mapping, without inferred seam coordinates."""

import os
from pathlib import Path
from typing import Final

from coordit_ml.provenance import approved_entry, audit_records, write_records
from coordit_ml.schema import Landmark, PipelineError, Record, Registry

_MAPPINGS: Final = {
    "tshirt": {
        "shoulder_left": "shoulder_left",
        "shoulder_right": "shoulder_right",
        "armpit_left": "armpit_left",
        "armpit_right": "armpit_right",
    },
    "shorts": {
        "waist_left": "waist_left",
        "waist_right": "waist_right",
        "crotch": "crotch",
        "side_waist": "waist_left",
        "side_hem": "pipe_left_outer",
    },
}


def mapped_landmarks(record: Record) -> list[Landmark]:
    """Copy documented source points; missing/occluded labels never become visible targets."""
    source = {point.landmark_type.removeprefix("artf:"): point for point in record.source_keypoints}
    return [
        source[name].model_copy(update={"landmark_type": target, "source": "artf_publisher_anatomical_candidate_v1"})
        for target, name in _MAPPINGS.get(record.category, {}).items()
        if name in source and source[name].visibility > 0
    ]


def prepare_artf_landmarks(manifest: Path, output: Path, registry: Registry) -> Path:
    """Create a new corpus identity; preserve original files, denylist and training-only grouping."""
    entry = approved_entry(registry, "artf-1.0.1")
    if "semantic_keypoints" not in entry.annotation_types:
        raise PipelineError("aRTF semantic mapping has not been reviewed")
    records = audit_records(manifest, registry)
    if any(record.source_dataset != entry.id or record.split != "train" for record in records):
        raise PipelineError("Only the reviewed aRTF publisher training pool may be relabeled")
    output.mkdir(parents=True, exist_ok=False)
    (output / "images").mkdir()
    converted: list[Record] = []
    for record in records:
        filename = f"images/{record.sha256}.png"
        os.link(manifest.parent / record.file_name, output / filename)
        converted.append(
            record.model_copy(
                update={
                    "file_name": filename,
                    "keypoints": mapped_landmarks(record),
                    "acquisition_metadata": record.acquisition_metadata.model_copy(
                        update={"label_provenance": "publisher_manual_anatomical_labels_not_cm_or_seam_certification"}
                    ),
                }
            )
        )
    target = output / "records.jsonl"
    write_records(target, converted)
    _ = audit_records(target, registry)
    return target
