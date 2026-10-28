"""Conservative training-history exclusion, including legacy artifacts without exposure IDs."""

from dataclasses import dataclass
from pathlib import Path
from typing import ClassVar

from pydantic import BaseModel, ConfigDict

from coordit_ml.artifacts import ManifestPin
from coordit_ml.provenance import sha256
from coordit_ml.schema import BoundaryModel, PipelineError, Record


class HistoryArtifact(BaseModel):
    """Legacy training configs differ; all referenced corpus images are conservatively excluded."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True)
    checkpoint_sha256: str
    manifests: list[ManifestPin]


class HistoryPin(BoundaryModel):
    """Exact run evidence audited before a new evaluation corpus is exposed."""

    artifact: Path
    sha256: str


class HistoryRecord(BaseModel):
    """Historical geometry schemas may differ; image identity is still mandatory and pinned."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True)
    sha256: str
    original_sha256: str | None = None
    garment_id: str
    perceptual_hash: str


@dataclass(frozen=True, slots=True)
class HistoryIndex:
    """Original and normalized bytes, garment groups and image similarity stay separate."""

    records: list[HistoryRecord]
    hashes: frozenset[str]
    garments: frozenset[str]
    perceptual_hashes: frozenset[int]

    def overlaps(self, record: Record) -> str | None:
        """Fail conservatively even if a source was only in a previous tuning/validation corpus."""
        if record.sha256 in self.hashes or record.original_sha256 in self.hashes:
            return "exact_image_in_history"
        if record.garment_id in self.garments:
            return "garment_in_history"
        value = int(record.perceptual_hash, 16)
        if any((value ^ previous).bit_count() <= 4 for previous in self.perceptual_hashes):
            return "near_image_in_history"
        return None


def load_history(pins: list[HistoryPin]) -> HistoryIndex:
    """Audit metadata, checkpoint and manifest pins; missing history cannot yield independence."""
    if not pins:
        raise PipelineError("Evaluation requires explicit training history")
    manifests: dict[Path, str] = {}
    for pin in pins:
        if sha256(pin.artifact) != pin.sha256:
            raise PipelineError("Training history metadata changed")
        artifact = HistoryArtifact.model_validate_json(pin.artifact.read_bytes())
        if sha256(pin.artifact.parent / "checkpoint.pt") != artifact.checkpoint_sha256:
            raise PipelineError("Training history checkpoint changed")
        for source in artifact.manifests:
            path = Path(source.path).resolve()
            if sha256(path) != source.sha256 or manifests.setdefault(path, source.sha256) != source.sha256:
                raise PipelineError("Training history manifest changed")
    records = [
        HistoryRecord.model_validate_json(line)
        for manifest in sorted(manifests)
        for line in manifest.read_text().splitlines()
        if line.strip()
    ]
    if not records:
        raise PipelineError("Recorded training history is empty")
    hashes = frozenset(value for record in records for value in (record.sha256, record.original_sha256) if value)
    return HistoryIndex(
        records,
        hashes,
        frozenset(r.garment_id for r in records),
        frozenset(int(r.perceptual_hash, 16) for r in records),
    )
