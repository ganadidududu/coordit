import random
import struct
from pathlib import Path
from typing import Literal, assert_never

import numpy as np
import pytest

from coordit_ml.artf_landmarks import mapped_landmarks
from coordit_ml.finetuning import ParentCheckpoint, initialize
from coordit_ml.garmentcode_mesh import GarmentMesh, read_mesh
from coordit_ml.garmentcode_topology import recover_panels
from coordit_ml.mesh_projection import (
    PhysicalSurface,
    PinholeCamera,
    project,
    render_mesh,
    visible_on_surface,
)
from coordit_ml.model_factory import create_model
from coordit_ml.provenance import REGISTRY_ROOT, read_records, sha256
from coordit_ml.sampling import SourceSampling, sample_sources
from coordit_ml.schema import Landmark, PipelineError, read_registry
from coordit_ml.seam_reviews import ReviewedPoint, ReviewImport, SeamReview, import_seam_reviews
from coordit_ml.synthetic import generate
from coordit_ml.training import TrainingConfig, train


def test_artf_only_maps_present_publisher_points_without_midpoint_or_visibility_invention(tmp_path: Path) -> None:
    # Given a partial, occluded publisher annotation.
    record = read_records(generate(tmp_path / "data", 1))[0].model_copy(
        update={
            "category": "tshirt",
            "source_keypoints": [
                Landmark(landmark_type="artf:shoulder_left", x=0.2, y=0.3, visibility=2, source="publisher"),
                Landmark(landmark_type="artf:armpit_left", x=0.3, y=0.6, visibility=1, source="publisher"),
                Landmark(landmark_type="artf:neck_left", x=0.5, y=0.3, visibility=2, source="publisher"),
            ],
        }
    )
    # When mapping reviewed direct labels.
    points = mapped_landmarks(record)
    # Then no total-length, sleeve or invisible partner is manufactured.
    assert [(p.landmark_type, p.visibility) for p in points] == [("shoulder_left", 2), ("armpit_left", 1)]
    assert [(p.x, p.y) for p in points] == [(0.2, 0.3), (0.3, 0.6)]


def test_source_quotas_are_deterministic_and_preserve_all_requested_sources() -> None:
    # Given imbalanced pools and a source-specific budget.
    sources = ["real"] * 90 + ["seams"] * 10
    policy = SourceSampling(weights={"real": 1, "seams": 3}, epoch_images=40)
    # When drawing one epoch.
    samples = sample_sources(sources, policy, random.Random(42))
    # Then exposure counts reflect policy, not raw corpus size or fictional new images.
    assert sum(sources[i] == "real" for i in samples) == 10
    assert sum(sources[i] == "seams" for i in samples) == 30
    assert samples == sample_sources(sources, policy, random.Random(42))
    assert len({i for i in samples if sources[i] == "seams"}) == 10


@pytest.mark.parametrize("weights", [{"real": 1}, {"real": 1, "seams": 0}, {"real": 1, "seams": -1}])
def test_source_sampler_rejects_silent_source_drop(weights: dict[str, float]) -> None:
    # Given an incomplete or invalid requested source ratio.
    policy = SourceSampling(weights=weights, epoch_images=10)
    # When drawing from both sources, then fail rather than omit supervision silently.
    with pytest.raises(PipelineError):
        _ = sample_sources(["real", "seams"], policy, random.Random(42))


def test_pinhole_projection_preserves_pose_scale_and_rejects_behind_camera_points() -> None:
    # Given world cm with a translated camera and known focal lengths.
    camera = PinholeCamera(
        width=64,
        height=64,
        intrinsics=((100, 0, 32), (0, 100, 32), (0, 0, 1)),
        rotation=((1, 0, 0), (0, 1, 0), (0, 0, 1)),
        translation_cm=(0, 0, 100),
    )
    # When projecting a ten-cm horizontal segment.
    result = project(np.array([[0, 0, 0], [10, 0, 0]], dtype=np.float64), camera)
    # Then its ten-pixel length follows the same frozen camera state.
    assert np.allclose(result, [[32, 32, 100], [42, 32, 100]])
    with pytest.raises(PipelineError, match="behind"):
        _ = project(np.array([[0, 0, -101]], dtype=np.float64), camera)


def test_zbuffer_rejects_occluded_seam_and_preserves_the_front_surface() -> None:
    # Given two overlapping triangles at distinct physical depths.
    camera = PinholeCamera(
        width=64,
        height=64,
        intrinsics=((50, 0, 32), (0, 50, 32), (0, 0, 1)),
        rotation=((1, 0, 0), (0, 1, 0), (0, 0, 1)),
        translation_cm=(0, 0, 0),
    )
    vertices = np.array(
        [[-10, -10, 50], [10, -10, 50], [0, 10, 50], [-20, -20, 100], [20, -20, 100], [0, 20, 100]], dtype=np.float64
    )
    # When rasterizing and projecting a point behind the front triangle.
    rendered = render_mesh(vertices, np.array([[3, 4, 5], [0, 1, 2]], dtype=np.int64), camera)
    # Then the hidden landmark is not visible supervision.
    assert rendered.depth_cm[32, 32] == pytest.approx(50)
    surface = PhysicalSurface(vertices, np.array([[3, 4, 5], [0, 1, 2]], dtype=np.int64))
    assert not visible_on_surface((0, 0, 100), surface, camera)
    assert visible_on_surface((0, 0, 50), surface, camera)


