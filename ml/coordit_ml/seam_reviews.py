"""Local seam annotation review boundary; model suggestions cannot enter supervised learning."""

import os
from pathlib import Path
from typing import Literal

from coordit_ml.provenance import approved_entry, audit_records, sha256, write_records
from coordit_ml.schema import BoundaryModel, Landmark, PipelineError, Record, Registry


class ReviewedPoint(BoundaryModel):
    """Explicit source pixel evidence and tailoring protocol for each reviewed visible seam."""

    landmark: Landmark
    review_status: Literal["proposal", "verified", "rejected"]
    reviewer: str
    protocol: str
    evidence: str


class SeamReview(BoundaryModel):
    """Source identity prevents applying coordinates to another crop, orientation or garment."""

    image_id: str
    image_sha256: str
    coordinate_system: Literal["upright_rgb_normalized_top_left"]
    points: list[ReviewedPoint]


class ReviewImport(BoundaryModel):
    """Private source photos and annotations remain local; immutable output corpus is separate."""

    manifest: Path
    reviews: Path
    output: Path


def import_seam_reviews(config: ReviewImport, registry: Registry) -> Path:
    """Only verified, source-matched visible seam points are eligible; empty or draft imports fail."""
    reviews = [SeamReview.model_validate_json(line) for line in config.reviews.read_text().splitlines() if line]
    if not reviews or len({review.image_id for review in reviews}) != len(reviews):
        raise PipelineError("Empty or duplicate seam review set")
    records = {record.image_id: record for record in audit_records(config.manifest, registry)}
    for review in reviews:
        if review.image_id not in records:
            raise PipelineError("Seam annotation source image is unknown")
        record = records[review.image_id]
        entry = approved_entry(registry, record.source_dataset)
        if "semantic_keypoints" not in entry.annotation_types:
            raise PipelineError("Source semantic annotation scope requires explicit registry review")
        if record.sha256 != review.image_sha256:
            raise PipelineError("Seam annotation coordinates reference another image/crop")
        if not review.points or any(
            point.review_status != "verified"
            or not point.reviewer.strip()
            or not point.protocol.strip()
            or not point.evidence.strip()
            or point.landmark.visibility != 2
            for point in review.points
        ):
            raise PipelineError("Only explicitly verified visible seams can enter training")
        points = {point.landmark_type: point for point in record.keypoints}
        points.update({point.landmark.landmark_type: point.landmark for point in review.points})
        target = record.model_dump()
        target["keypoints"] = [point.model_dump() for point in points.values()]
        records[review.image_id] = Record.model_validate(target)
    converted = list(records.values())
    config.output.mkdir(parents=True, exist_ok=False)
    for record in converted:
        for name in (record.file_name, record.mask_file_name):
            if name:
                target = config.output / name
                target.parent.mkdir(parents=True, exist_ok=True)
                os.link(config.manifest.parent / name, target)
    manifest = config.output / "records.jsonl"
    write_records(manifest, converted)
    _ = audit_records(manifest, registry)
    _ = (config.output / "review-evidence.sha256").write_text(sha256(config.reviews) + "\n")
    return manifest
