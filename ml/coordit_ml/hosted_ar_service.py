"""Separate opt-in development gateway; never runs inside the production backend."""

import hmac
import os
from typing import Annotated

from anyio import CapacityLimiter, to_thread
from fastapi import FastAPI, Header, HTTPException, Request
from pydantic import ValidationError

from coordit_ml.hosted_ar_inference import HostedRequest, HostedResult, infer_hosted
from coordit_ml.schema import PipelineError

app = FastAPI(title="Coordit hosted AR field test", docs_url=None, redoc_url=None)
_LIMITER = CapacityLimiter(1)
_ATTEMPT_LIMIT = 60
_attempts = 0


@app.get("/health")
def health() -> dict[str, str | bool]:
    """No configuration, access token, private image or provider API key is exposed."""
    return {"service": "coordit-hosted-ar-field", "deployment_approved": False}


@app.post("/v1/hosted-landmarks")
async def hosted_landmarks(request: Request, authorization: Annotated[str | None, Header()] = None) -> HostedResult:
    """Authenticate before reading any pixels; bounded body, explicit consent, no raw-photo logging or storage."""
    global _attempts  # noqa: PLW0603 -- Process-local hard attempt cap for this single-worker development gateway.
    if os.environ.get("COORDIT_HOSTED_AR_DEVELOPMENT") != "true":
        raise HTTPException(503, "hosted_field_test_disabled")
    token = os.environ.get("COORDIT_HOSTED_AR_TOKEN", "")
    if len(token) < 32 or not hmac.compare_digest((authorization or "").encode(), ("Bearer " + token).encode()):
        raise HTTPException(401, "authentication_required")
    content = bytearray()
    async for chunk in request.stream():
        if len(content) + len(chunk) > 4_100_000:
            raise HTTPException(413, "request_too_large")
        content.extend(chunk)
    try:
        parsed = HostedRequest.model_validate_json(content)
        if not parsed.processing_consent:
            raise HTTPException(403, "processing_consent_required")
        if _attempts >= _ATTEMPT_LIMIT:
            raise HTTPException(429, "development_attempt_limit")
        _attempts += 1
        return await to_thread.run_sync(infer_hosted, parsed, limiter=_LIMITER)
    except ValidationError as error:
        raise HTTPException(422, "invalid_request") from error
    except PipelineError as error:
        raise HTTPException(502, "hosted_inference_failed_keep_existing_measurements") from error
