from pathlib import Path

import pytest

from coordit_ml.external_pilot import ExternalPoint, require_public_artf
from coordit_ml.external_pilot_comparison import ExternalComparison, compare_external_pilot
from coordit_ml.external_pilot_metrics import (
    PhotoMetrics,
    PixelLength,
    matched_length_summaries,
    photo_metrics,
    summarize_photos,
)
from coordit_ml.provenance import read_records, sha256
from coordit_ml.schema import Landmark, PipelineError
from coordit_ml.synthetic import generate


def test_aihub_is_blocked_even_with_plausible_public_license_and_test_path(tmp_path: Path) -> None:
    # Given a nonempty authored fixture relabeled as AI Hub with otherwise public-looking metadata.
    record = read_records(generate(tmp_path / "fixture", 1))[0].model_copy(
        update={
            "source_dataset": "aihub-71501",
            "category": "tshirt",
            "original_license": "CC-BY-4.0",
            "split": "test",
            "source_path": "test/source.png",
        }
    )
    # When preparing external pixels, then the actual source identity wins over permissive-looking fields.
    with pytest.raises(PipelineError, match="public aRTF"):
        require_public_artf(record, "CC-BY-4.0")


def test_abstentions_remain_point_failures_and_failed_lengths(tmp_path: Path) -> None:
    # Given four visible GT points with one missing external shoulder proposal.
    coordinates = {
        "shoulder_left": (0.25, 0.25),
        "shoulder_right": (0.75, 0.25),
        "armpit_left": (0.25, 0.6),
        "armpit_right": (0.75, 0.6),
    }
    points = [
        Landmark(landmark_type=k, x=x, y=y, visibility=2, source="authored_fixture")
        for k, (x, y) in coordinates.items()
    ]
    record = read_records(generate(tmp_path / "fixture", 1))[0].model_copy(
        update={
            "category": "tshirt",
            "width": 512,
            "height": 256,
            "keypoints": points,
        }
    )
    proposals: dict[str, tuple[float, float] | None] = dict(coordinates)
    proposals["shoulder_left"] = None
    # When scoring the same visible GT, then omission cannot inflate PCK or make a missing length accurate.
    result = summarize_photos([photo_metrics("fixture", record, proposals)])
    assert result["all"]["pck_005_all_visible_gt"] == 0.75
    assert result["all"]["nme_supplied_only"] == 0
    assert result["all"]["nme_with_abstention_penalty_1"] == 0.25
    assert result["all"]["coverage"] == 0.75
    assert result["all/shoulder_width"]["failed_pairs"] == 1
    assert result["all/shoulder_width"]["mean_relative_error_supplied_only"] is None
    assert result["all/chest_width"]["mean_absolute_error_pixels_supplied_only"] == 0


def test_changed_frozen_proposal_file_cannot_be_rescored_as_the_original_response(tmp_path: Path) -> None:
    # Given an exact packet pin and a response file whose bytes differ from its pre-scoring pin.
    receipt, predictions = tmp_path / "packet.json", tmp_path / "response.json"
    _ = receipt.write_text("{}")
    _ = predictions.write_text("changed after inspection")
    config = ExternalComparison(
        receipt=receipt,
        receipt_sha256=sha256(receipt),
        predictions=predictions,
        predictions_sha256="0" * 64,
        protocol=tmp_path / "protocol.md",
        output=tmp_path / "metrics.json",
    )
    # When comparing, then identity mismatch blocks scoring before any model or GT is loaded.
    with pytest.raises(PipelineError, match="frozen external responses changed"):
        _ = compare_external_pilot(config)
    assert not config.output.exists()


def test_abstention_cannot_carry_an_apparently_precise_coordinate() -> None:
    # Given a provider response that declares abstention yet supplies numeric coordinates.
    # When parsing, then its contradictory state is rejected.
    with pytest.raises(PipelineError, match="status"):
        _ = ExternalPoint(landmark_type="shoulder_left", x=0.5, y=0.5, status="abstain")


def test_secondary_matching_does_not_remove_primary_failed_pairs() -> None:
    # Given one missing external length and a complete local prediction for the same photograph.
    external = PhotoMetrics(
        case_id="A",
        category="tshirt",
        point_errors={"shoulder_left": None},
        lengths=[
            PixelLength(
                dimension="shoulder_width",
                ground_truth_pixels=10,
                predicted_pixels=None,
                absolute_error_pixels=None,
                relative_error=None,
            ),
        ],
    )
    local = external.model_copy(
        update={
            "lengths": [
                PixelLength(
                    dimension="shoulder_width",
                    ground_truth_pixels=10,
                    predicted_pixels=12,
                    absolute_error_pixels=2,
                    relative_error=0.2,
                ),
            ]
        }
    )
    # When matching supplied pairs, then neither participant has a matched pair, while the primary failure remains.
    result = matched_length_summaries({"external": [external], "local": [local]}, "external")
    assert result["external"] == {}
    assert result["local"] == {}
    assert summarize_photos([external])["all/shoulder_width"]["failed_pairs"] == 1
