"""CI provenance checks that do not require distributing image archives in Git."""

from pathlib import Path

from coordit_ml.provenance import REGISTRY_ROOT, Denylist, approved_entry
from coordit_ml.schema import BoundaryModel, PipelineError, Registry


class InventoryEntry(BoundaryModel):
    """Reviewed file identities; full pixel/geometry verification stays in the training loader."""

    image_id: str
    category: str
    source_dataset: str
    original_license: str
    source_url: str
    source_path: str
    source_group: str
    garment_id: str
    split: str
    sha256: str
    perceptual_hash: str


def audit_inventory(path: Path, registry: Registry) -> int:
    """Fail CI when a tracked provenance inventory names unapproved/evaluation data."""
    records = [InventoryEntry.model_validate_json(line) for line in path.read_text().splitlines() if line.strip()]
    if not records:
        raise PipelineError("Empty provenance inventory")
    deny = Denylist.model_validate_json((REGISTRY_ROOT / "EVALUATION_DENYLIST.json").read_bytes())
    excluded = {entry.sha256 for entry in deny.files}
    hashes: set[str] = set()
    for record in records:
        entry = approved_entry(registry, record.source_dataset)
        if (
            record.category not in entry.categories
            or record.original_license != entry.data_license
            or not record.source_url
        ):
            raise PipelineError("Inventory rights/category mismatch")
        if record.sha256 in hashes or record.sha256 in excluded:
            raise PipelineError("Duplicate or excluded inventory image")
        if record.source_dataset.startswith("artf-") and any(
            record.source_path.startswith(p) for p in deny.blocked_source_prefixes
        ):
            raise PipelineError("Evaluation family in training inventory")
        hashes.add(record.sha256)
    return len(records)
