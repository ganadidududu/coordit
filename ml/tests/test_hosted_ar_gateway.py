import base64
import io
import uuid

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from coordit_ml.hosted_ar_inference import HostedRequest, clean_pixels, infer_hosted
from coordit_ml.hosted_ar_service import app
from coordit_ml.schema import PipelineError


def test_gateway_is_disabled_without_development_flag(monkeypatch: pytest.MonkeyPatch) -> None:
    # Given the default deployment state.
    monkeypatch.delenv("COORDIT_HOSTED_AR_DEVELOPMENT", raising=False)
    # When an unauthenticated user submits even an empty body, then no provider call occurs.
    assert TestClient(app).post("/v1/hosted-landmarks", json={}).status_code == 503


def test_gateway_authenticates_before_image_decode(monkeypatch: pytest.MonkeyPatch) -> None:
    # Given development is enabled with a private gateway credential.
    monkeypatch.setenv("COORDIT_HOSTED_AR_DEVELOPMENT", "true")
    monkeypatch.setenv("COORDIT_HOSTED_AR_TOKEN", "g" * 40)
    # When no credential is supplied, then malformed image data cannot reach inference.
    assert TestClient(app).post("/v1/hosted-landmarks", json={"image_base64": "invalid"}).status_code == 401


def test_unconsented_photo_never_reaches_paid_inference(monkeypatch: pytest.MonkeyPatch) -> None:
    # Given an authenticated but explicitly unconsented submission.
    monkeypatch.setenv("COORDIT_HOSTED_AR_DEVELOPMENT", "true")
    monkeypatch.setenv("COORDIT_HOSTED_AR_TOKEN", "g" * 40)
    body = HostedRequest(image_base64="invalid", category="tshirt", model="astra", frame_id=uuid.uuid4(),
                         processing_consent=False)
    # When sent, then consent is checked before attempting to decode or upload the image.
    response = TestClient(app).post("/v1/hosted-landmarks", json=body.model_dump(mode="json"),
                                    headers={"Authorization": "Bearer " + "g" * 40})
    assert response.status_code == 403


def test_image_cleaning_removes_metadata_without_changing_pixel_frame() -> None:
    # Given an authored image with location-like EXIF and known non-square dimensions.
    image = Image.new("RGB", (128, 96), "red")
    exif = Image.Exif()
    exif[270] = "private metadata should not survive"
    stream = io.BytesIO()
    image.save(stream, format="JPEG", exif=exif)
    # When reconstructed, then the original coordinate frame survives while metadata disappears.
    pixels = clean_pixels(base64.b64encode(stream.getvalue()).decode())
    with Image.open(io.BytesIO(pixels)) as result:
        assert result.size == (128, 96)
        assert not result.getexif()


def test_exif_only_rotation_is_rejected_instead_of_silently_moving_coordinates() -> None:
    # Given a client that sends rotated EXIF rather than upright pixels.
    exif = Image.Exif()
    exif[274] = 6
    stream = io.BytesIO()
    Image.new("RGB", (128, 96), "red").save(stream, format="JPEG", exif=exif)
    # When decoding, then an inconsistent coordinate system is rejected.
    with pytest.raises(PipelineError, match="upright"):
        _ = clean_pixels(base64.b64encode(stream.getvalue()).decode())


def test_non_ascii_credential_is_rejected_without_server_error(monkeypatch: pytest.MonkeyPatch) -> None:
    # Given an enabled gateway and a malformed non-ASCII bearer credential.
    monkeypatch.setenv("COORDIT_HOSTED_AR_DEVELOPMENT", "true")
    monkeypatch.setenv("COORDIT_HOSTED_AR_TOKEN", "g" * 40)
    # When authenticating, then no decoding, paid inference or unhandled compare_digest error occurs.
    response = TestClient(app).post("/v1/hosted-landmarks", content=b"{}",
                                    headers={b"Authorization": b"Bearer \xff"})
    assert response.status_code == 401


@pytest.mark.parametrize(("category", "basis"), [("skirt", "high_shoulder_to_hem"), ("tshirt", "waist_to_hem")])
def test_incompatible_length_basis_fails_before_photo_decode_or_paid_call(category: str, basis: str) -> None:
    # Given otherwise parseable input with a category-incompatible measurement definition.
    request = HostedRequest.model_validate({"image_base64": "invalid", "category": category, "model": "astra",
        "frame_id": str(uuid.uuid4()), "processing_consent": True, "length_basis": basis})
    # When processing it, then the incompatible measurement basis is refused before any paid work.
    with pytest.raises(PipelineError, match="length basis"):
        _ = infer_hosted(request)
