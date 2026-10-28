"""Train local segmentation from reviewed AI Hub bytes; preserve native cm targets separately."""

import hashlib
import re
from collections import Counter
from pathlib import Path
from typing import Final

from PIL import Image
from pydantic import Field

from coordit_ml.aihub import QuarantinedPair, audit_aihub
from coordit_ml.provenance import approved_entry, perceptual_hash, sha256, write_records
from coordit_ml.schema import Acquisition, BoundaryModel, PipelineError, Record, Registry

LABELS: Final = {"01outer_01coat": "coat", "01outer_02jacket": "jacket"}


class AIHubConversion(BoundaryModel):
    """Only reviewed unambiguous categories; conservative train-only grouping, no invented real holdout."""

    source: Path
    output: Path
    maximum_per_category: int = Field(default=10_000, ge=1)


class ConversionReport(BoundaryModel):
    """Actual distinct accepted images and supervision types."""

    accepted_images: int
    category_counts: dict[str, int]
    excluded: dict[str, int]
    real_seam_supervision_images: int = 0
    cm_regression_training_images: int = 0
    real_independent_validation_images: int = 0
    training_only: bool = True


def normalize_pair_record(pair: QuarantinedPair, config: AIHubConversion, license_id: str) -> Record:
    """Normalize pixels and matching polygons without EXIF-induced coordinate changes."""
    source, output = config.source, config.output
    identity = re.fullmatch(r"(\d+)_sou_(\d+)_(\d+)_(front|back|wear)_.+", pair.source_name)
    if identity is None:
        raise PipelineError("Unknown source identity format; refusing guessed grouping")
    filename = f"images/{pair.image_sha256}.jpg"
    original = source / pair.image_path
    if sha256(original) != pair.image_sha256:
        raise PipelineError("AI Hub source changed after audit")
    with Image.open(original) as pixels:
        normalized = pixels.convert("RGB")
        normalized.thumbnail((1024, 1024))
        normalized.save(output / filename, quality=92)
        width, height = normalized.size
    polygons = [
        [
            value * (width / pair.width if index % 2 == 0 else height / pair.height)
            for index, value in enumerate(polygon)
        ]
        for polygon in pair.segmentation
    ]
    coordinates = [value for polygon in polygons for value in polygon]
    if not coordinates:
        raise PipelineError("Missing real segmentation polygon")
    xs, ys = coordinates[::2], coordinates[1::2]
    left, top, right, bottom = min(xs), min(ys), max(xs), max(ys)
    return Record(
        image_id=f"aihub-71501:{pair.image_sha256}",
        garment_id=f"aihub-71501:{identity[1]}:{identity[2]}",
        source_group="aihub-71501:reviewed-acquisition-training-only",
        category=LABELS[pair.source_category],
        source_dataset="aihub-71501",
        original_license=license_id,
        license_status="approved",
        source_url=pair.source_url,
        source_path=pair.image_path,
        split="train",
        file_name=filename,
        sha256=sha256(output / filename),
        original_sha256=pair.image_sha256,
        perceptual_hash=perceptual_hash(output / filename),
        width=width,
        height=height,
        bbox=[left, top, right - left, bottom - top],
        segmentation=polygons,
        keypoints=[],
        measurement_ground_truth={},
        acquisition_metadata=Acquisition(
            synthetic=False,
            source_category=pair.source_category,
            label_provenance="original_publisher_polygon; native_cm_in_source_measurements_sidecar_not_seam_targets",
        ),
    )


def convert_aihub(config: AIHubConversion, registry: Registry) -> Path:
    """Enforce the reviewed training grant before decoding actual source pixels."""
    entry = approved_entry(registry, "aihub-71501")
    if config.output.exists() or not config.source.is_dir():
        raise PipelineError("Use an existing source and a fresh conversion directory")
    config.output.mkdir(parents=True)
    _ = audit_aihub(config.source, config.output / "audit")
    pairs = [
        QuarantinedPair.model_validate_json(line)
        for line in (config.output / "audit/quarantined_pairs.jsonl").read_text().splitlines()
    ]
    (config.output / "images").mkdir()
    counts: Counter[str] = Counter()
    excluded: Counter[str] = Counter()
    normalized_hashes: set[str] = set()
    records: list[Record] = []
    accepted_pairs: list[QuarantinedPair] = []
    for pair in pairs:
        category = LABELS.get(pair.source_category)
        if category is None or category not in entry.categories:
            excluded["unreviewed_category"] += 1
            continue
        if "_wear_" in pair.source_name:
            excluded["worn_view_not_flat_garment_target"] += 1
            continue
        if counts[category] >= config.maximum_per_category:
            excluded["per_category_limit"] += 1
            continue
        record = normalize_pair_record(pair, config, entry.data_license)
        if record.sha256 in normalized_hashes:
            excluded["normalized_duplicate"] += 1
            continue
        normalized_hashes.add(record.sha256)
        records.append(record)
        accepted_pairs.append(pair)
        counts[category] += 1
    if not records:
        raise PipelineError("No approved unworn coat/jacket image pairs")
    manifest = config.output / "records.jsonl"
    write_records(manifest, records)
    _ = (config.output / "source_measurements.jsonl").write_text(
        "".join(pair.model_dump_json() + "\n" for pair in accepted_pairs)
    )
    report = ConversionReport(accepted_images=len(records), category_counts=dict(counts), excluded=dict(excluded))
    _ = (config.output / "conversion-report.json").write_text(report.model_dump_json(indent=2) + "\n")
    digest = hashlib.sha256(manifest.read_bytes()).hexdigest()
    _ = (config.output / "records.sha256").write_text(digest + "\n")
    return manifest
