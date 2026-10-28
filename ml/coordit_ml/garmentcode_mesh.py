"""Strict publisher PLY reader preserving stitch IDs across adjacent UV seam duplicates."""

from dataclasses import dataclass
from pathlib import Path

import numpy as np

from coordit_ml.schema import PipelineError

type FloatMatrix = np.ndarray[tuple[int, int], np.dtype[np.float64]]
type FloatVector = np.ndarray[tuple[int], np.dtype[np.float64]]
type IntMatrix = np.ndarray[tuple[int, int], np.dtype[np.int64]]
type IntVector = np.ndarray[tuple[int], np.dtype[np.int64]]


@dataclass(frozen=True, slots=True)
class GarmentMesh:
    """Raw render topology and canonical publisher vertex identities in source units."""

    vertices: FloatMatrix
    faces: IntMatrix
    canonical_ids: IntVector
    canonical_vertices: FloatMatrix


def read_mesh(path: Path) -> GarmentMesh:
    """Accept only the documented binary layout, never reorder or spatially merge vertices."""
    with path.open("rb") as stream:
        header: list[str] = []
        while len(header) < 30:
            line = stream.readline(256).decode("ascii").strip()
            header.append(line)
            if line == "end_header":
                break
        expected = [
            "ply",
            "format binary_little_endian 1.0",
            "comment https://github.com/mikedh/trimesh",
            "element vertex",
            "property float x",
            "property float y",
            "property float z",
            "property double s",
            "property double t",
            "element face",
            "property list uchar int vertex_indices",
            "end_header",
        ]
        if len(header) != len(expected) or any(
            actual != wanted
            for index, (actual, wanted) in enumerate(zip(header, expected, strict=True))
            if index not in (3, 9)
        ):
            raise PipelineError("Unsupported publisher PLY layout; explicit adapter review required")
        vertex_count, face_count = int(header[3].split()[-1]), int(header[9].split()[-1])
        if not 0 < vertex_count <= 1_000_000 or not 0 < face_count <= 1_000_000:
            raise PipelineError("Unbounded PLY geometry")
        raw = np.frombuffer(stream.read(vertex_count * 28), dtype=[("xyz", "<f4", 3), ("uv", "<f8", 2)])
        triangles = np.frombuffer(stream.read(), dtype=[("count", "u1"), ("indices", "<i4", 3)])
    counts: IntVector = np.array(triangles["count"], dtype=np.int64)
    valid_counts = np.array(counts == 3, dtype=bool)
    if len(raw) != vertex_count or len(triangles) != face_count or not valid_counts.all():
        raise PipelineError("Truncated or non-triangular PLY")
    vertices: FloatMatrix = np.array(raw["xyz"], dtype=np.float64)
    faces: IntMatrix = np.array(triangles["indices"], dtype=np.int64)
    if not np.isfinite(vertices).all() or faces.min() < 0 or faces.max() >= vertex_count:
        raise PipelineError("Invalid PLY coordinates or indices")
    changes = np.array(vertices[1:] != vertices[:-1], dtype=bool)
    starts = np.concatenate((np.array([True]), changes.any(axis=1)))
    ids = np.array(np.cumsum(starts) - 1, dtype=np.int64)
    return GarmentMesh(vertices, faces, ids, vertices[starts])
