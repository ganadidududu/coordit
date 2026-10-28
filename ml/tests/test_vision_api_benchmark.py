import json
from pathlib import Path

import httpx2
import pytest

from coordit_ml.external_pilot import PilotCase
from coordit_ml.provenance import sha256
from coordit_ml.schema import PipelineError
from coordit_ml.vision_api_inputs import PublicPhoto, load_public_photos, reserve_total
from coordit_ml.vision_api_runner import ScheduledPhoto, make_attempt, parse_annotation
from coordit_ml.vision_api_types import ApiResponse, BenchmarkConfig


def fixture_config(root: Path) -> BenchmarkConfig:
    protocol, receipt, catalog = root / "protocol.md", root / "packet.json", root / "catalog.json"
    _ = protocol.write_text("fixture instructions")
    _ = receipt.write_text("{}")
    _ = catalog.write_text(json.dumps({"data": [{
        "id": "fixture/model", "pricing": {"prompt": "0.00001", "completion": "0.00005"},
        "architecture": {"input_modalities": ["text", "image"]},
        "supported_parameters": ["structured_outputs", "reasoning"],
    }]}))
    return BenchmarkConfig(
        receipt=receipt, receipt_sha256=sha256(receipt), protocol=protocol, protocol_sha256=sha256(protocol),
        catalog=catalog, catalog_sha256=sha256(catalog), models=["fixture/model"], output=root / "run",
    )


def fixture_photo() -> PublicPhoto:
    return PublicPhoto(PilotCase(
        case_id="P01", category="tshirt", source_image_id="public-fixture", image_file="P01.png",
        image_sha256="0" * 64, width=512, height=256,
    ), b"synthetic public fixture pixels")


def test_changed_public_packet_is_rejected_before_any_egress(tmp_path: Path) -> None:
    # Given packet bytes changed after predeclaring public image identity.
    config = fixture_config(tmp_path)
    _ = config.receipt.write_text("changed")
    # When preparing inputs, then no unverified replacement image can reach the transport.
    with pytest.raises(PipelineError, match="packet or protocol changed"):
        _ = load_public_photos(config)


def test_reservation_blocks_oversized_paid_experiment(tmp_path: Path) -> None:
    # Given a positive but inadequate budget for the exact selected model/photo exposure count.
    config = fixture_config(tmp_path).model_copy(update={"spending_limit_usd": 0.01})
    # When checking the experiment, then it fails before any provider request.
    with pytest.raises(PipelineError, match="exceeds"):
        _ = reserve_total(config)


def test_billed_invalid_answer_is_kept_without_retry(tmp_path: Path) -> None:
    # Given a real HTTP-level fixture returning billed tokens but malformed coordinate JSON.
    config = fixture_config(tmp_path)
    config.output.mkdir()
    calls: list[httpx2.Request] = []

    def handler(request: httpx2.Request) -> httpx2.Response:
        calls.append(request)
        return httpx2.Response(200, json={
            "id": "generation-fixture", "model": "fixture/model", "provider": "fixture",
            "choices": [{"message": {"content": "invalid JSON"}, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30, "cost": 0.001},
        })

    # When making one scheduled attempt, then the charge survives the parsing failure and no retry occurs.
    with httpx2.Client(transport=httpx2.MockTransport(handler)) as client:
        result = make_attempt(client, ScheduledPhoto("fixture/model", fixture_photo()), config)
    assert len(calls) == 1
    assert result.annotation is None
    assert result.failure == "invalid_annotation_json"
    assert result.response is not None
    assert result.response.usage is not None
    assert result.response.usage.cost == 0.001


def test_provider_error_cannot_persist_credential_fragment(tmp_path: Path) -> None:
    # Given a vendor error whose message includes a fake secret, as some authentication errors do.
    config = fixture_config(tmp_path)
    config.output.mkdir()
    secret = "unit-test-secret-never-persist"  # noqa: S105 -- Deliberately fake credential for leak regression.

    def handler(_request: httpx2.Request) -> httpx2.Response:
        return httpx2.Response(401, json={"error": {"code": "invalid_api_key", "message": secret}})

    # When storing the attempt receipt, then its allowlisted metadata retains failure without the secret.
    with httpx2.Client(
        transport=httpx2.MockTransport(handler), headers={"Authorization": "Bearer " + secret},
    ) as client:
        result = make_attempt(client, ScheduledPhoto("fixture/model", fixture_photo()), config)
    assert result.failure == "http_401"
    assert all(secret not in path.read_text() for path in config.output.glob("*.json"))


def test_truncated_completion_cannot_be_reported_as_success() -> None:
    # Given a JSON-looking but length-truncated answer.
    response = ApiResponse.model_validate({
        "choices": [{"message": {"content": "{}"}, "finish_reason": "length"}],
    })
    # When parsing, then the response remains a failed attempt even if some coordinates could be guessed.
    annotation, failure = parse_annotation(response, fixture_photo())
    assert annotation is None
    assert failure == "incomplete_or_refused"
