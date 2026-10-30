import io
from pathlib import Path

import httpx2
import pytest
from PIL import Image

import coordit_ml.vision_refinement_packet as packet
from coordit_ml.external_pilot import ExternalPoint, PilotCase
from coordit_ml.provenance import read_records, sha256
from coordit_ml.schema import Landmark, PipelineError
from coordit_ml.synthetic import generate
from coordit_ml.vision_api_inputs import PublicPhoto
from coordit_ml.vision_api_types import ApiAnnotation, BenchmarkConfig, ModelCatalog
from coordit_ml.vision_refinement_crop import CropBox, proposal_crop
from coordit_ml.vision_refinement_report import measurement_metrics, usable_proposals
from coordit_ml.vision_refinement_runner import RefinementConfig, verify_refinement


def test_crop_inverse_preserves_native_aspect_and_uncertainty() -> None:
    # Given a non-square source and an offset crop with both uncertain and hidden landmarks.
    crop = CropBox(left=128, top=64, right=384, bottom=192, image_width=512, image_height=256)
    annotation = ApiAnnotation(
        points=[
            ExternalPoint(landmark_type="shoulder_left", x=0.25, y=0.75, status="uncertain_proposal"),
            ExternalPoint(landmark_type="shoulder_right", x=None, y=None, status="abstain"),
        ],
        note="fixture",
    )
    # When restoring from crop coordinates, then each axis uses its own native dimension and status is preserved.
    restored = crop.restore(annotation)
    assert restored.points[0].x == pytest.approx(0.375)
    assert restored.points[0].y == pytest.approx(0.625)
    assert restored.points[0].status == "uncertain_proposal"
    assert restored.points[1].x is None
    assert restored.points[1].y is None


def test_uncertain_coordinate_cannot_count_as_an_ar_usable_point() -> None:
    # Given a supplied but uncertain draft that the phone would refuse for centimeters.
    annotation = ApiAnnotation(
        points=[ExternalPoint(landmark_type="shoulder_left", x=0.4, y=0.6, status="uncertain_proposal")], note="fixture"
    )
    # When forming both metric profiles, then proposal-only accuracy cannot inflate AR usability.
    strict = usable_proposals(annotation, "tshirt", visible_only=True)
    tentative = usable_proposals(annotation, "tshirt", visible_only=False)
    assert strict["shoulder_left"] is None
    assert tentative["shoulder_left"] == (0.4, 0.6)
    assert len(strict) == 4


def test_no_draft_uses_whole_original_frame_without_inventing_landmarks() -> None:
    # Given a public pixel-only photo boundary with no valid previous model answer.
    stream = io.BytesIO()
    Image.new("RGB", (512, 256), "blue").save(stream, format="PNG")
    photo = PublicPhoto(
        PilotCase(
            case_id="P01",
            category="tshirt",
            source_image_id="fixture",
            image_file="P01.png",
            image_sha256="0" * 64,
            width=512,
            height=256,
        ),
        stream.getvalue(),
    )
    # When choosing a review view, then all source pixels remain available rather than guessed keypoints.
    crop = proposal_crop(photo, None)
    assert (crop.left, crop.top, crop.right, crop.bottom) == (0, 0, 512, 256)


def test_out_of_source_crop_is_refused_instead_of_clamping_predictions() -> None:
    # Given corrupt transform metadata that would map a normalized point outside the photograph.
    crop = CropBox(left=128, top=64, right=900, bottom=192, image_width=512, image_height=256)
    # When restoring, then no fabricated boundary point reaches scoring.
    with pytest.raises(PipelineError, match="crop bounds"):
        _ = crop.restore(ApiAnnotation(points=[], note="fixture"))


