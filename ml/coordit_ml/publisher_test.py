"""aRTF publisher test is evaluation-only; the ordinary training loader must reject this identity."""

import hashlib
import io
import zipfile
from collections import Counter
from pathlib import Path
from typing import Literal, final

from PIL import Image

from coordit_ml.acquisition import Coco
from coordit_ml.artf_landmarks import mapped_landmarks
from coordit_ml.history import HistoryPin, load_history
from coordit_ml.network import ApprovedDataset
from coordit_ml.provenance import (
    REGISTRY_ROOT,
    Denylist,
    approved_entry,
    perceptual_hash,
    read_records,
    sha256,
    write_records,
)
from coordit_ml.schema import Acquisition, BoundaryModel, Landmark, PipelineError, Record, Registry


class TestPreparation(BoundaryModel):
    """Original publisher bytes and all prior model runs are pinned before test preparation."""

    archive: Path
    output: Path
    history: list[HistoryPin]


class TestReceipt(BoundaryModel):
    """Unseen training photos are distinguished from a newly independent measurement study."""

    identity: Literal["artf-publisher-test-evaluation-only-v1"] = "artf-publisher-test-evaluation-only-v1"
    manifest_sha256: str
    publisher_archive_sha256: str
    history: list[HistoryPin]
    images: int
    categories: dict[str, int]
    exclusions: dict[str, int]
    independent_study: Literal[False] = False
    limitation: str = (
        "Publisher test family was used for earlier 16-photo heuristic development; not a new independent study"
    )


def prepare_publisher_test(config: TestPreparation, registry: Registry) -> Path:
    """Extract only test labels; exclude old 16 paths, duplicate bytes and any recorded training image."""
    entry = approved_entry(registry, "artf-1.0.1")
    if hashlib.md5(config.archive.read_bytes(), usedforsecurity=False).hexdigest() != entry.archive_md5:
        raise PipelineError("Publisher archive differs from reviewed version")
    history = load_history(config.history)
    deny = Denylist.model_validate_json((REGISTRY_ROOT / "EVALUATION_DENYLIST.json").read_bytes())
    denied_paths, denied_hashes = {f.path for f in deny.files}, {f.sha256 for f in deny.files}
    config.output.mkdir(parents=True, exist_ok=False)
    (config.output / "images").mkdir()
    records: list[Record] = []
    seen: set[str] = set()
    exclusions: Counter[str] = Counter()
    with zipfile.ZipFile(config.archive) as outer:
        for name in sorted(outer.namelist()):
            if not name.endswith(".zip"):
                continue
            with zipfile.ZipFile(io.BytesIO(outer.read(name))) as nested:
                for label_path in sorted(nested.namelist()):
                    if not label_path.endswith("-test.json"):
                        continue
                    coco = Coco.model_validate_json(nested.read(label_path))
                    categories = {c.id: c for c in coco.categories}
                    images = {image.id: image for image in coco.images}
                    for annotation in coco.annotations:
                        category = categories[annotation.category_id]
                        if category.name not in {"tshirt", "shorts"}:
                            continue
                        image = images[annotation.image_id]
                        if not image.file_name.startswith("test/"):
                            raise PipelineError("Unexpected source test partition")
                        if image.file_name in denied_paths:
                            exclusions["old_16_development_paths"] += 1
                            continue
                        content = nested.read(str(Path(label_path).parent / image.file_name))
                        digest = hashlib.sha256(content).hexdigest()
                        if digest in seen or digest in denied_hashes:
                            exclusions["duplicate_or_old_development_hash"] += 1
                            continue
                        seen.add(digest)
                        target = config.output / f"images/{digest}.png"
                        _ = target.write_bytes(content)
                        points = [
                            Landmark(
                                landmark_type="artf:" + name,
                                x=x / image.width,
                                y=y / image.height,
                                visibility=2 if v == 2 else (1 if v == 1 else 0),
                                source="publisher_coco",
                            )
                            for index, name in enumerate(category.keypoints)
                            for x, y, v in [annotation.keypoints[index * 3 : index * 3 + 3]]
                            if v in (0, 1, 2) and 0 <= x <= image.width and 0 <= y <= image.height
                        ]
                        xs = [x for polygon in annotation.segmentation for x in polygon[::2]]
                        ys = [y for polygon in annotation.segmentation for y in polygon[1::2]]
                        record = Record(
                            image_id=f"artf-test-only:{digest}",
                            garment_id="artf-publisher-test-unresolved-garment-ids",
                            category=category.name,
                            source_dataset="artf-publisher-test-evaluation-only-v1",
                            original_license=entry.data_license,
                            license_status="approved",
                            source_url=entry.original_url,
                            source_path=image.file_name,
                            source_group="artf-publisher-test-evaluation-only",
                            split="test",
                            file_name=str(target.relative_to(config.output)),
                            sha256=digest,
                            perceptual_hash=perceptual_hash(target),
                            width=image.width,
                            height=image.height,
                            bbox=[min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)],
                            segmentation=annotation.segmentation,
                            keypoints=[],
                            source_keypoints=points,
                            acquisition_metadata=Acquisition(
                                synthetic=False, label_provenance="publisher_manual_anatomical_test_only"
                            ),
                        )
                        overlap = history.overlaps(record)
                        if overlap:
                            exclusions[overlap] += 1
                            continue
                        records.append(record.model_copy(update={"keypoints": mapped_landmarks(record)}))
    manifest = config.output / "records.jsonl"
    write_records(manifest, records)
    receipt = TestReceipt(
        manifest_sha256=sha256(manifest),
        publisher_archive_sha256=sha256(config.archive),
        history=config.history,
        images=len(records),
        categories=dict(Counter(r.category for r in records)),
        exclusions=dict(exclusions),
    )
    _ = (config.output / "test-receipt.json").write_text(receipt.model_dump_json(indent=2) + "\n")
    return manifest


@final
class PublisherTestDataset(ApprovedDataset):
    """Only this evaluation adapter accepts the source identity; training remains fail-closed."""

    def __init__(self, manifest: Path, registry: Registry) -> None:
        """Verify source pins and every test image before tensor decoding."""
        super().__init__([], registry, "test")
        entry = approved_entry(registry, "artf-1.0.1")
        receipt = TestReceipt.model_validate_json(manifest.with_name("test-receipt.json").read_bytes())
        if sha256(manifest) != receipt.manifest_sha256:
            raise PipelineError("Test-only manifest changed")
        history = load_history(receipt.history)
        records = read_records(manifest)
        if len(records) != receipt.images:
            raise PipelineError("Test-only image count changed")
        root = manifest.parent.resolve()
        for record in records:
            image = (root / record.file_name).resolve()
            if (
                record.source_dataset != receipt.identity
                or record.split != "test"
                or not record.source_path.startswith("test/")
                or record.original_license != entry.data_license
                or not image.is_relative_to(root)
                or sha256(image) != record.sha256
                or perceptual_hash(image) != record.perceptual_hash
                or history.overlaps(record)
            ):
                raise PipelineError("Test-only corpus identity, pixel or history mismatch")
            with Image.open(image) as decoded:
                if decoded.size != (record.width, record.height):
                    raise PipelineError("Test-only image dimensions changed")
        self.samples = [(root, record) for record in records]
        self.image_size = 128
