"""Freeze an image-disjoint, scene-held-out public-aRTF packet before viewing new model predictions."""

import hashlib
import json
import shutil
from pathlib import Path
from typing import ClassVar

from pydantic import BaseModel, ConfigDict, JsonValue

from coordit_ml.external_pilot import PilotCase, require_public_artf
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import PipelineError, Record, read_registry
from coordit_ml.source_downloads import create_client
from coordit_ml.vision_api_inputs import load_public_photos
from coordit_ml.vision_api_types import ApiModel, BenchmarkConfig, ModelCatalog


class CatalogEnvelope(BaseModel):
    """Only selected models need strict commercial prices; router aliases may advertise a sentinel -1."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    data: list[dict[str, JsonValue]]


def prepare_holdout(source: BenchmarkConfig, output: Path) -> Path:
    """Select four images per category/location by hash and pixel similarity, never by labels or model quality."""
    old, _ = load_public_photos(source)
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    entry = approved_entry(registry, "artf-1.0.1")
    dataset = PublisherTestDataset(old.preparation.manifest, registry)
    indexed = {r.image_id: r for _, r in dataset.samples}
    dev = [indexed[c.source_image_id] for c in old.cases]
    old_locations = {r.source_path.split("/")[1] for r in dev}
    locations = ("location_2", "location_3")
    if old_locations.intersection(locations):
        raise PipelineError("Holdout scenes overlap the declared development packet")
    output.mkdir(parents=True, exist_ok=False)
    selected: list[tuple[Path, Record]] = []
    for category in ("tshirt", "shorts"):
        for location in locations:
            candidates = [
                (root, r)
                for root, r in dataset.samples
                if r.category == category and r.source_path.split("/")[1] == location
            ]
            candidates.sort(key=lambda item: hashlib.sha256(("20261029:" + item[1].sha256).encode()).hexdigest())
            count = 0
            for root, record in candidates:
                peers = [*dev, *(r for _, r in selected)]
                if any(
                    record.sha256 == p.sha256
                    or (int(record.perceptual_hash, 16) ^ int(p.perceptual_hash, 16)).bit_count() < 8
                    for p in peers
                ):
                    continue
                require_public_artf(record, entry.data_license)
                selected.append((root, record))
                count += 1
                if count == 4:
                    break
            if count != 4:
                raise PipelineError("Insufficient diverse source pixels for the predeclared holdout")
    cases: list[PilotCase] = []
    for index, (root, record) in enumerate(selected, 1):
        filename = f"P{index:02d}.png"
        _ = shutil.copyfile(root / record.file_name, output / filename)
        cases.append(
            PilotCase.model_validate(
                {
                    "case_id": f"P{index:02d}",
                    "category": record.category,
                    "source_image_id": record.image_id,
                    "image_file": filename,
                    "image_sha256": record.sha256,
                    "width": record.width,
                    "height": record.height,
                }
            )
        )
    preparation = old.preparation.model_copy(update={"output": output, "per_category": 8, "seed": 20261029})
    packet = old.model_copy(update={"preparation": preparation, "cases": cases})
    path = output / "packet.json"
    _ = path.write_text(packet.model_dump_json(indent=2) + "\n")
    _ = (output / "split-audit.json").write_text(
        json.dumps(
            {
                "development_receipt_sha256": source.receipt_sha256,
                "holdout_receipt_sha256": sha256(path),
                "development_images": len(old.cases),
                "holdout_images": len(cases),
                "development_locations": sorted(old_locations),
                "holdout_locations": list(locations),
                "sha_overlap": 0,
                "minimum_phash_hamming": 8,
                "selected_without_keypoints_or_predictions": True,
                "same_physical_garment_independence": "unknown_source_garment_ids_unresolved",
                "prior_heuristic_development_in_publisher_test_family": True,
                "training": False,
            },
            indent=2,
        )
        + "\n"
    )
    return path


def current_catalog(output: Path) -> Path:
    """Read current public API metadata without credentials or image transfer; retain only the two requested models."""
    with create_client() as client:
        response = client.get("https://openrouter.ai/api/v1/models", follow_redirects=False)
    if response.status_code != 200:
        raise PipelineError("Current public model catalog unavailable")
    catalog = CatalogEnvelope.model_validate_json(response.content)
    names = {"openai/gpt-6-astra", "google/gemini-3.8-flash"}
    selected = [
        ApiModel.model_validate(row)
        for row in catalog.data
        if row.get("id") == "openai/gpt-6-astra" or row.get("id") == "google/gemini-3.8-flash"
    ]
    if len(selected) != len(names):
        raise PipelineError("One requested model is absent from the current catalog")
    target = output / "current-models.json"
    with target.open("x") as stream:
        _ = stream.write(ModelCatalog(data=selected).model_dump_json(indent=2) + "\n")
    return target
