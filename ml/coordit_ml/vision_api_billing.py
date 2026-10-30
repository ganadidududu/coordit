"""Read-only OpenRouter generation-ledger cross-check, independent of pricing estimates."""

import json
import os
from pathlib import Path
from typing import ClassVar

from pydantic import BaseModel, ConfigDict, TypeAdapter

from coordit_ml.provenance import sha256
from coordit_ml.schema import PipelineError
from coordit_ml.source_downloads import create_client
from coordit_ml.vision_api_types import ApiAttempt, BenchmarkConfig


class GenerationCharge(BaseModel):
    """Keep only this experiment's generation identity and charge, excluding user/account metadata."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore", allow_inf_nan=False)
    id: str
    model: str
    provider_name: str | None = None
    total_cost: float
    is_byok: bool
    generation_time: float | None = None
    latency: float | None = None


class GenerationEnvelope(BaseModel):
    """Provider response parsed at the read-only ledger boundary."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    data: GenerationCharge


def audit_billing(config: BenchmarkConfig, output: Path) -> Path:
    """No image or inference is submitted; compare each stored usage.cost with the generation ledger."""
    key = (os.environ.get("OPENROUTER_API_KEY") or os.environ.get("OPENAI_API_KEY") or "").strip()
    if not key:
        raise PipelineError("Local OpenRouter credential missing for generation-ledger audit")
    attempts_path = config.output / "attempts.json"
    attempts = TypeAdapter(list[ApiAttempt]).validate_json(attempts_path.read_bytes())
    rows: list[GenerationCharge] = []
    with create_client() as client:
        for attempt in attempts:
            response = attempt.response
            if response is None or response.id is None or response.usage is None or response.usage.cost is None:
                raise PipelineError("Cannot independently audit missing generation identity or response cost")
            ledger = client.get(
                "https://openrouter.ai/api/v1/generation", params={"id": response.id},
                headers={"Authorization": "Bearer " + key}, follow_redirects=False,
            )
            if ledger.status_code != 200:
                raise PipelineError(f"Generation ledger unavailable: HTTP {ledger.status_code}; no inference retried")
            charge = GenerationEnvelope.model_validate_json(ledger.content).data
            matches = charge.id == response.id and abs(charge.total_cost - response.usage.cost) < 1e-9
            if not matches or charge.is_byok:
                raise PipelineError("Ledger disagrees with response cost or additional BYOK billing needs review")
            rows.append(charge)
    with output.open("x") as stream:
        _ = stream.write(json.dumps({
            "attempts_sha256": sha256(attempts_path), "generation_count": len(rows),
            "all_response_costs_match_ledger": True, "total_cost_usd": sum(row.total_cost for row in rows),
            "generations": [row.model_dump() for row in rows], "inference_requests_made_by_audit": 0,
        }, indent=2, allow_nan=False) + "\n")
    return output
