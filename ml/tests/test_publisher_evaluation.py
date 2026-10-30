import hashlib
import io
import json
import zipfile
from pathlib import Path

import pytest
from PIL import Image, ImageDraw

from coordit_ml import publisher_test
from coordit_ml.history import HistoryPin
from coordit_ml.network import ApprovedDataset
from coordit_ml.provenance import REGISTRY_ROOT, read_records, sha256
from coordit_ml.schema import PipelineError, Registry, read_registry
from coordit_ml.synthetic import generate


def _source_fixture(tmp_path: Path) -> tuple[publisher_test.TestPreparation, Registry]:
    training = generate(tmp_path / "training", 1)
    run = tmp_path / "historical"
    run.mkdir()
    _ = (run / "checkpoint.pt").write_bytes(b"test-history-identity-only")
    metadata = run / "artifact.json"
    _ = metadata.write_text(
        json.dumps(
            {
                "checkpoint_sha256": sha256(run / "checkpoint.pt"),
                "manifests": [{"path": str(training), "sha256": sha256(training)}],
            }
        )
    )
    fresh = Image.new("RGB", (64, 64), "white")
    draw = ImageDraw.Draw(fresh)
    for row in range(8):
        for column in range(8):
            if (row + column) % 2:
                draw.rectangle((column * 8, row * 8, column * 8 + 7, row * 8 + 7), fill="black")
    output = io.BytesIO()
    fresh.save(output, format="PNG")
    previous = read_records(training)[0]
    paths = [
        "test/new-scene/tshirts/unseen.png",
        "test/location_2/tshirts/2023-04-24_11-57-31_rgb_zed.png",
        "test/new-scene/tshirts/leaked.png",
    ]
    coco = {
        "images": [{"id": i, "width": 64, "height": 64, "file_name": name} for i, name in enumerate(paths)],
        "categories": [
            {"id": 1, "name": "tshirt", "keypoints": ["shoulder_left", "shoulder_right", "armpit_left", "armpit_right"]}
        ],
        "annotations": [
            {
                "image_id": i,
                "category_id": 1,
                "bbox": [0, 0, 64, 64],
                "segmentation": [[0, 0, 64, 0, 64, 64, 0, 64]],
                "keypoints": [10, 10, 2, 50, 10, 2, 10, 30, 2, 50, 30, 2],
            }
            for i in range(3)
        ],
    }
    nested_bytes = io.BytesIO()
    with zipfile.ZipFile(nested_bytes, "w") as nested:
        nested.writestr("tshirts-test.json", json.dumps(coco))
        nested.writestr(paths[0], output.getvalue())
        nested.writestr(paths[1], output.getvalue())
        nested.writestr(paths[2], (training.parent / previous.file_name).read_bytes())
    archive = tmp_path / "fixture.zip"
    with zipfile.ZipFile(archive, "w") as outer:
        outer.writestr("tshirts.zip", nested_bytes.getvalue())
    registry = read_registry(REGISTRY_ROOT / "DATASET_MANIFEST.json")
    registry = registry.model_copy(
        update={
            "datasets": [
                entry.model_copy(
                    update={"archive_md5": hashlib.md5(archive.read_bytes(), usedforsecurity=False).hexdigest()}
                )
                if entry.id == "artf-1.0.1"
                else entry
                for entry in registry.datasets
            ]
        }
    )
    config = publisher_test.TestPreparation(
        archive=archive, output=tmp_path / "test-only", history=[HistoryPin(artifact=metadata, sha256=sha256(metadata))]
    )
    return config, registry


def test_unseen_publisher_photos_load_for_evaluation_but_can_never_load_for_training(tmp_path: Path) -> None:
    # Given publisher-style test bytes plus an old development path and a trained image.
    config, registry = _source_fixture(tmp_path)
    # When preparing and opening the test-only adapter.
    manifest = publisher_test.prepare_publisher_test(config, registry)
    dataset = publisher_test.PublisherTestDataset(manifest, registry)
    # Then only the unseen photo is available, and the normal training loader rejects the same manifest.
    assert len(dataset) == 1
    assert len(dataset.samples[0][1].keypoints) == 4
    assert dataset[0].pixels.shape == (3, 128, 128)
    with pytest.raises(PipelineError, match="Unknown or duplicate dataset"):
        _ = ApprovedDataset([manifest], registry, "train")


def test_test_only_pixel_tampering_is_rejected(tmp_path: Path) -> None:
    # Given a successfully prepared evaluation corpus.
    config, registry = _source_fixture(tmp_path)
    manifest = publisher_test.prepare_publisher_test(config, registry)
    record = read_records(manifest)[0]
    _ = (manifest.parent / record.file_name).write_bytes(b"replaced")
    # When opening evaluation, then the image identity mismatch blocks scoring.
    with pytest.raises(PipelineError, match="mismatch"):
        _ = publisher_test.PublisherTestDataset(manifest, registry)
