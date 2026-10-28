"""Audit private AI Hub 71501 image/measurement pairs without granting training rights."""

import math
from collections import Counter, defaultdict
from pathlib import Path, PurePosixPath
from typing import Annotated, ClassVar, Literal

from PIL import Image
from pydantic import BaseModel, BeforeValidator, ConfigDict, Field

from coordit_ml.provenance import sha256
from coordit_ml.schema import BoundaryModel, PipelineError


def _nullable_number(value: str | float | None) -> float | None:
    """Accept publisher numeric strings and explicit nulls, never fabricated zero labels."""
    if value is None or str(value).strip().lower() in {"null", "none", "", "n/a"}:
        return None
    number = float(value)
    if number == 0:
        return None
    if not math.isfinite(number) or not 0 < number < 999:
        raise PipelineError("Invalid AI Hub clothing measurement")
    return number


Number = Annotated[float | None, BeforeValidator(_nullable_number)]


class SourceDataset(BaseModel):
    """Publisher uses literal dotted JSON keys, not nested dotted paths."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    name: str = Field(alias="dataset.name", min_length=1)
    image_path: str = Field(alias="dataset.image_path", min_length=1)
    width: int = Field(alias="dataset.width", gt=0)
    height: int = Field(alias="dataset.height", gt=0)


class Clothes(BaseModel):
    """Only clothing metadata is read; wearer body measurements are deliberately excluded."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    category: str = Field(alias="metadata.clothes.type")
    front_length: Number = Field(default=None, alias="metadata.top.front_length")
    chest: Number = Field(default=None, alias="metadata.top.chest_size")
    shoulder: Number = Field(default=None, alias="metadata.top.shoulder_width")
    sleeve: Number = Field(default=None, alias="metadata.top.sleeve_length")
    pants_length: Number = Field(default=None, alias="metadata.pants.pants_length")
    waist: Number = Field(default=None, alias="metadata.pants.waist_size")
    hip: Number = Field(default=None, alias="metadata.pants.hip_size")
    rise: Number = Field(default=None, alias="metadata.pants.front_rise_length")
    inseam: Number = Field(default=None, alias="metadata.pants.inner_seam_length")
    skirt_length: Number = Field(default=None, alias="metadata.skirt.length")
    skirt_waist: Number = Field(default=None, alias="metadata.skirt.waist_size")
    skirt_hip: Number = Field(default=None, alias="metadata.skirt.hip_size")


class Polygon(BaseModel):
    """Polygon vertices remain segmentation, never seam keypoints."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore", allow_inf_nan=False)
    kind: Literal["Polygon"] = Field(alias="annotation_type")
    points: list[float] = Field(alias="annotation_point", min_length=6)


class SourceLabel(BaseModel):
    """Public format example; no personal model metadata is retained."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    dataset: SourceDataset
    clothes: Clothes = Field(alias="metadata.clothes")
    annotation: list[Polygon]


class MeasurementTarget(BoundaryModel):
    """Native cm meaning verified in the guide, without claiming image seam coordinates."""

    source_field: str
    value: float
    quantity: Literal["linear", "circumference", "seam_length"]
    unit: Literal["cm"] = "cm"
    protocol_verified: Literal[True] = True
    coordit_endpoints_verified: Literal[False] = False
    protocol_source_sha256: str = "68f3aaa3a7fe00d645f9967e5941dde2f0e7b320d03daa9b043d77e4fbabfe5e"


def measurement_targets(clothes: Clothes) -> list[MeasurementTarget]:
    """Keep circumferences intact: no silent division by two or front-length remapping."""
    fields: list[tuple[str, float | None, Literal["linear", "circumference", "seam_length"]]] = [
        ("metadata.top.front_length", clothes.front_length, "linear"),
        ("metadata.top.chest_size", clothes.chest, "circumference"),
        ("metadata.top.shoulder_width", clothes.shoulder, "linear"),
        ("metadata.top.sleeve_length", clothes.sleeve, "linear"),
        ("metadata.pants.pants_length", clothes.pants_length, "linear"),
        ("metadata.pants.waist_size", clothes.waist, "circumference"),
        ("metadata.pants.hip_size", clothes.hip, "circumference"),
        ("metadata.pants.front_rise_length", clothes.rise, "seam_length"),
        ("metadata.pants.inner_seam_length", clothes.inseam, "linear"),
        ("metadata.skirt.length", clothes.skirt_length, "linear"),
        ("metadata.skirt.waist_size", clothes.skirt_waist, "circumference"),
        ("metadata.skirt.hip_size", clothes.skirt_hip, "circumference"),
    ]
    return [
        MeasurementTarget(source_field=name, value=value, quantity=kind)
        for name, value, kind in fields
        if value is not None
    ]