def test_current_catalog_keeps_selected_prices_strict_with_router_sentinels(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Given current catalog metadata with negative-price router aliases and extra pagination fields.
    def handler(_request: httpx2.Request) -> httpx2.Response:
        rows = [
            {
                "id": name,
                "pricing": {"prompt": price, "completion": price},
                "architecture": {"input_modalities": ["text", "image"]},
                "supported_parameters": ["structured_outputs", "reasoning"],
            }
            for name, price in (
                ("openai/gpt-6-astra", "0.000001"),
                ("google/gemini-3.8-flash", "0.000001"),
                ("router/auto", "-1"),
            )
        ]
        return httpx2.Response(200, json={"data": rows, "total_count": 3, "links": {"next": None}})

    # When refreshing at the HTTP boundary, then only requested positive-priced models survive.
    monkeypatch.setattr(packet, "create_client", lambda: httpx2.Client(transport=httpx2.MockTransport(handler)))
    catalog = ModelCatalog.model_validate_json(packet.current_catalog(tmp_path).read_bytes())
    assert len(catalog.data) == 2
    assert all(m.pricing.prompt > 0 for m in catalog.data)


def test_original_frame_answer_is_not_affine_transformed_again() -> None:
    # Given a follow-up explicitly reporting original-image coordinates, despite receiving a crop.
    crop = CropBox(left=128, top=64, right=384, bottom=192, image_width=512, image_height=256)
    answer = ApiAnnotation(
        points=[ExternalPoint(landmark_type="shoulder_left", x=0.4, y=0.6, status="visible_proposal")], note="fixture"
    )
    # When restoring that declared frame, then no second transform introduces scale/offset error.
    assert crop.restore(answer, "original") == answer


@pytest.mark.parametrize("missing_hem", [False, True])
def test_projected_outseam_uses_outer_hem_and_keeps_missing_pair(tmp_path: Path, *, missing_hem: bool) -> None:
    # Given authored native-pixel GT; the crouch point is deliberately unrelated to the outer side seam.
    coordinates = {"waist_left": (0.2, 0.2), "waist_right": (0.8, 0.2), "crotch": (0.5, 0.5), "side_hem": (0.2, 0.8)}
    points = [
        Landmark(landmark_type=n, x=x, y=y, visibility=2, source="authored_fixture")
        for n, (x, y) in coordinates.items()
    ]
    record = read_records(generate(tmp_path / "fixture", 1))[0].model_copy(
        update={"category": "shorts", "width": 512, "height": 256, "keypoints": points}
    )
    proposals: dict[str, tuple[float, float] | None] = dict(coordinates)
    if missing_hem:
        proposals["side_hem"] = None
    # When measuring the documented same-side endpoints, then the GT pair remains even when prediction is missing.
    result = measurement_metrics("fixture", record, proposals)
    pair = next(p for p in result.lengths if p.dimension == "outseam")
    assert pair.ground_truth_pixels == pytest.approx(153.6)
    if missing_hem:
        assert pair.predicted_pixels is None
    else:
        assert pair.predicted_pixels == pytest.approx(153.6)


@pytest.mark.parametrize("partial", [False, True])
def test_empty_experiment_cannot_be_scored_as_a_completed_comparison(tmp_path: Path, *, partial: bool) -> None:
    # Given an interrupted run without any persisted result, even if partial scoring was explicitly requested.
    parent = tmp_path / "parents.json"
    _ = parent.write_text("[]")
    baseline = BenchmarkConfig(
        receipt=parent, receipt_sha256=sha256(parent),
        protocol=parent, protocol_sha256=sha256(parent),
        catalog=parent, catalog_sha256=sha256(parent),
        models=["fixture/model"], output=tmp_path / "unused",
    )
    config = RefinementConfig(
        baseline=baseline, parent_attempts=parent, parent_attempts_sha256=sha256(parent), output=tmp_path / "empty",
    )
    # When verifying, then the empty output cannot become a zero-error model result.
    with pytest.raises(PipelineError, match="no result receipts"):
        _ = verify_refinement(config, allow_partial=partial)
