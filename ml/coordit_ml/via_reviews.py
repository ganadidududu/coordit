"""Convert explicit local human point reviews; blind tasks cannot become training labels."""

from pathlib import Path
from typing import ClassVar

from pydantic import BaseModel, ConfigDict, Field

from coordit_ml.aihub_review_queue import AnnotationTask
from coordit_ml.provenance import sha256
from coordit_ml.schema import BoundaryModel, Landmark, PipelineError
from coordit_ml.seam_protocol import SideReference, validate_side_reference
from coordit_ml.seam_reviews import ReviewedPoint, SeamReview
from coordit_ml.via_annotation import ViaImage


class ViaExport(BaseModel):
    """VIA full-project exports contain unrelated UI settings which are not trusted."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True)
    images: dict[str, ViaImage] = Field(alias="_via_img_metadata")


class ViaImport(BoundaryModel):
    """Original queue SHA prevents relabeling an evaluated photograph as a training task."""

    tasks: Path
    tasks_sha256: str
    project: Path
    output: Path


class ReviewReceipt(BoundaryModel):
    """Verified photo counts stay distinct from mere model proposals and incomplete files."""

    tasks_sha256: str
    project_sha256: str
    verified_training_images: int
    verified_holdout_images: int
    incomplete_images: int
    original_photos_transmitted: bool = False


def completed_review(image: ViaImage, task: AnnotationTask) -> SeamReview:
    """Parse visible human points and their side-reference evidence after source identity was checked."""
    attributes, record = image.file_attributes, task.record
    reviewer, protocol, evidence = (attributes.get(key, "").strip() for key in ("reviewer", "protocol", "evidence"))
    if (
        not reviewer
        or protocol != "coordit-upper-seam-v2"
        or task.protocol != protocol
        or task.view == "unknown"
        or attributes.get("view") != task.view
        or not evidence
        or not image.regions
    ):
        raise PipelineError("Completed review requires reviewer, endpoint protocol and visual evidence")
    points: list[ReviewedPoint] = []
    anchors: dict[str, Landmark] = {}
    names: set[str] = set()
    for region in image.regions:
        meta = region.region_attributes
        name = meta.get("landmark_type", "")
        if (
            meta.get("review_status") != "verified"
            or meta.get("visibility") != "2"
            or name in names
            or name
            not in {
                "shoulder_left",
                "shoulder_right",
                "armpit_left",
                "armpit_right",
                "hem_reference_left",
                "hem_reference_right",
            }
        ):
            raise PipelineError("Unverified, hidden, duplicate or unsupported seam point")
        names.add(name)
        landmark = Landmark(
            landmark_type=name,
            x=region.shape_attributes.cx / record.width,
            y=region.shape_attributes.cy / record.height,
            visibility=2,
            source="local_human_seam_review",
            correction_status="user_corrected",
        )
        if name.startswith("hem_reference_"):
            anchors[name] = landmark
            continue
        points.append(
            ReviewedPoint(
                landmark=landmark,
                review_status="verified",
                reviewer=reviewer,
                protocol=protocol,
                evidence=evidence,
            )
        )
    if len(anchors) != 2 or not points:
        raise PipelineError("Verified v2 review requires two human hem anchors and actual seam points")
    reference = SideReference(
        left_hem=anchors["hem_reference_left"],
        right_hem=anchors["hem_reference_right"],
        view=task.view,
    )
    validate_side_reference(reference, record)
    return SeamReview(
        image_id=record.image_id,
        image_sha256=record.sha256,
        coordinate_system="upright_rgb_normalized_top_left",
        points=points,
        side_reference=reference,
    )


def import_via_reviews(config: ViaImport) -> Path:
    """Accept only explicit visible-point confirmations matched to original image identity."""
    if sha256(config.tasks) != config.tasks_sha256:
        raise PipelineError("Original annotation queue changed")
    tasks = {
        task.record.image_id: task
        for line in config.tasks.read_text().splitlines()
        for task in [AnnotationTask.model_validate_json(line)]
    }
    export = ViaExport.model_validate_json(config.project.read_bytes())
    by_purpose: dict[str, list[SeamReview]] = {"training_review": [], "blind_holdout_candidate": []}
    seen: set[str] = set()
    incomplete = 0
    for image in export.images.values():
        identity = image.file_attributes.get("coordit_image_id", "")
        if identity not in tasks or identity in seen:
            raise PipelineError("Unknown or duplicate source photo in VIA project")
        seen.add(identity)
        task = tasks[identity]
        record = task.record
        attributes = image.file_attributes
        root = config.tasks.parent.resolve()
        pixels = (root / record.file_name).resolve()
        if (
            attributes.get("image_sha256") != record.sha256
            or attributes.get("purpose") != task.purpose
            or Path(image.filename).name != Path(record.file_name).name
            or not pixels.is_relative_to(root)
            or sha256(pixels) != record.sha256
            or image.size != pixels.stat().st_size
        ):
            raise PipelineError("Review purpose or source image identity changed")
        if attributes.get("review_complete") != "yes":
            incomplete += 1
            continue
        by_purpose[task.purpose].append(completed_review(image, task))
    if not any(by_purpose.values()):
        raise PipelineError("No verified human annotations; proposals cannot be imported as ground truth")
    config.output.mkdir(parents=True, exist_ok=False)
    for purpose, reviews in by_purpose.items():
        if reviews:
            _ = (config.output / f"{purpose}.jsonl").write_text("".join(r.model_dump_json() + "\n" for r in reviews))
    receipt = ReviewReceipt(
        tasks_sha256=config.tasks_sha256,
        project_sha256=sha256(config.project),
        verified_training_images=len(by_purpose["training_review"]),
        verified_holdout_images=len(by_purpose["blind_holdout_candidate"]),
        incomplete_images=incomplete,
    )
    result = config.output / "review-receipt.json"
    _ = result.write_text(receipt.model_dump_json(indent=2) + "\n")
    return result
