from pathlib import Path

import pytest
import torch

from coordit_ml.centimeter_evaluation import evaluate_centimeters
from coordit_ml.heatmap_network import GarmentHeatmapNet, spatial_loss
from coordit_ml.network import ApprovedDataset, batch
from coordit_ml.proposal_validation import rejection_reason
from coordit_ml.provenance import REGISTRY_ROOT, audit_records
from coordit_ml.schema import CATEGORIES, Landmark, PipelineError, dimension_landmarks, read_registry
from coordit_ml.synthetic_v2 import generate_v2
from coordit_ml.training import TrainingConfig, load_model, train


def test_spatial_model_learns_visible_landmarks_from_actual_generated_pixels(tmp_path: Path) -> None:
    torch.set_num_threads(2)
    _ = torch.manual_seed(42)
    manifest = generate_v2(tmp_path / "scenes", per_category=2, seed=257)
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    records = audit_records(manifest, registry)
    assert {record.category for record in records} == set(CATEGORIES)
    dataset = ApprovedDataset([manifest], registry, "train")
    dataset.image_size = 128
    target = batch(dataset, [0, 1], "cpu")
    model = GarmentHeatmapNet()
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.002)
    before = float(spatial_loss(model.forward(target.pixels), target).detach())
    for _ in range(15):
        optimizer.zero_grad()
        loss = spatial_loss(model.forward(target.pixels), target)
        _ = loss.backward()
        _ = optimizer.step()
    after = float(spatial_loss(model.forward(target.pixels), target).detach())
    assert after < before * 0.75
    assert model.forward(target.pixels).mask.shape[-2:] == (128, 128)


def test_spatial_artifact_load_and_resume_and_manifest_tampering(tmp_path: Path) -> None:
    manifest = generate_v2(tmp_path / "scenes", per_category=2)
    config = TrainingConfig(
        manifests=[manifest],
        output=tmp_path / "model",
        epochs=1,
        batch_size=2,
        max_steps=1,
        architecture="coordit-spatial-multitask-v2",
    )
    _ = train(config)
    assert load_model(config.output).input_size == 128
    _ = train(config.model_copy(update={"resume": True, "epochs": 2}))
    with manifest.open("a") as stream:
        _ = stream.write("\n")
    with pytest.raises(PipelineError, match="manifest changed"):
        _ = load_model(config.output)


def test_proposal_rejects_collapsed_segments_empty_masks_and_occlusion() -> None:
    names = {name for pair in dimension_landmarks("skirt").values() for name in pair}
    points = [Landmark(landmark_type=name, x=0.5, y=0.5, visibility=2, confidence=0.9, source="test") for name in names]
    empty = torch.zeros(64, 64, dtype=torch.bool)
    assert rejection_reason("skirt", points, empty) == "invalid_segmentation_coverage"
    empty[10:55, 10:55] = True
    assert rejection_reason("skirt", points, empty) == "collapsed_measurement_segment"
    hidden = [point.model_copy(update={"visibility": 0}) for point in points]
    assert rejection_reason("skirt", hidden, empty) == "landmarks_missing_or_occluded"


def test_tape_release_cannot_pass_missing_categories_or_only_easy_successes(tmp_path: Path) -> None:
    csv = tmp_path / "tape.csv"
    header = "garment_id,category,method,dimension,ground_truth_cm,predicted_cm,independent,synthetic\n"
    rows = [f"g{i},skirt,arPlane,waist_width,35,{35 if i == 0 else ''},true,false\n" for i in range(20)]
    _ = csv.write_text(header + "".join(rows))
    report = evaluate_centimeters(csv)
    assert len(report) == 43
    assert report["arPlane/skirt/waist_width"]["successful_garments"] == 1
    assert report["arPlane/skirt/waist_width"]["accuracy_target_met"] is False
    assert report["arPlane/coat/chest_width"]["accuracy_target_met"] is False
    assert "arPlane/skirt/rise" not in report
