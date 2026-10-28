"""Extract only unambiguous semantic seam intersections, not contour extrema."""

from pathlib import Path
from typing import ClassVar, Literal

import yaml
from pydantic import ConfigDict, RootModel

from coordit_ml.garmentcode_mesh import GarmentMesh, read_mesh
from coordit_ml.garmentcode_topology import recover_panels
from coordit_ml.schema import BoundaryModel, PipelineError


class EdgeReference(BoundaryModel):
    """Exact sewing pattern edge identity."""

    panel: str
    edge: int


class Stitch(
    RootModel[tuple[EdgeReference, EdgeReference] | tuple[EdgeReference, EdgeReference, Literal["right_wrong"]]]
):
    """Publisher stitch with optional sewing direction flag."""


class Pattern(BoundaryModel):
    """Only stitching topology is consumed from the upstream pattern document."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True)
    stitches: list[Stitch]


class Properties(BoundaryModel):
    """Scale is explicit; body dimensions are never garment centimeter truth."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True)
    units_in_meter: float


class Specification(BoundaryModel):
    """Original source schema parsed without executing upstream generator code."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True)
    pattern: Pattern
    properties: Properties


class SeamPoint(BoundaryModel):
    """A physical vertex with source topology evidence, not a guessed coordinate."""

    landmark_type: str
    canonical_vertex_id: int
    xyz_cm: tuple[float, float, float]
    evidence: str


class SeamExtraction(BoundaryModel):
    """Unknown landmarks remain absent; a failure cannot silently manufacture points."""

    points: list[SeamPoint]
    omitted: list[str]


def extract_seams(folder: Path, mesh: GarmentMesh) -> SeamExtraction:
    """Identify armhole/torso seam junctions and the four-panel pants crotch junction."""
    name = folder.name
    specification = Specification.model_validate_json((folder / f"{name}_specification.json").read_bytes())
    if specification.properties.units_in_meter <= 0:
        raise PipelineError("Missing physical source scale")
    scale = 100 / specification.properties.units_in_meter
    labels = (
        RootModel[dict[str, list[int]]]
        .model_validate(yaml.safe_load((folder / f"{name}_vertex_labels.yaml").read_text()))
        .root
    )
    segmentation = [set(line.split(",")) for line in (folder / f"{name}_sim_segmentation.txt").read_text().splitlines()]
    box = read_mesh(folder / f"{name}_boxmesh.ply")
    if len(segmentation) != len(mesh.canonical_vertices) or len(segmentation) != len(box.canonical_vertices):
        raise PipelineError("UV duplicate map does not match publisher segmentation IDs")
    if any(vertex < 0 or vertex >= len(segmentation) for vertices in labels.values() for vertex in vertices):
        raise PipelineError("Semantic vertex label outside mesh")
    topology = recover_panels(box, segmentation)
    source_xyz = RootModel[list[tuple[float, float, float]]].model_validate(mesh.canonical_vertices.tolist()).root
    box_xyz = RootModel[list[tuple[float, float, float]]].model_validate(box.canonical_vertices.tolist()).root
    points: list[SeamPoint] = []
    omitted: list[str] = []
    for side in ("left", "right"):
        required = {f"{side}_ftorso", f"{side}_btorso", f"{side}_sleeve_f", f"{side}_sleeve_b"}
        junctions = sorted(vertex for vertex, panels in enumerate(topology.panels) if required <= panels)
        if len(junctions) != 2:
            omitted.extend(
                (
                    f"shoulder_{side}:ambiguous_or_missing_armhole_junction",
                    f"armpit_{side}:ambiguous_or_missing_armhole_junction",
                )
            )
            continue
        junctions.sort(key=lambda vertex: -box_xyz[vertex][1])
        if box_xyz[junctions[0]][1] - box_xyz[junctions[1]][1] < 3 / scale:
            omitted.append(f"{side}:shoulder_and_armpit_not_separable")
            continue
        for landmark, vertex in zip((f"shoulder_{side}", f"armpit_{side}"), junctions, strict=True):
            xyz = source_xyz[vertex]
            points.append(
                SeamPoint(
                    landmark_type=landmark,
                    canonical_vertex_id=vertex,
                    xyz_cm=(xyz[0] * scale, xyz[1] * scale, xyz[2] * scale),
                    evidence=f"UV islands meet: {sorted(required)}; two junctions, y-up box ordering",
                )
            )
    crotch = [
        vertex
        for vertex, panels in enumerate(topology.panels)
        if {"pant_f_l", "pant_f_r", "pant_b_l", "pant_b_r"} <= panels
    ]
    if len(crotch) == 1:
        vertex = crotch[0]
        xyz = source_xyz[vertex]
        points.append(
            SeamPoint(
                landmark_type="crotch",
                canonical_vertex_id=vertex,
                xyz_cm=(xyz[0] * scale, xyz[1] * scale, xyz[2] * scale),
                evidence="unique four-panel pants crotch junction recovered from UV islands",
            )
        )
    else:
        omitted.append("crotch:ambiguous_or_missing_center_seam_junction")
    for side, suffix in (("left", "l"), ("right", "r")):
        waist = [
            vertex
            for vertex in topology.boundary_vertices
            if {f"pant_f_{suffix}", f"pant_b_{suffix}"} <= topology.panels[vertex]
        ]
        if len(waist) == 1:
            vertex = waist[0]
            xyz = source_xyz[vertex]
            points.append(
                SeamPoint(
                    landmark_type=f"waist_{side}",
                    canonical_vertex_id=vertex,
                    xyz_cm=(xyz[0] * scale, xyz[1] * scale, xyz[2] * scale),
                    evidence="unique pants front/back side-seam junction on an open garment boundary",
                )
            )
        else:
            omitted.append(f"waist_{side}:ambiguous_open_boundary")
    return SeamExtraction(points=points, omitted=omitted)
