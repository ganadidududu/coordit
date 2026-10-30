"""Classification-only conversion from the original author's pinned real photo shards."""

import hashlib
import io
import json
from collections import Counter
from pathlib import Path
from typing import ClassVar, Final

import polars as pl
from PIL import Image, ImageOps
from pydantic import BaseModel, ConfigDict, Field, TypeAdapter

from coordit_ml.provenance import approved_entry, group_splits, perceptual_hash, sha256, write_records
from coordit_ml.schema import Acquisition, BoundaryModel, PipelineError, Record, Registry
from coordit_ml.secondhand_download import DATASET_ID, verify_source_pins
from coordit_ml.source_downloads import PinnedFile

# Sweater and Outerwear deliberately remain unmapped: neither identifies a fine class reliably.
LABELS: Final = {
    "Shirt": "shirt",
    "Hoodie": "hoodie",
    "Cardigan": "knit",
    "Jacket": "jacket",
    "Denim Jacket": "jacket",
    "Blazer": "jacket",
    "Trousers": "pants",
    "Jeans": "jeans",
    "Skirt": "skirt",
    "T-shirt": "tshirt",
    "Shorts": "shorts",
}


class SourceImage(BoundaryModel):
    """Original author-supplied embedded image and source garment filename."""

    bytes: bytes
    path: str


class SourceGarment(BaseModel):
    """Only required metadata crosses into training; free text/people/brand fields are discarded."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    image: SourceImage
    type: str


class CategoryReview(BoundaryModel):
    """A hash-bound, explicitly named visual fine-category review; never a seam/mask label."""

    source_path: str
    original_sha256: str
    category: str | None
    reviewer: str
    reason: str


class ConversionConfig(BoundaryModel):
    """Keep whole garments/capture days together and original publisher test outside development."""

    source: Path
    output: Path
    reviews: Path | None = None
    training_only: bool = True
    maximum_per_category: int = Field(default=100_000, ge=1)


def _record(item: SourceGarment, context: tuple[Path, PinnedFile, int], category: str) -> Record:
    root, pin, index = context
    identifier = f"{DATASET_ID}:{Path(pin.path).stem}:{index}"
    raw_hash = hashlib.sha256(item.image.bytes).hexdigest()
    with Image.open(io.BytesIO(item.image.bytes)) as original:
        if original.width * original.height > 12_000_000:
            raise PipelineError("Source photograph exceeds pixel budget")
        image = ImageOps.exif_transpose(original).convert("RGB")
        image.thumbnail((1024, 1024))
        filename = f"images/{Path(pin.path).stem}-{index}.jpg"
        image.save(root / filename, quality=92)
        width, height = image.size
    identity = Path(item.image.path).stem.removeprefix("front_")
    parts = identity.split("_")
    if len(parts) < 3 or not all(part.isdigit() for part in parts[:3]):
        raise PipelineError("Missing source capture date; cannot establish session groups")
    return Record(
        image_id=identifier,
        garment_id=f"{DATASET_ID}:garment:{identity}",
        category=category,
        source_dataset=DATASET_ID,
        original_license="CC-BY-4.0",
        license_status="approved",
        source_url=pin.url,
        source_path=item.image.path,
        source_group=f"{DATASET_ID}:capture_day:{'_'.join(parts[:3])}",
        split="train",
        file_name=filename,
        sha256=sha256(root / filename),
        original_sha256=raw_hash,
        perceptual_hash=perceptual_hash(root / filename),
        width=width,
        height=height,
        bbox=[0, 0, width, height],
        segmentation=[],
        segmentation_supervised=False,
        keypoints=[],
        acquisition_metadata=Acquisition(
            synthetic=False,
            background="sorting_facility_table",
            source_category=item.type,
            label_provenance="publisher_expert_category",
        ),
    )


def convert_secondhand(config: ConversionConfig, registry: Registry) -> Path:
    """No fabricated masks, landmarks, item dimensions, or use of publisher test images for fitting."""
    entry = approved_entry(registry, DATASET_ID)
    pins = TypeAdapter(list[PinnedFile]).validate_json((config.source / "DOWNLOAD_PINS.json").read_bytes())
    verify_source_pins(pins)
    reviews = TypeAdapter(list[CategoryReview]).validate_json(config.reviews.read_bytes()) if config.reviews else []
    lookup = {review.source_path: review for review in reviews}
    if len(lookup) != len(reviews):
        raise PipelineError("Duplicate category review")
    config.output.mkdir(parents=True, exist_ok=False)
    (config.output / "images").mkdir()
    counts: Counter[str] = Counter()
    excluded: Counter[str] = Counter()
    records: list[Record] = []
    hashes: set[str] = set()
    normalized_hashes: dict[str, str] = {}
    conflicts: set[str] = set()
    for pin in sorted(pins, key=lambda row: row.path):
        source = config.source / pin.path
        if not source.is_file() or sha256(source) != pin.sha256:
            raise PipelineError("Official shard hash mismatch or incomplete acquisition")
        if Path(pin.path).name.startswith("test-"):
            excluded["publisher_test_rows"] += 3390
            continue
        rows = pl.read_parquet(source, columns=["image", "type"])
        for index, raw in enumerate(rows.iter_rows(named=True)):
            item = SourceGarment.model_validate(raw)
            review = lookup.get(item.image.path)
            raw_hash = hashlib.sha256(item.image.bytes).hexdigest()
            if review and (review.original_sha256 != raw_hash or not review.reason or not review.reviewer):
                raise PipelineError("Unbound or incomplete fine-category review")
            category = review.category if review else LABELS.get(item.type)
            if category is None:
                excluded[f"unmapped_or_rejected/{item.type}"] += 1
                continue
            if category not in entry.categories:
                raise PipelineError("Fine category outside source approval")
            if raw_hash in hashes:
                excluded["exact_duplicate"] += 1
                continue
            if counts[category] >= config.maximum_per_category:
                excluded[f"quota/{category}"] += 1
                continue
            record = _record(item, (config.output, pin, index), category)
            if review:
                record = record.model_copy(
                    update={
                        "acquisition_metadata": record.acquisition_metadata.model_copy(
                            update={"label_provenance": "codex_visual_fine_category_review_not_human_seam_truth"}
                        )
                    }
                )
            previous_category = normalized_hashes.get(record.sha256)
            if previous_category is not None:
                excluded["normalized_duplicate"] += 1
                if previous_category != category:
                    conflicts.add(record.sha256)
                continue
            normalized_hashes[record.sha256] = category
            hashes.add(raw_hash)
            counts[category] += 1
            records.append(record)
    manifest = config.output / "records.jsonl"
    accepted = [record for record in records if record.sha256 not in conflicts]
    excluded["conflicting_duplicate_labels"] = len(records) - len(accepted)
    grouped = (
        [record.model_copy(update={"split": "train"}) for record in accepted]
        if config.training_only
        else group_splits(accepted)
    )
    counts = Counter(record.category for record in grouped)
    write_records(manifest, grouped)
    _ = (config.output / "conversion-report.json").write_text(
        json.dumps(
            {
                "accepted": dict(counts),
                "excluded": dict(excluded),
                "label_scope": "classification_only",
                "centimeter_ground_truth": 0,
                "mask_ground_truth": 0,
                "seam_ground_truth": 0,
                "splits": dict(Counter(record.split for record in grouped)),
            },
            indent=2,
        )
        + "\n"
    )
    return manifest
