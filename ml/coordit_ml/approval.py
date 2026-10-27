"""Explicit, evidence-bearing registry review; never auto-approve marketplace labels."""

from pathlib import Path

from pydantic import Field

from coordit_ml.provenance import approved_entry, sha256
from coordit_ml.schema import BoundaryModel, DatasetEntry, PipelineError, Registry, Status, read_registry


class Approval(BoundaryModel):
    """A reviewer supplies the complete rights record and original-source evidence."""

    expected_registry_sha256: str
    reviewer: str = Field(min_length=3)
    original_evidence_urls: list[str] = Field(min_length=1)
    dataset: DatasetEntry


def approve_dataset(registry_path: Path, review_path: Path) -> None:
    """Apply a review only to a pending record at the exact reviewed registry version."""
    review = Approval.model_validate_json(review_path.read_bytes())
    registry = read_registry(registry_path)
    if sha256(registry_path) != review.expected_registry_sha256:
        raise PipelineError("Registry changed since review")
    existing = [entry for entry in registry.datasets if entry.id == review.dataset.id]
    if len(existing) != 1 or existing[0].status != Status.PENDING or review.dataset.status != Status.APPROVED:
        raise PipelineError("Only explicitly reviewed pending records can be approved")
    if not all(url.startswith("https://") for url in review.original_evidence_urls):
        raise PipelineError("Original rights documents need HTTPS evidence URLs")
    updated = Registry(
        schema_version=1,
        categories=registry.categories,
        datasets=[review.dataset if entry.id == review.dataset.id else entry for entry in registry.datasets],
    )
    _ = approved_entry(updated, review.dataset.id)
    temporary = registry_path.with_suffix(".reviewed")
    _ = temporary.write_text(updated.model_dump_json(indent=2) + "\n")
    _ = temporary.replace(registry_path)
    with registry_path.with_name("APPROVAL_AUDIT.jsonl").open("a") as audit:
        _ = audit.write(review.model_dump_json() + "\n")
