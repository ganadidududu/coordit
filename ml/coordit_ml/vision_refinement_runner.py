"""One bounded self-review per frozen original prediction, with paid receipts and exact inverse transforms."""

import hashlib
import json
import os
from pathlib import Path
from typing import Literal

from pydantic import TypeAdapter

from coordit_ml.provenance import sha256
from coordit_ml.schema import BoundaryModel, PipelineError
from coordit_ml.source_downloads import create_client
from coordit_ml.vision_api_inputs import load_public_photos, request_bytes, reserve_total
from coordit_ml.vision_api_runner import ScheduledPhoto, make_attempt
from coordit_ml.vision_api_types import ApiAnnotation, ApiAttempt, BenchmarkConfig
from coordit_ml.vision_refinement_crop import CropBox, ReviewInput, refinement_payload


class RefinementConfig(BoundaryModel):
    """Baseline inputs/results are pinned before the follow-up; no evaluation feedback can enter requests."""

    baseline: BenchmarkConfig
    parent_attempts: Path
    parent_attempts_sha256: str
    output: Path
    spending_limit_usd: float = 5
    output_frame: Literal["crop", "original"] = "crop"


class RefinedAttempt(BoundaryModel):
    """Raw crop-frame output and mapped original-frame proposals are both retained for independent replay."""

    crop: CropBox
    parent_request_sha256: str
    parent_response_sha256: str | None
    attempt: ApiAttempt
    original_annotation: ApiAnnotation | None
    output_frame: Literal["crop", "original"] = "crop"


def run_refinement(config: RefinementConfig) -> Path:
    """No inference retries, GT hints, status promotion, best-of selection or overwrite of existing results."""
    if sha256(config.parent_attempts) != config.parent_attempts_sha256:
        raise PipelineError("Original prediction receipt changed before self-review")
    parents = TypeAdapter(list[ApiAttempt]).validate_json(config.parent_attempts.read_bytes())
    _, photos = load_public_photos(config.baseline)
    selected = [p for p in parents if p.model_requested in config.baseline.models]
    expected = {(m, p.case.case_id) for m in config.baseline.models for p in photos}
    if len(selected) != len(expected) or {(p.model_requested, p.case_id) for p in selected} != expected:
        raise PipelineError("Parent results do not cover the declared model/photo grid")
    candidate = config.baseline.model_copy(
        update={
            "output": config.output,
            "input_token_reservation": 16384,
            "spending_limit_usd": config.spending_limit_usd,
        }
    )
    reserved = reserve_total(candidate)
    key = (os.environ.get("OPENROUTER_API_KEY") or os.environ.get("OPENAI_API_KEY") or "").strip()
    if not key:
        raise PipelineError("Local OpenRouter credential missing")
    indexed = {p.case.case_id: p for p in photos}
    config.output.mkdir(parents=True, exist_ok=False)
    _ = (config.output / "config.json").write_text(config.model_dump_json(indent=2) + "\n")
    _ = (config.output / "reservation.json").write_text(json.dumps({"reserved_usd": reserved}) + "\n")
    results: list[RefinedAttempt] = []
    with create_client() as client:
        client.headers["Authorization"] = "Bearer " + key
        auth = client.get("https://openrouter.ai/api/v1/key", follow_redirects=False)
        if auth.status_code != 200:
            raise PipelineError("OpenRouter authentication failed before photo egress")
        for parent in selected:
            photo = indexed[parent.case_id]
            expected_request = hashlib.sha256(request_bytes(parent.model_requested, photo, config.baseline)).hexdigest()
            if photo.case.image_sha256 != parent.image_sha256 or expected_request != parent.request_sha256:
                raise PipelineError("Draft came from another photograph or inference contract")
            payload, crop = refinement_payload(ReviewInput(photo, parent, config.output_frame), candidate)
            result = make_attempt(client, ScheduledPhoto(parent.model_requested, photo, payload), candidate)
            original = crop.restore(result.annotation, config.output_frame) if result.annotation else None
            record = RefinedAttempt(
                crop=crop,
                parent_request_sha256=parent.request_sha256,
                parent_response_sha256=parent.response_sha256,
                attempt=result,
                original_annotation=original,
                output_frame=config.output_frame,
            )
            results.append(record)
            target = config.output / (parent.model_requested.replace("/", "--") + "-" + parent.case_id + ".mapped.json")
            with target.open("x") as stream:
                _ = stream.write(record.model_dump_json(indent=2) + "\n")
            print(  # noqa: T201 -- Sanitized CLI progress.
                parent.model_requested,
                parent.case_id,
                result.failure or "ok",
                round(result.elapsed_seconds, 2),
                flush=True,
            )
            known_cost = sum(
                r.attempt.response.usage.cost or 0 for r in results if r.attempt.response and r.attempt.response.usage
            )
            if result.http_status in (401, 402, 403) or result.failure == "transport_error_billing_unknown":
                raise PipelineError("Stopped self-review on access/funding/unknown billing; never blindly retry")
            if known_cost > config.spending_limit_usd:
                raise PipelineError("Self-review exceeded declared actual-cost limit")
    target = config.output / "refinements.json"
    with target.open("x") as stream:
        _ = stream.write("[\n" + ",\n".join(r.model_dump_json(indent=2) for r in results) + "\n]\n")
    return target


def verify_refinement(config: RefinementConfig, *, allow_partial: bool = False) -> list[RefinedAttempt]:
    """Reconstruct every label-free request and affine inverse; refuse edited hashes or mapped coordinates."""
    if sha256(config.parent_attempts) != config.parent_attempts_sha256:
        raise PipelineError("Parent attempt hash changed")
    parents = TypeAdapter(list[ApiAttempt]).validate_json(config.parent_attempts.read_bytes())
    aggregate = config.output / "refinements.json"
    records = (
        TypeAdapter(list[RefinedAttempt]).validate_json(aggregate.read_bytes())
        if aggregate.exists()
        else [RefinedAttempt.model_validate_json(p.read_bytes()) for p in sorted(config.output.glob("*.mapped.json"))]
        if allow_partial
        else []
    )
    if not records:
        raise PipelineError("Refinement has no result receipts; an empty run cannot be scored")
    _, photos = load_public_photos(config.baseline)
    indexed = {(r.model_requested, r.case_id): r for r in parents}
    pixels = {p.case.case_id: p for p in photos}
    expected = {(m, p.case.case_id) for m in config.baseline.models for p in photos}
    observed = {(r.attempt.model_requested, r.attempt.case_id) for r in records}
    if len(records) != len(observed) or not observed <= expected or (not allow_partial and observed != expected):
        raise PipelineError("Refinement grid has missing, foreign or repeated attempts")
    for record in records:
        attempt = record.attempt
        parent = indexed[attempt.model_requested, attempt.case_id]
        payload, crop = refinement_payload(
            ReviewInput(pixels[attempt.case_id], parent, config.output_frame), config.baseline
        )
        restored = crop.restore(attempt.annotation, config.output_frame) if attempt.annotation else None
        if (
            record.output_frame != config.output_frame
            or attempt.request_sha256 != hashlib.sha256(payload).hexdigest()
            or crop != record.crop
            or restored != record.original_annotation
            or parent.request_sha256 != record.parent_request_sha256
            or parent.response_sha256 != record.parent_response_sha256
        ):
            raise PipelineError("Edited refinement request, crop, draft or restored coordinates")
    return records
