"""Fail-closed public-aRTF egress boundary and identical label-free request contracts."""

import base64
import json
from dataclasses import dataclass

from PIL import Image

from coordit_ml.external_pilot import TARGETS, PilotCase, PilotReceipt, require_public_artf
from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, sha256
from coordit_ml.publisher_test import PublisherTestDataset
from coordit_ml.schema import PipelineError, read_registry
from coordit_ml.vision_api_types import ApiAnnotation, BenchmarkConfig, ModelCatalog


@dataclass(frozen=True, slots=True)
class PublicPhoto:
    """No original keypoints, model predictions or private-source records can enter request construction."""

    case: PilotCase
    pixels: bytes


def load_public_photos(config: BenchmarkConfig) -> tuple[PilotReceipt, list[PublicPhoto]]:
    """Audit original source identity, hash, license, split and crop before returning public pixels only."""
    if sha256(config.receipt) != config.receipt_sha256 or sha256(config.protocol) != config.protocol_sha256:
        raise PipelineError("API packet or protocol changed")
    receipt = PilotReceipt.model_validate_json(config.receipt.read_bytes())
    if len(receipt.cases) != 8 or len({c.case_id for c in receipt.cases}) != 8:
        raise PipelineError("API benchmark requires the frozen eight unique public photos")
    if sha256(receipt.preparation.manifest) != receipt.manifest_sha256:
        raise PipelineError("API source manifest changed")
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    source = approved_entry(registry, "artf-1.0.1")
    dataset = PublisherTestDataset(receipt.preparation.manifest, registry)
    records = {record.image_id: record for _, record in dataset.samples}
    photos: list[PublicPhoto] = []
    for case in receipt.cases:
        if case.source_image_id not in records:
            raise PipelineError("API photo is absent from the audited public corpus")
        record = records[case.source_image_id]
        require_public_artf(record, source.data_license)
        path = (config.receipt.parent / case.image_file).resolve()
        if (
            not path.is_relative_to(config.receipt.parent.resolve())
            or sha256(path) != record.sha256 or case.image_sha256 != record.sha256
            or case.category != record.category or (case.width, case.height) != (record.width, record.height)
        ):
            raise PipelineError("API image identity or coordinate frame differs from original source")
        with Image.open(path) as image:
            if image.format != "PNG" or image.size != (case.width, case.height):
                raise PipelineError("API photograph is not the frozen original PNG")
        photos.append(PublicPhoto(case, path.read_bytes()))
    return receipt, photos


def reserve_total(config: BenchmarkConfig) -> float:
    """Advertised worst-case reservations guard the small pilot; actual provider charges are recorded separately."""
    if sha256(config.catalog) != config.catalog_sha256:
        raise PipelineError("Model catalog snapshot changed")
    catalog = ModelCatalog.model_validate_json(config.catalog.read_bytes())
    indexed = {model.id: model for model in catalog.data}
    if not config.models or len(set(config.models)) != len(config.models) or len(config.models) > 5:
        raise PipelineError("Choose one to five unique explicit API models")
    total = 0.0
    for model_id in config.models:
        if model_id not in indexed:
            raise PipelineError("Requested API model is absent from the actual catalog")
        model = indexed[model_id]
        if "image" not in model.architecture.input_modalities or not {
            "structured_outputs", "reasoning",
        } <= set(model.supported_parameters):
            raise PipelineError("API model lacks required image/JSON/reasoning controls")
        total += 8 * (
            config.input_token_reservation * model.pricing.prompt + config.max_tokens * model.pricing.completion
        )
    if total > config.spending_limit_usd:
        raise PipelineError("Reserved API cost exceeds the configured pilot budget")
    return total


def request_bytes(model_id: str, photo: PublicPhoto, config: BenchmarkConfig) -> bytes:
    """Only approved original pixels and the same category/coordinate instructions reach OpenRouter."""
    protocol = config.protocol.read_text()
    names = TARGETS[photo.case.category]
    prompt = (
        protocol + f"\nCategory: {photo.case.category}. Original image: {photo.case.width}x{photo.case.height}. "
        + "Return exactly these four landmark types: " + ", ".join(names) + "."
    )
    payload = {
        "model": model_id,
        "messages": [{"role": "user", "content": [
            {"type": "text", "text": prompt},
            {"type": "image_url", "image_url": {
                "url": "data:image/png;base64," + base64.b64encode(photo.pixels).decode(), "detail": "high",
            }},
        ]}],
        "response_format": {"type": "json_schema", "json_schema": {
            "name": "garment_landmarks", "strict": True, "schema": ApiAnnotation.model_json_schema(),
        }},
        "max_tokens": config.max_tokens, "stream": False,
        "reasoning": {"effort": "low", "exclude": True},
        "provider": {"allow_fallbacks": False, "require_parameters": True, "data_collection": "deny", "zdr": True},
        "usage": {"include": True},
    }
    return json.dumps(payload, separators=(",", ":"), allow_nan=False).encode()