def test_uv_islands_restore_multiple_panel_memberships_at_one_physical_seam() -> None:
    # Given two disconnected UV islands sharing one canonical physical vertex.
    vertices = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0], [0, 0, 0], [-1, 0, 0], [0, -1, 0]], dtype=np.float64)
    mesh = GarmentMesh(
        vertices,
        np.array([[0, 1, 2], [3, 4, 5]], dtype=np.int64),
        np.array([0, 1, 2, 0, 3, 4], dtype=np.int64),
        vertices[[0, 1, 2, 4, 5]],
    )
    # When restoring publisher panel identities through actual triangle connectivity.
    topology = recover_panels(mesh, [{"stitch_0"}, {"front"}, {"front"}, {"back"}, {"back"}])
    # Then the sewn junction belongs to both panels without coordinate guessing.
    assert topology.panels[0] == {"front", "back"}
    assert topology.panels[1] == {"front"}


def test_ply_reader_preserves_canonical_ids_across_exact_adjacent_uv_duplicates(tmp_path: Path) -> None:
    # Given the source layout with an adjacent duplicated seam vertex.
    target = tmp_path / "mesh.ply"
    header = (
        "ply\nformat binary_little_endian 1.0\ncomment https://github.com/mikedh/trimesh\n"
        "element vertex 4\nproperty float x\nproperty float y\nproperty float z\nproperty double s\n"
        "property double t\nelement face 1\nproperty list uchar int vertex_indices\nend_header\n"
    )
    coordinates = [(0, 0, 0), (0, 0, 0), (1, 0, 0), (0, 1, 0)]
    _ = target.write_bytes(
        header.encode()
        + b"".join(struct.pack("<fffdd", *xyz, 0, 0) for xyz in coordinates)
        + struct.pack("<Biii", 3, 0, 2, 3)
    )
    # When reading without topology-processing libraries.
    mesh = read_mesh(target)
    # Then label vertex indices remain canonical publisher identities.
    assert mesh.canonical_ids.tolist() == [0, 0, 1, 2]
    assert mesh.faces.tolist() == [[0, 2, 3]]


def test_finetune_parent_is_preserved_and_tampered_metadata_is_rejected(tmp_path: Path) -> None:
    # Given a completed, pinned baseline.
    manifest = generate(tmp_path / "scenes", 1)
    run = tmp_path / "baseline"
    _ = train(TrainingConfig(manifests=[manifest], output=run, epochs=1, batch_size=2, max_steps=1))
    parent = ParentCheckpoint(
        directory=run, checkpoint_sha256=sha256(run / "checkpoint.pt"), artifact_sha256=sha256(run / "artifact.json")
    )
    # When initializing a separate model from that baseline.
    initialize(create_model("coordit-tiny-multitask-v1", category_heads=False), parent)
    # Then both baseline files remain byte-identical and metadata substitution is refused.
    assert sha256(run / "checkpoint.pt") == parent.checkpoint_sha256
    assert sha256(run / "artifact.json") == parent.artifact_sha256
    with pytest.raises(PipelineError, match="explicit pin"):
        initialize(
            create_model("coordit-tiny-multitask-v1", category_heads=False),
            parent.model_copy(update={"artifact_sha256": "0" * 64}),
        )


@pytest.mark.parametrize("state", ["proposal", "verified", "rejected"])
def test_seam_review_requires_verified_source_matched_annotations(
    tmp_path: Path, state: Literal["proposal", "verified", "rejected"]
) -> None:
    # Given a source record and a proposed/manual seam annotation.
    manifest = generate(tmp_path / "scenes", 1)
    record = read_records(manifest)[0]
    point = record.keypoints[0]
    review = SeamReview.model_validate(
        {
            "image_id": record.image_id,
            "image_sha256": record.sha256,
            "coordinate_system": "upright_rgb_normalized_top_left",
            "points": [
                {
                    "landmark": point.model_dump(),
                    "review_status": state,
                    "reviewer": "local-test-reviewer",
                    "protocol": "fixture exact authored vertex",
                    "evidence": "fixture geometry correspondence",
                }
            ],
        }
    )
    path = tmp_path / "reviews.jsonl"
    _ = path.write_text(review.model_dump_json() + "\n")
    config = ReviewImport(manifest=manifest, reviews=path, output=tmp_path / "reviewed")
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    # When importing the annotation, then drafts/rejections cannot become training truth.
    match state:
        case "proposal" | "rejected":
            with pytest.raises(PipelineError, match="verified visible"):
                _ = import_seam_reviews(config, registry)
        case "verified":
            assert len(read_records(import_seam_reviews(config, registry))) == len(read_records(manifest))
        case unreachable:
            assert_never(unreachable)


def test_verified_seam_on_another_crop_is_rejected(tmp_path: Path) -> None:
    # Given a manually verified point referencing a different pixel crop.
    manifest = generate(tmp_path / "scenes", 1)
    record = read_records(manifest)[0]
    review = SeamReview(
        image_id=record.image_id,
        image_sha256="0" * 64,
        coordinate_system="upright_rgb_normalized_top_left",
        points=[
            ReviewedPoint(
                landmark=record.keypoints[0],
                review_status="verified",
                reviewer="local-test",
                protocol="authored fixture",
                evidence="pixel geometry",
            )
        ],
    )
    path = tmp_path / "reviews.jsonl"
    _ = path.write_text(review.model_dump_json() + "\n")
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    # When importing, then the source mismatch fails before output creation.
    with pytest.raises(PipelineError, match="another image/crop"):
        _ = import_seam_reviews(ReviewImport(manifest=manifest, reviews=path, output=tmp_path / "reviewed"), registry)