class QuarantinedPair(BoundaryModel):
    """Private preparation output is deliberately incompatible with approved training Record."""

    source_dataset: Literal["aihub-71501"] = "aihub-71501"
    license_status: Literal["pending_review"] = "pending_review"
    training_eligible: Literal[False] = False
    source_url: str = "https://aihub.or.kr/aihubdata/data/view.do?dataSetSn=71501"
    source_name: str
    source_category: str
    label_path: str
    label_sha256: str
    image_path: str
    image_sha256: str
    width: int
    height: int
    segmentation: list[list[float]]
    targets: list[MeasurementTarget]
    semantic_landmark_count: Literal[0] = 0
    split: Literal["quarantine"] = "quarantine"
    grouping_verified: Literal[False] = False


class PairAudit(BoundaryModel):
    """Counts describe actually inspected local bytes, never website totals."""

    inspected_labels: int
    matched_unique_images: int
    missing_images: int
    duplicate_images: int
    conflicting_duplicate_images: int = 0
    source_categories: dict[str, int]
    measurement_fields: dict[str, int]
    approved_training_images: Literal[0] = 0
    seam_ground_truth_images: Literal[0] = 0
    blockers: tuple[str, ...] = (
        "download approval and dataset-specific rights evidence",
        "Coordit endpoint compatibility: chest at armpit vs publisher 1 inch below; back shoulder; waistband basis",
        "garment/capture identity mapping and independent split review",
        "semantic seam annotations absent in public polygon schema",
    )


def _check_image_size(image: Path, dataset: SourceDataset) -> None:
    """Refuse a label/image coordinate mismatch before using any polygon vertices."""
    with Image.open(image) as pixels:
        if pixels.size != (dataset.width, dataset.height):
            raise PipelineError("Source image dimensions do not match label; refusing coordinate mismatch")


def _checked_polygons(label: SourceLabel) -> list[list[float]]:
    """Check every original vertex before assigning normalized image coordinates."""
    polygons = [annotation.points for annotation in label.annotation]
    if any(
        len(polygon) % 2
        or any(x < 0 or x > label.dataset.width for x in polygon[::2])
        or any(y < 0 or y > label.dataset.height for y in polygon[1::2])
        for polygon in polygons
    ):
        raise PipelineError("AI Hub polygon outside publisher image dimensions")
    return polygons


def audit_aihub(source: Path, output: Path) -> PairAudit:
    """Match extracted private source/label files and write a fresh quarantined inventory."""
    if output.exists() or not source.is_dir():
        raise PipelineError("Use an existing extracted source directory and a fresh output directory")
    root = source.resolve()
    images: defaultdict[str, list[Path]] = defaultdict(list)
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".jpg", ".jpeg", ".png"}:
            if not path.resolve().is_relative_to(root):
                raise PipelineError("Source image escapes private dataset root")
            images[path.name].append(path)
    labels = sorted(root.rglob("*.json"))
    if not labels:
        raise PipelineError("No actual AI Hub labels found; refusing empty success")
    pairs: list[QuarantinedPair] = []
    seen: set[str] = set()
    signatures: dict[str, str] = {}
    conflicts: set[str] = set()
    missing = duplicates = 0
    for path in labels:
        if not path.resolve().is_relative_to(root):
            raise PipelineError("Source label escapes private dataset root")
        label = SourceLabel.model_validate_json(path.read_bytes())
        matches = images[PurePosixPath(label.dataset.image_path.replace("\\", "/")).name]
        if not matches:
            missing += 1
            continue
        hashes = {sha256(image) for image in matches}
        if len(hashes) != 1:
            raise PipelineError("Ambiguous image filename joins different image bytes")
        image = matches[0]
        _check_image_size(image, label.dataset)
        digest = next(iter(hashes))
        signature = label.clothes.model_dump_json()
        if digest in seen:
            duplicates += 1
            if signatures[digest] != signature:
                conflicts.add(digest)
            continue
        seen.add(digest)
        signatures[digest] = signature
        polygons = _checked_polygons(label)
        pairs.append(
            QuarantinedPair(
                source_name=label.dataset.name,
                source_category=label.clothes.category,
                label_path=str(path.relative_to(root)),
                label_sha256=sha256(path),
                image_path=str(image.relative_to(root)),
                image_sha256=digest,
                width=label.dataset.width,
                height=label.dataset.height,
                segmentation=polygons,
                targets=measurement_targets(label.clothes),
            )
        )
    pairs = [pair for pair in pairs if pair.image_sha256 not in conflicts]
    if not pairs:
        raise PipelineError("No image/label pairs matched; no data was prepared for training")
    report = PairAudit(
        inspected_labels=len(labels),
        matched_unique_images=len(pairs),
        missing_images=missing,
        duplicate_images=duplicates,
        conflicting_duplicate_images=len(conflicts),
        source_categories=dict(Counter(pair.source_category for pair in pairs)),
        measurement_fields=dict(Counter(target.source_field for pair in pairs for target in pair.targets)),
    )
    output.mkdir(parents=True)
    _ = (output / "quarantined_pairs.jsonl").write_text("".join(pair.model_dump_json() + "\n" for pair in pairs))
    _ = (output / "audit.json").write_text(report.model_dump_json(indent=2) + "\n")
    return report
