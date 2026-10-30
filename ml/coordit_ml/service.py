"""Independent, disabled-by-default inference service; never mounts in the existing backend."""

import hmac
import os
from pathlib import Path
from typing import Annotated

from anyio import CapacityLimiter, to_thread
from fastapi import FastAPI, Header, HTTPException, Request
from pydantic import Field

from coordit_ml.inference import InferenceResult, infer_image
from coordit_ml.schema import BoundaryModel

_LIMITER = CapacityLimiter(1)

app = FastAPI(title="Coordit garment research", docs_url=None, redoc_url=None)


class InferenceRequest(BoundaryModel):
    """Consent-bearing metadata-free image payload."""

    image_base64: Annotated[str, Field(max_length=4_000_000)]
    processing_consent: bool
    training_consent: bool = False


@app.get("/health")
def health() -> dict[str, str | bool]:
    """Health does not claim a model is installed, approved or accurate."""
    return {"service": "coordit-garment-ml", "deployment_approved": False}


@app.post("/v1/landmarks", response_model=InferenceResult)
async def landmarks(request: Request, authorization: Annotated[str | None, Header()] = None) -> InferenceResult:
    """Local research only until legal, accuracy, identity and gateway review are complete."""
    import base64
    import binascii

    from PIL import UnidentifiedImageError
    from pydantic import ValidationError

    from coordit_ml.schema import PipelineError

    if os.environ.get("COORDIT_ML_DEVELOPMENT") != "true":
        raise HTTPException(503, "model_not_deployment_approved")
    token = os.environ.get("COORDIT_ML_API_TOKEN", "")
    if len(token) < 32 or not hmac.compare_digest(authorization or "", "Bearer " + token):
        raise HTTPException(401, "authentication_required")
    content = bytearray()
    async for chunk in request.stream():
        if len(content) + len(chunk) > 4_100_000:
            raise HTTPException(413, "request_too_large")
        content.extend(chunk)
    try:
        parsed = InferenceRequest.model_validate_json(content)
        if not parsed.processing_consent:
            raise HTTPException(403, "explicit_processing_consent_required")
        if parsed.training_consent:
            raise HTTPException(422, "this_service_does_not_collect_training_data")
        image = base64.b64decode(parsed.image_base64, validate=True)
        directory = os.environ.get("COORDIT_ML_MODEL_DIRECTORY")
        if not directory or not all((Path(directory) / file).is_file() for file in ("artifact.json", "checkpoint.pt")):
            raise HTTPException(503, "model_not_installed")
        return await to_thread.run_sync(infer_image, Path(directory), image, limiter=_LIMITER)
    except (ValidationError, binascii.Error, UnidentifiedImageError, PipelineError) as error:
        raise HTTPException(422, "invalid_image_or_artifact") from error
