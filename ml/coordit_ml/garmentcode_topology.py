"""Recover panel membership from UV-separated mesh islands without moving source vertices."""

from collections import defaultdict
from dataclasses import dataclass

from pydantic import RootModel

from coordit_ml.garmentcode_mesh import GarmentMesh
from coordit_ml.schema import PipelineError


@dataclass(frozen=True, slots=True)
class PanelTopology:
    """Canonical vertices can belong to multiple sewn panels at a seam junction."""

    panels: list[set[str]]
    boundary_vertices: set[int]


def recover_panels(mesh: GarmentMesh, segmentation: list[set[str]]) -> PanelTopology:
    """Each raw UV island must resolve to exactly one publisher-named panel."""
    parents = list(range(len(mesh.vertices)))

    def find(vertex: int) -> int:
        while parents[vertex] != vertex:
            parents[vertex] = parents[parents[vertex]]
            vertex = parents[vertex]
        return vertex

    faces = RootModel[list[tuple[int, int, int]]].model_validate(mesh.faces.tolist()).root
    canonical_ids = RootModel[list[int]].model_validate(mesh.canonical_ids.tolist()).root
    for triangle in faces:
        first = find(triangle[0])
        for raw in triangle[1:]:
            other = find(raw)
            parents[other] = first
    names: dict[int, set[str]] = defaultdict(set)
    for raw, canonical in enumerate(canonical_ids):
        names[find(raw)].update(name for name in segmentation[canonical] if not name.startswith("stitch_"))
    if any(len(group) != 1 for group in names.values()):
        raise PipelineError("UV island panel identity is missing or ambiguous")
    panels: list[set[str]] = [set() for _ in segmentation]
    for raw, canonical in enumerate(canonical_ids):
        panels[canonical].update(names[find(raw)])
    edges: dict[tuple[int, int], int] = defaultdict(int)
    for triangle in faces:
        a, b, c = (canonical_ids[value] for value in triangle)
        for first, second in ((a, b), (b, c), (c, a)):
            edge = (min(first, second), max(first, second))
            edges[edge] += 1
    boundary = {vertex for edge, count in edges.items() if count == 1 for vertex in edge}
    return PanelTopology(panels, boundary)
