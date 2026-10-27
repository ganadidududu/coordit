"""Typed source and normalized COCO-compatible records; coordinates are explicit."""

from enum import StrEnum
from pathlib import Path
from typing import Annotated, ClassVar, Literal, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

CATEGORIES = ("tshirt", "shirt", "sweatshirt", "hoodie", "knit", "jacket", "coat", "pants", "jeans", "shorts", "skirt")
CLASSES = (*CATEGORIES, "aux_towel", "aux_boxershorts")
LANDMARKS = (
    "shoulder_left",
    "shoulder_right",
    "armpit_left",
    "armpit_right",
    "length_start",
    "hem_center",
    "sleeve_start",
    "sleeve_end",
    "waist_left",
    "waist_right",
    "hip_left",
    "hip_right",
    "waist_center",
    "crotch",
    "side_waist",
    "side_hem",
    "skirt_hem",
)


_UPPER = {
    "shoulder_width": ("shoulder_left", "shoulder_right"),
    "chest_width": ("armpit_left", "armpit_right"),
    "total_length": ("length_start", "hem_center"),
    "sleeve_length": ("sleeve_start", "sleeve_end"),
}
_LOWER = {
    "waist_width": ("waist_left", "waist_right"),
    "hip_width": ("hip_left", "hip_right"),
    "rise": ("waist_center", "crotch"),
    "outseam": ("side_waist", "side_hem"),
}
_SKIRT = {
    "waist_width": ("waist_left", "waist_right"),
    "hip_width": ("hip_left", "hip_right"),
    "total_length": ("waist_center", "skirt_hem"),
}
_SCHEMAS = {
    **dict.fromkeys(CATEGORIES[:7], _UPPER),
    **dict.fromkeys(("pants", "jeans", "shorts"), _LOWER),
    "skirt": _SKIRT,
}


def dimension_landmarks(category: str) -> dict[str, tuple[str, str]]:
    """Return a copy of the existing mobile measurement semantics, including skirts."""
    return _SCHEMAS.get(category, {}).copy()


class BoundaryModel(BaseModel):
    """Immutable parsed boundary; unknown fields are rejected unless source format says otherwise."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="forbid", allow_inf_nan=False)


class Status(StrEnum):
    """Commercial training review state."""

    APPROVED = "approved"
    PENDING = "pending_review"
    BLOCKED = "blocked"


class DatasetEntry(BoundaryModel):
    """Separate original image, annotation, terms and usage evidence."""

    id: str
    name: str
    original_url: str
    publisher: str
    image_rightsholder: str
    data_license: str
    annotation_license: str
    license_url: str
    checked_at: str
    terms_url: str
    commercial_basis: str
    permissions: list[str]
    attribution: str
    published_image_count: int | None
    approved_image_count: int
    categories: list[str]
    annotation_types: list[str]
    provenance_manifest: str | None
    status: Status
    approval_reason: str
    download_url: str | None = None
    archive_md5: str | None = None


class Registry(BoundaryModel):
    """Reviewed dataset entries and the authoritative category set."""

    schema_version: Literal[1]
    categories: list[str]
    datasets: list[DatasetEntry]


class Landmark(BoundaryModel):
    """Top-left normalized coordinates with visibility and provenance."""

    landmark_type: str
    x: Annotated[float, Field(ge=0, le=1)]
    y: Annotated[float, Field(ge=0, le=1)]
    visibility: Literal[0, 1, 2]
    confidence: Annotated[float, Field(ge=0, le=1)] = 1
    source: str
    correction_status: Literal["original", "user_corrected"] = "original"


class Acquisition(BoundaryModel):
    """Physical or procedural capture metadata without location EXIF."""

    synthetic: bool
    camera_intrinsics: list[list[float]] | None = None
    camera_rotation: list[list[float]] | None = None
    camera_translation_cm: list[float] | None = None
    keypoints_3d_cm: dict[str, list[float]] = Field(default_factory=dict)
    background: str = "unknown"
    occlusion: str = "unknown"
    wrinkles: str = "unknown"
    difficulty: str = "unknown"


class Record(BoundaryModel):
    """COCO-compatible normalized, individually traceable garment record."""

    image_id: str
    garment_id: str
    category: str
    source_dataset: str
    original_license: str
    license_status: Literal["approved"]
    source_url: str
    source_path: str
    source_group: str
    split: Literal["train", "validation", "test"]
    file_name: str
    sha256: Annotated[str, Field(pattern=r"^[0-9a-f]{64}$")]
    perceptual_hash: Annotated[str, Field(pattern=r"^[0-9a-f]{16}$")]
    width: Annotated[int, Field(gt=0)]
    height: Annotated[int, Field(gt=0)]
    bbox: list[float]
    source_bbox: list[float] | None = None
    segmentation: list[list[float]]
    keypoints: list[Landmark]
    mask_file_name: str | None = None
    mask_sha256: str | None = None
    source_keypoints: list[Landmark] = Field(default_factory=list)
    measurement_ground_truth: dict[str, float] = Field(default_factory=dict)
    acquisition_metadata: Acquisition

    @model_validator(mode="after")
    def geometry_and_semantics(self) -> Self:
        """Reject malformed COCO geometry and accidental source-to-seam label mixing."""
        if self.category not in CLASSES or len(self.bbox) != 4:
            raise PipelineError("Unknown category or malformed COCO bounding box")
        x, y, width, height = self.bbox
        if (
            x < 0
            or y < 0
            or width <= 0
            or height <= 0
            or x + width > self.width + 0.01
            or y + height > self.height + 0.01
        ):
            raise PipelineError("Bounding box is outside the image")
        for polygon in self.segmentation:
            if len(polygon) < 6 or len(polygon) % 2:
                raise PipelineError("Invalid segmentation polygon")
            if any(px < 0 or px > self.width for px in polygon[::2]) or any(
                py < 0 or py > self.height for py in polygon[1::2]
            ):
                raise PipelineError("Segmentation is outside the image")
            if any(px < x - 0.01 or px > x + width + 0.01 for px in polygon[::2]) or any(
                py < y - 0.01 or py > y + height + 0.01 for py in polygon[1::2]
            ):
                raise PipelineError("Bounding box does not cover segmentation")
        names = [point.landmark_type for point in self.keypoints]
        permitted = {point for pair in dimension_landmarks(self.category).values() for point in pair}
        if len(set(names)) != len(names) or not set(names) <= permitted:
            raise PipelineError("Semantic landmark schema mismatch")
        if not set(self.measurement_ground_truth) <= set(dimension_landmarks(self.category)) or any(
            v <= 0 for v in self.measurement_ground_truth.values()
        ):
            raise PipelineError("Invalid centimeter ground-truth schema")
        return self


class PipelineError(RuntimeError):
    """An input cannot pass provenance, quality or artifact policy."""


def read_registry(path: Path) -> Registry:
    """Parse the reviewed registry without granting approvals."""
    return Registry.model_validate_json(path.read_bytes())
