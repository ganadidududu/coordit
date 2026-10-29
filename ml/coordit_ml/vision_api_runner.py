"""Serial, bounded OpenRouter calls with immutable per-attempt receipts and no inference retries."""

import hashlib
import json
import os
import random
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

import httpx2
from pydantic import ValidationError

from coordit_ml.external_pilot import TARGETS
from coordit_ml.provenance import sha256
from coordit_ml.schema import PipelineError
from coordit_ml.source_downloads import create_client
from coordit_ml.vision_api_inputs import PublicPhoto, load_public_photos, request_bytes, reserve_total
from coordit_ml.vision_api_types import ApiAnnotation, ApiAttempt, ApiResponse, BenchmarkConfig


@dataclass(frozen=True, slots=True)
class ScheduledPhoto:
    """One predetermined model/photo pairing; model order cannot adapt to measured accuracy."""

    model: str
    photo: PublicPhoto
    payload: bytes | None = None


def parse_annotation(response: ApiResponse, photo: PublicPhoto) -> tuple[ApiAnnotation | None, str | None]:
    """Incomplete answers, refusals and invalid coordinates are explicit service failures, never good predictions."""
    if response.error or len(response.choices) != 1:
        return None, "provider_error_or_missing_answer"
    choice = response.choices[0]
    if choice.finish_reason != "stop" or choice.message.refusal or choice.message.content is None:
        return None, "incomplete_or_refused"
    try:
        annotation = ApiAnnotation.model_validate_json(choice.message.content)
    except (ValidationError, PipelineError):
        return None, "invalid_annotation_json"
    names = [p.landmark_type for p in annotation.points]
    if len(names) != len(set(names)) or set(names) != set(TARGETS[photo.case.category]):
        return None, "missing_duplicate_or_wrong_targets"
    return annotation, None


def make_attempt(client: httpx2.Client, item: ScheduledPhoto, config: BenchmarkConfig) -> ApiAttempt:
    """A start receipt is durable before egress; a crash cannot silently trigger a duplicate paid request."""
    model, photo = item.model, item.photo
    payload = item.payload if item.payload is not None else request_bytes(model, photo, config)
    request_hash = hashlib.sha256(payload).hexdigest()
    started = datetime.now(UTC).isoformat()
    filename = model.replace("/", "--") + "-" + photo.case.case_id
    with (config.output / (filename + ".started.json")).open("x") as stream:
        _ = stream.write(json.dumps({
            "requested_model": model, "case_id": photo.case.case_id, "started_utc": started,
            "request_sha256": request_hash, "image_sha256": photo.case.image_sha256,
        }) + "\n")
    retry_after: int | None = None
    status: int | None = None
    envelope: ApiResponse | None = None
    annotation: ApiAnnotation | None = None
    failure: str | None = None
    response_hash: str | None = None
    before = time.perf_counter()
    try:
        response = client.post(
            "https://openrouter.ai/api/v1/chat/completions", content=payload,
            headers={"Content-Type": "application/json"},
            timeout=httpx2.Timeout(connect=5, read=180, write=10, pool=10), follow_redirects=False,
        )
        elapsed = time.perf_counter() - before
        status, response_hash = response.status_code, hashlib.sha256(response.content).hexdigest()
        header = response.headers.get("Retry-After", "")
        if header.isdecimal() and int(header) <= 3600:
            retry_after = int(header)
        try:
            envelope = ApiResponse.model_validate_json(response.content)
        except ValidationError:
            failure = "unparseable_provider_response"
        if status != 200:
            failure = f"http_{status}"
        elif envelope is not None:
            annotation, failure = parse_annotation(envelope, photo)
    except httpx2.RequestError:
        elapsed = time.perf_counter() - before
        failure = "transport_error_billing_unknown"
    attempt = ApiAttempt(
        model_requested=model, case_id=photo.case.case_id, image_sha256=photo.case.image_sha256,
        started_utc=started, elapsed_seconds=elapsed, http_status=status,
        request_sha256=request_hash, response_sha256=response_hash, response=envelope,
        annotation=annotation, failure=failure, retry_after_seconds=retry_after,
    )
    with (config.output / (filename + ".result.json")).open("x") as stream:
        _ = stream.write(attempt.model_dump_json(indent=2) + "\n")
    return attempt


def run_benchmark(config: BenchmarkConfig) -> Path:
    """Authenticate against the correct provider before public-photo egress; preserve all paid/failed responses."""
    key = (os.environ.get("OPENROUTER_API_KEY") or os.environ.get("OPENAI_API_KEY") or "").strip()
    if not key:
        raise PipelineError("Missing local OpenRouter API key; never paste credentials in chat")
    reserved = reserve_total(config)
    with create_client() as client:
        client.headers["Authorization"] = "Bearer " + key
        auth = client.get("https://openrouter.ai/api/v1/key", follow_redirects=False)
        if auth.status_code != 200:
            raise PipelineError(f"OpenRouter authentication failed with HTTP {auth.status_code}; key not printed")
        receipt, photos = load_public_photos(config)
        config.output.mkdir(parents=True, exist_ok=False)
        _ = (config.output / "config.json").write_text(config.model_dump_json(indent=2) + "\n")
        _ = (config.output / "source-pins.json").write_text(json.dumps({
            "config_sha256": sha256(config.output / "config.json"), "receipt_sha256": config.receipt_sha256,
            "protocol_sha256": config.protocol_sha256, "catalog_sha256": config.catalog_sha256,
            "reserved_usd": reserved, "images": len(receipt.cases), "aihub_images": 0,
        }, indent=2) + "\n")
        schedule = [ScheduledPhoto(model, photo) for model in config.models for photo in photos]
        random.Random(config.seed).shuffle(schedule)  # noqa: S311 -- Reproducible experiment order, not security.
        attempts: list[ApiAttempt] = []
        for item in schedule:
            attempt = make_attempt(client, item, config)
            attempts.append(attempt)
            cost = attempt.response.usage.cost if attempt.response and attempt.response.usage else None
            print(item.model, item.photo.case.case_id, attempt.failure or "ok",  # noqa: T201 -- CLI progress.
                  round(attempt.elapsed_seconds, 3), cost, flush=True)
            observed = sum(a.response.usage.cost or 0 for a in attempts if a.response and a.response.usage)
            if attempt.http_status in (401, 402, 403) or observed > config.spending_limit_usd:
                raise PipelineError("Benchmark stopped on auth/funding/permission or budget limit; receipts saved")
            if attempt.failure == "transport_error_billing_unknown":
                raise PipelineError("Benchmark stopped on uncertain billing; do not blindly retry the paid request")
    target = config.output / "attempts.json"
    with target.open("x") as stream:
        _ = stream.write("[\n" + ",\n".join(a.model_dump_json(indent=2) for a in attempts) + "\n]\n")
    return target
