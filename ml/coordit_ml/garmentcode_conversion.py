"""Convert reviewed garment geometries into body-free, calibrated seam training renders."""

import hashlib
import math
from pathlib import Path

import numpy as np
from pydantic import Field, RootModel

from coordit_ml.garmentcode_download import SampleReceipt
from coordit_ml.garmentcode_landmarks import Specification, extract_seams
from coordit_ml.garmentcode_mesh import FloatVector, read_mesh
from coordit_ml.mesh_projection import PhysicalSurface, PinholeCamera, project, render_mesh, visible_on_surface
from coordit_ml.provenance import approved_entry, audit_records, perceptual_hash, sha256, write_records
from coordit_ml.schema import Acquisition, BoundaryModel, Landmark, PipelineError, Record, Registry, dimension_landmarks


class GarmentSelection(BoundaryModel):
    """Review coarse garment classes explicitly; mixed dresses/jumpsuits cannot become shirts/pants."""

    source: Path
    output: Path
    categories: dict[str, str]
    views_degrees: list[float]
    official_split: Path
    official_split_sha256: str


class PublisherSplits(BoundaryModel):
    """The two fitted bodies for one design inherit the same publisher partition."""

    train: list[str] = Field(alias="training")
    validation: list[str]
    test: list[str]


def render_garmentcode(config: GarmentSelection, registry: Registry) -> Path:
    """New data identity with source hashes, world/camera cm, physical seams and visibility."""
    entry = approved_entry(registry, "garmentcodedata-v2")
    receipt = SampleReceipt.model_validate_json((config.source / "source-receipt.json").read_bytes())
    if sha256(config.official_split) != config.official_split_sha256:
        raise PipelineError("GarmentCode official partition pin changed")
    partitions = PublisherSplits.model_validate_json(config.official_split.read_bytes())
    training_designs = {Path(path).name for path in partitions.train}
    evaluation_designs = {Path(path).name for path in partitions.validation + partitions.test}
    if not set(config.categories) <= training_designs or set(config.categories) & evaluation_designs:
        raise PipelineError("Pilot only accepts official training designs; evaluation designs stay held out")
    for member in receipt.files:
        if sha256(config.source / member.path) != member.sha256:
            raise PipelineError("GarmentCode source member hash changed")
    if not config.categories or not config.views_degrees or not set(config.categories) <= set(receipt.garments):
        raise PipelineError("Empty or unknown GarmentCode selection")
    config.output.mkdir(parents=True, exist_ok=False)
    (config.output / "images").mkdir()
    records: list[Record] = []
    extraction_log: list[str] = []
    for name, category in sorted(config.categories.items()):
        if category not in entry.categories:
            raise PipelineError("Garment category outside reviewed source scope")
        folder = config.source / name
        spec = Specification.model_validate_json((folder / f"{name}_specification.json").read_bytes())
        if spec.properties.units_in_meter <= 0:
            raise PipelineError("Unknown mesh units")
        mesh = read_mesh(folder / f"{name}_sim.ply")
        seams = extract_seams(folder, mesh)
        extraction_log.append(seams.model_dump_json())
        vertices = mesh.vertices * (100 / spec.properties.units_in_meter)
        lower, upper = vertices.min(axis=0), vertices.max(axis=0)
        center = (lower + upper) / 2
        distance = float(np.linalg.norm(upper - lower)) * 2.5
        allowed = {point for pair in dimension_landmarks(category).values() for point in pair}
        for view in config.views_degrees:
            angle = math.radians(view)
            cosine, sine = math.cos(angle), math.sin(angle)
            rotation = ((cosine, 0.0, -sine), (0.0, -1.0, 0.0), (-sine, 0.0, -cosine))
            translation: FloatVector = np.array(-np.array(rotation) @ center + (0, 0, distance), dtype=np.float64)
            camera = PinholeCamera(
                width=256,
                height=256,
                intrinsics=((500.0, 0.0, 128.0), (0.0, 500.0, 128.0), (0.0, 0.0, 1.0)),
                rotation=rotation,
                translation_cm=RootModel[tuple[float, float, float]].model_validate(translation.tolist()).root,
            )
            by_name = {point.landmark_type: point for point in seams.points}
            # Coordit front-view labels use image sides; preserve original physical-side IDs in evidence.
            swap_sides = any(
                project(np.array([by_name[left].xyz_cm, by_name[right].xyz_cm]), camera)[0, 0]
                > project(np.array([by_name[left].xyz_cm, by_name[right].xyz_cm]), camera)[1, 0]
                for left, right in (("shoulder_left", "shoulder_right"), ("waist_left", "waist_right"))
                if left in by_name and right in by_name
            )
            projected_seams = [
                point.model_copy(
                    update={
                        "landmark_type": point.landmark_type.removesuffix("_left") + "_right"
                        if point.landmark_type.endswith("_left")
                        else point.landmark_type.removesuffix("_right") + "_left"
                        if point.landmark_type.endswith("_right")
                        else point.landmark_type
                    }
                )
                if swap_sides
                else point
                for point in seams.points
            ]
            rendered = render_mesh(vertices, mesh.faces, camera)
            bbox = rendered.mask.getbbox()
            if bbox is None:
                raise PipelineError("Empty garment render")
            points: list[Landmark] = []
            for seam in projected_seams:
                pixel = (
                    RootModel[list[tuple[float, float, float]]]
                    .model_validate(project(np.array([seam.xyz_cm]), camera).tolist())
                    .root[0]
                )
                if seam.landmark_type in allowed and 0 <= pixel[0] < 256 and 0 <= pixel[1] < 256:
                    points.append(
                        Landmark(
                            landmark_type=seam.landmark_type,
                            x=float(pixel[0] / 256),
                            y=float(pixel[1] / 256),
                            visibility=2
                            if visible_on_surface(seam.xyz_cm, PhysicalSurface(vertices, mesh.faces), camera)
                            else 1,
                            source=f"garmentcodedata_v2_uv_panel_junction:vertex_{seam.canonical_vertex_id}",
                        )
                    )
            image_id = hashlib.sha256(f"gcd-v2-body-free-v1:{name}:{view}".encode()).hexdigest()
            image = config.output / f"images/{image_id}.png"
            mask = config.output / f"images/{image_id}-mask.png"
            rendered.rgb.save(image)
            rendered.mask.save(mask)
            records.append(
                Record(
                    image_id=image_id,
                    garment_id=f"garmentcodedata-v2:{name}",
                    category=category,
                    source_dataset=entry.id,
                    original_license=entry.data_license,
                    license_status="approved",
                    source_url=entry.original_url,
                    source_path=f"garments_5000_0/default_body/{name}",
                    source_group="garmentcodedata-v2-pilot-training-only",
                    split="train",
                    file_name=str(image.relative_to(config.output)),
                    sha256=sha256(image),
                    original_sha256=sha256(folder / f"{name}_sim.ply"),
                    perceptual_hash=perceptual_hash(image),
                    width=256,
                    height=256,
                    bbox=[bbox[0], bbox[1], bbox[2] - bbox[0], bbox[3] - bbox[1]],
                    segmentation=[],
                    keypoints=points,
                    mask_file_name=str(mask.relative_to(config.output)),
                    mask_sha256=sha256(mask),
                    measurement_ground_truth={},
                    acquisition_metadata=Acquisition(
                        synthetic=True,
                        camera_intrinsics=[list(row) for row in camera.intrinsics],
                        camera_rotation=[list(row) for row in camera.rotation],
                        camera_translation_cm=list(camera.translation_cm),
                        keypoints_3d_cm={point.landmark_type: list(point.xyz_cm) for point in projected_seams},
                        background="procedural_plain",
                        occlusion="garment_self_occlusion_zbuffer",
                        wrinkles="source_simulation",
                        difficulty="draped_not_flat_lay",
                        source_category=category,
                        label_provenance="UV_panel_topology_not_contour; coarse_category_review",
                    ),
                )
            )
    target = config.output / "records.jsonl"
    write_records(target, records)
    _ = audit_records(target, registry)
    _ = (config.output / "extraction.jsonl").write_text("\n".join(extraction_log) + "\n")
    return target
