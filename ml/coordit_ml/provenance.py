"""Fail-closed loading, byte provenance, duplicate detection and grouped splits."""

import hashlib
from pathlib import Path

from PIL import Image

from coordit_ml.schema import BoundaryModel, DatasetEntry, PipelineError, Record, Registry, Status
from coordit_ml.similarity import near_duplicate_pairs

REGISTRY_ROOT = Path(__file__).resolve().parents[1] / "registry"


class DeniedFile(BoundaryModel):
    """A permanently excluded evaluation source and hash."""

    path: str
    sha256: str


class Denylist(BoundaryModel):
    """Evaluation families excluded from all training and validation."""

    reason: str
    blocked_source_prefixes: list[str]
    files: list[DeniedFile]


def sha256(path: Path) -> str:
    """Hash actual image/artifact bytes, not filenames."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def perceptual_hash(path: Path) -> str:
    """64-bit difference hash for near-duplicate screening (not an identity proof)."""
    with Image.open(path) as image:
        pixels = image.convert("L").resize((9, 8)).tobytes()
    value = 0
    for row in range(8):
        for column in range(8):
            value = (value << 1) | (pixels[row * 9 + column] > pixels[row * 9 + column + 1])
    return f"{value:016x}"


def approved_entry(registry: Registry, dataset_id: str) -> DatasetEntry:
    """Only reviewed original rights with explicit training permission may pass."""
    matches = [entry for entry in registry.datasets if entry.id == dataset_id]
    if len(matches) != 1:
        raise PipelineError(f"Unknown or duplicate dataset: {dataset_id}")
    entry = matches[0]
    if entry.status != Status.APPROVED or "train" not in entry.permissions:
        raise PipelineError(f"Dataset is not approved for training: {dataset_id}")
    allowed = {"MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "CC0-1.0", "CC-BY-4.0", "Coordit-owned"}
    if entry.data_license not in allowed or entry.annotation_license not in allowed:
        raise PipelineError(f"License requires separate obligations review: {dataset_id}")
    if (
        not all(
            (
                entry.commercial_basis,
                entry.approval_reason,
                entry.image_rightsholder,
                entry.license_url,
                entry.checked_at,
                entry.terms_url,
                entry.attribution,
                entry.publisher,
            )
        )
        or entry.image_rightsholder == "unverified"
    ):
        raise PipelineError(f"Missing original-image rights evidence: {dataset_id}")
    return entry


def read_records(path: Path) -> list[Record]:
    """Parse JSONL; empty corpora are failures, never fake success."""
    records = [Record.model_validate_json(line) for line in path.read_text().splitlines() if line.strip()]
    if not records:
        raise PipelineError("Dataset is empty")
    return records


def audit_records(manifest: Path, registry: Registry) -> list[Record]:
    """Verify every file before tensor decoding at the training loader boundary."""
    records = read_records(manifest)
    denylist = Denylist.model_validate_json((REGISTRY_ROOT / "EVALUATION_DENYLIST.json").read_bytes())
    denied_hashes = {entry.sha256 for entry in denylist.files}
    denied_paths = {entry.path for entry in denylist.files}
    groups: dict[str, str] = {}
    hashes: set[str] = set()
    ids: set[str] = set()
    root = manifest.parent.resolve()
    for record in records:
        entry = approved_entry(registry, record.source_dataset)
        if record.original_license != entry.data_license or not record.source_url or not record.source_path:
            raise PipelineError(f"Missing/mismatched per-file rights: {record.image_id}")
        if record.category not in entry.categories:
            raise PipelineError(f"Category outside dataset grant: {record.category}")
        if (
            record.sha256 in denied_hashes
            or record.source_path in denied_paths
            or (
                record.source_dataset.startswith("artf-")
                and any(record.source_path.startswith(p) for p in denylist.blocked_source_prefixes)
            )
        ):
            raise PipelineError(f"Evaluation contamination: {record.image_id}")
        if record.segmentation_supervised and not {"mask", "polygon", "segmentation"}.intersection(
            entry.annotation_types
        ):
            raise PipelineError(f"Source has no approved segmentation truth: {record.image_id}")
        if record.keypoints and "semantic_keypoints" not in entry.annotation_types:
            raise PipelineError(f"Source has no approved semantic landmark truth: {record.image_id}")
        if record.measurement_ground_truth and not {"synthetic_cm", "measured_cm"}.intersection(entry.annotation_types):
            raise PipelineError(f"Source has no approved centimeter truth: {record.image_id}")
        file = (root / record.file_name).resolve()
        if (
            not file.is_relative_to(root)
            or sha256(file) != record.sha256
            or perceptual_hash(file) != record.perceptual_hash
        ):
            raise PipelineError(f"File provenance/hash mismatch: {record.image_id}")
        with Image.open(file) as image:
            if image.size != (record.width, record.height):
                raise PipelineError(f"Image dimensions mismatch: {record.image_id}")
        if record.mask_file_name:
            mask = (root / record.mask_file_name).resolve()
            if not mask.is_relative_to(root) or sha256(mask) != record.mask_sha256:
                raise PipelineError(f"Mask provenance mismatch: {record.image_id}")
            with Image.open(mask) as decoded_mask:
                if decoded_mask.size != (record.width, record.height):
                    raise PipelineError(f"Mask dimensions mismatch: {record.image_id}")
        if record.sha256 in hashes or record.image_id in ids:
            raise PipelineError(f"Duplicate image: {record.image_id}")
        hashes.add(record.sha256)
        ids.add(record.image_id)
        for group in ("source:" + record.source_group, "garment:" + record.garment_id):
            if not group.split(":", 1)[1] or groups.setdefault(group, record.split) != record.split:
                raise PipelineError(f"Cross-split group leakage: {group}")
        if len(record.bbox) != 4 or (
            record.segmentation_supervised and not record.segmentation and not record.mask_file_name
        ):
            raise PipelineError(f"Invalid COCO geometry: {record.image_id}")
    check_separation(records)
    return records


def check_separation(records: list[Record]) -> None:
    """Check across corpora too: duplicate manifests cannot bypass per-file auditing."""
    hashes: set[str] = set()
    groups: dict[str, str] = {}
    for record in records:
        if record.sha256 in hashes:
            raise PipelineError(f"Duplicate across corpora: {record.image_id}")
        hashes.add(record.sha256)
        for group in ("source:" + record.source_group, "garment:" + record.garment_id):
            if groups.setdefault(group, record.split) != record.split:
                raise PipelineError(f"Cross-split group leakage: {group}")
    if len({record.split for record in records}) <= 1:
        return
    for index, previous in near_duplicate_pairs(records):
        if records[index].split != records[previous].split:
            raise PipelineError(f"Cross-split near duplicate: {records[index].image_id}, {records[previous].image_id}")


def group_splits(records: list[Record]) -> list[Record]:
    """Union garment/session/near-duplicate groups before deterministic partitioning."""
    parents = list(range(len(records)))

    def find(index: int) -> int:
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index

    seen_groups: dict[str, int] = {}
    for index, record in enumerate(records):
        for key in ("garment:" + record.garment_id, "source:" + record.source_group):
            previous = seen_groups.setdefault(key, index)
            a, b = find(index), find(previous)
            parents[max(a, b)] = min(a, b)
    for index, previous in near_duplicate_pairs(records):
        a, b = find(index), find(previous)
        parents[max(a, b)] = min(a, b)
    assignments: dict[int, str] = {}
    for index in range(len(records)):
        component = find(index)
        token = int(hashlib.sha256(records[component].garment_id.encode()).hexdigest()[:8], 16) % 10
        assignments[component] = "test" if token == 0 else ("validation" if token == 1 else "train")
    return [record.model_copy(update={"split": assignments[find(index)]}) for index, record in enumerate(records)]


def write_records(path: Path, records: list[Record]) -> None:
    """Write a reviewable immutable manifest; refuse a silent overwrite."""
    if not records:
        raise PipelineError("No accepted images")
    with path.open("x") as stream:
        for record in records:
            _ = stream.write(record.model_dump_json() + "\n")
