"""Private local training proposals and blind held-out annotation tasks; no automatic truth promotion."""

import os
import re
from pathlib import Path
from typing import Literal

import torch
from pydantic import Field

from coordit_ml.aihub import QuarantinedPair
from coordit_ml.aihub_conversion import LABELS, AIHubConversion, normalize_pair_record
from coordit_ml.history import HistoryPin, load_history
from coordit_ml.network import ApprovedDataset
from coordit_ml.provenance import approved_entry, sha256
from coordit_ml.schema import LANDMARKS, BoundaryModel, Landmark, Record, Registry
from coordit_ml.seam_reviews import ReviewedPoint, SeamReview
from coordit_ml.training import load_model
from coordit_ml.via_annotation import PointShape, ViaImage, ViaRegion, build_offline_via


class QueueConfig(BoundaryModel):
    """Existing source authorization stays local; sample photos must clear the complete known history."""

    train_manifest: Path
    sample_root: Path
    sample_audit: Path
    output: Path
    model: Path
    history: list[HistoryPin]
    train_images_per_category: int = Field(default=8, ge=1, le=100)


class AnnotationTask(BoundaryModel):
    """Immutable purpose/source identities are kept outside editable VIA project fields."""

    record: Record
    purpose: Literal["training_review", "blind_holdout_candidate"]
    proposed_points: list[Landmark]
    protocol: Literal["coordit-upper-seam-v1", "coordit-upper-seam-v2"] = "coordit-upper-seam-v1"
    view: Literal["front", "back", "unknown"] = "unknown"


def source_view(record: Record) -> Literal["front", "back", "unknown"]:
    """Read publisher front/back identity; never infer anatomy from a neural prediction."""
    found = re.search(r"_(front|back)_", Path(record.source_path).name)
    return "front" if found and found[1] == "front" else ("back" if found else "unknown")


def prepare_aihub_review_queue(config: QueueConfig, registry: Registry) -> Path:
    """Prepare visible seam suggestions for training photos and blank tasks for unseen samples."""
    torch.set_num_threads(2)
    entry = approved_entry(registry, "aihub-71501")
    history = load_history(config.history)
    dataset = ApprovedDataset([config.train_manifest], registry, "train")
    model = load_model(config.model)
    dataset.image_size = model.input_size
    config.output.mkdir(parents=True, exist_ok=False)
    (config.output / "images").mkdir()
    tasks: list[AnnotationTask] = []
    counts: dict[str, int] = {}
    selected_garments: set[str] = set()
    permitted = {"shoulder_left", "shoulder_right", "armpit_left", "armpit_right"}
    with torch.inference_mode():
        for index, (root, record) in enumerate(dataset.samples):
            if (
                counts.get(record.category, 0) >= config.train_images_per_category
                or record.garment_id in selected_garments
            ):
                continue
            selected_garments.add(record.garment_id)
            counts[record.category] = counts.get(record.category, 0) + 1
            prediction = model.forward(dataset[index].pixels.unsqueeze(0))
            points = [
                Landmark(
                    landmark_type=name,
                    x=float(prediction.points[0, pos, 0]),
                    y=float(prediction.points[0, pos, 1]),
                    visibility=2,
                    confidence=float(prediction.visibility[0, pos].sigmoid()),
                    source="unverified_cross_category_local_model_proposal",
                )
                for pos, name in enumerate(LANDMARKS)
                if name in permitted
            ]
            os.link(root / record.file_name, config.output / "images" / Path(record.file_name).name)
            tasks.append(AnnotationTask(record=record, purpose="training_review", proposed_points=points,
                                        protocol="coordit-upper-seam-v2", view=source_view(record)))
    normal = AIHubConversion(source=config.sample_root, output=config.output)
    for line in config.sample_audit.read_text().splitlines():
        pair = QuarantinedPair.model_validate_json(line)
        if LABELS.get(pair.source_category) not in entry.categories:
            continue
        record = normalize_pair_record(pair, normal, entry.data_license)
        if history.overlaps(record):
            continue
        record = record.model_copy(
            update={
                "source_dataset": "aihub71501-evaluation-only-v1",
                "split": "test",
                "source_group": "aihub71501-unseen-sample-candidate",
            }
        )
        tasks.append(AnnotationTask(record=record, purpose="blind_holdout_candidate", proposed_points=[],
                                    protocol="coordit-upper-seam-v2", view=source_view(record)))
    index_path = config.output / "annotation-tasks.jsonl"
    _ = index_path.write_text("".join(task.model_dump_json() + "\n" for task in tasks))
    drafts = [
        SeamReview(
            image_id=task.record.image_id,
            image_sha256=task.record.sha256,
            coordinate_system="upright_rgb_normalized_top_left",
            points=[
                ReviewedPoint(
                    landmark=point,
                    review_status="proposal",
                    reviewer="",
                    protocol=task.protocol,
                    evidence="unverified model suggestion; not centimeter ground truth",
                )
                for point in task.proposed_points
            ],
        )
        for task in tasks
        if task.proposed_points
    ]
    _ = (config.output / "draft-seams.jsonl").write_text("".join(d.model_dump_json() + "\n" for d in drafts))
    for purpose in ("training_review", "blind_holdout_candidate"):
        images: dict[str, ViaImage] = {}
        for task in tasks:
            if task.purpose != purpose:
                continue
            r = task.record
            filename = Path(r.file_name).name
            size = (config.output / "images" / filename).stat().st_size
            images[filename + str(size)] = ViaImage(
                filename=filename,
                size=size,
                regions=[
                    ViaRegion(
                        shape_attributes=PointShape(cx=point.x * r.width, cy=point.y * r.height),
                        region_attributes={
                            "landmark_type": point.landmark_type,
                            "visibility": "2",
                            "review_status": "proposal",
                        },
                    )
                    for point in task.proposed_points
                ],
                file_attributes={
                    "coordit_image_id": r.image_id,
                    "image_sha256": r.sha256,
                    "category": r.category,
                    "purpose": purpose,
                    "reviewer": "",
                    "review_complete": "no",
                    "protocol": task.protocol,
                    "view": task.view,
                    "evidence": "",
                },
            )
        if images:
            _ = build_offline_via(images, config.output / f"{purpose}.html")
    _ = (config.output / "tasks.sha256").write_text(sha256(index_path) + "\n")
    return index_path
