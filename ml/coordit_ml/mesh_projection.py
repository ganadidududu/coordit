"""Deterministic body-free garment rendering with explicit pinhole camera and depth visibility."""

import math
from dataclasses import dataclass
from typing import Annotated

import numpy as np
from PIL import Image
from pydantic import Field, RootModel, model_validator

from coordit_ml.garmentcode_mesh import FloatMatrix, FloatVector, IntMatrix
from coordit_ml.schema import BoundaryModel, PipelineError


class PinholeCamera(BoundaryModel):
    """World cm to camera cm: Xc = R Xw + t; x-right, y-down, z-forward."""

    width: Annotated[int, Field(ge=32, le=2048)]
    height: Annotated[int, Field(ge=32, le=2048)]
    intrinsics: tuple[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float]]
    rotation: tuple[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float]]
    translation_cm: tuple[float, float, float]

    @model_validator(mode="after")
    def valid_camera(self) -> "PinholeCamera":
        """Reject mirrored/non-rigid poses and malformed camera matrices at the boundary."""
        rotation: FloatMatrix = np.array(self.rotation)
        k = self.intrinsics
        if (
            not np.allclose(rotation @ rotation.T, np.eye(3), atol=1e-6)
            or not np.isclose(np.linalg.det(rotation), 1, atol=1e-6)
            or k[0][0] <= 0
            or k[1][1] <= 0
            or k[2] != (0, 0, 1)
            or k[0][1] != 0
            or k[1][0] != 0
        ):
            raise PipelineError("Camera must have calibrated positive focal lengths and a rigid proper pose")
        return self


@dataclass(frozen=True, slots=True)
class RenderedMesh:
    """Pixels, true raster mask and depth share exactly the same camera coordinates."""

    rgb: Image.Image
    mask: Image.Image
    depth_cm: FloatMatrix


@dataclass(frozen=True, slots=True)
class PhysicalSurface:
    """World geometry in the same cm units as projected source landmarks."""

    vertices_cm: FloatMatrix
    faces: IntMatrix


def visible_on_surface(point_cm: tuple[float, float, float], surface: PhysicalSurface, camera: PinholeCamera) -> bool:
    """Exact point ray test avoids mistaking coarse boundary raster pixels for occlusion."""
    origin = -np.array(camera.rotation).T @ np.array(camera.translation_cm)
    direction = np.array(point_cm) - origin
    triangles = surface.vertices_cm[surface.faces]
    first, edge1, edge2 = triangles[:, 0], triangles[:, 1] - triangles[:, 0], triangles[:, 2] - triangles[:, 0]
    h = np.cross(direction, edge2)
    determinant: FloatVector = np.array(np.einsum("ij,ij->i", edge1, h), dtype=np.float64)
    inverse: FloatVector = np.array(
        np.divide(1.0, determinant, out=np.zeros_like(determinant), where=np.abs(determinant) > 1e-10), dtype=np.float64
    )
    offset = origin - first
    u: FloatVector = np.array(inverse * np.einsum("ij,ij->i", offset, h), dtype=np.float64)
    q = np.cross(offset, edge1)
    v: FloatVector = np.array(inverse * (q @ direction), dtype=np.float64)
    distance: FloatVector = np.array(inverse * np.einsum("ij,ij->i", edge2, q), dtype=np.float64)
    intersects = np.array((np.abs(determinant) > 1e-10) & (u >= -1e-7) & (v >= -1e-7) & (u + v <= 1 + 1e-7), dtype=bool)
    before_point = np.array(
        (distance > 0) & (distance < 1 - 0.05 / max(float(np.linalg.norm(direction)), 1e-9)), dtype=bool
    )
    return not bool(np.array(intersects & before_point, dtype=bool).any())


def project(points_cm: FloatMatrix, camera: PinholeCamera) -> FloatMatrix:
    """Return pixel x/y and positive camera depth; behind-camera geometry is rejected."""
    points: FloatMatrix = points_cm @ np.array(camera.rotation).T + np.array(camera.translation_cm)
    if not np.isfinite(points).all() or np.any(points[:, 2] <= 0):
        raise PipelineError("Projection contains geometry behind the camera or nonfinite coordinates")
    pixels = points @ np.array(camera.intrinsics).T
    return np.column_stack((pixels[:, :2] / pixels[:, 2:3], points[:, 2]))


def render_mesh(vertices_cm: FloatMatrix, faces: IntMatrix, camera: PinholeCamera) -> RenderedMesh:
    """Perspective-correct z-buffer with flat procedural fabric; no source bodies/textures are used."""
    projected = project(vertices_cm, camera)
    projected_xyz = RootModel[list[tuple[float, float, float]]].model_validate(projected.tolist()).root
    world_xyz = RootModel[list[tuple[float, float, float]]].model_validate(vertices_cm.tolist()).root
    triangles = RootModel[list[tuple[int, int, int]]].model_validate(faces.tolist()).root
    depth = np.full((camera.height, camera.width), np.inf)
    rgb = np.full((camera.height, camera.width, 3), 235, dtype=np.uint8)
    for triangle in triangles:
        a, b, c = (projected_xyz[index] for index in triangle)
        left = max(0, math.floor(min(a[0], b[0], c[0])))
        top = max(0, math.floor(min(a[1], b[1], c[1])))
        right = min(camera.width - 1, math.ceil(max(a[0], b[0], c[0])))
        bottom = min(camera.height - 1, math.ceil(max(a[1], b[1], c[1])))
        if left > right or top > bottom:
            continue
        denominator = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(denominator) < 1e-8:
            continue
        y: FloatMatrix = np.array(np.mgrid[top : bottom + 1, left : right + 1][0] + 0.5, dtype=np.float64)
        x: FloatMatrix = np.array(np.mgrid[top : bottom + 1, left : right + 1][1] + 0.5, dtype=np.float64)
        first: FloatMatrix = np.array(
            ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / denominator, dtype=np.float64
        )
        second: FloatMatrix = np.array(
            ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / denominator, dtype=np.float64
        )
        third: FloatMatrix = np.array(1 - first - second, dtype=np.float64)
        inside = np.array((first >= -1e-8) & (second >= -1e-8) & (third >= -1e-8), dtype=bool)
        inverse: FloatMatrix = np.array(first / a[2] + second / b[2] + third / c[2], dtype=np.float64)
        z: FloatMatrix = np.array(
            np.divide(1.0, inverse, out=np.full_like(inverse, np.inf), where=inverse > 0), dtype=np.float64
        )
        region = depth[top : bottom + 1, left : right + 1]
        update = np.array(inside & (z < region), dtype=bool)
        region[update] = z[update]
        origin, second_vertex, third_vertex = (world_xyz[index] for index in triangle)
        edge1 = tuple(second_vertex[axis] - origin[axis] for axis in range(3))
        edge2 = tuple(third_vertex[axis] - origin[axis] for axis in range(3))
        normal = (
            edge1[1] * edge2[2] - edge1[2] * edge2[1],
            edge1[2] * edge2[0] - edge1[0] * edge2[2],
            edge1[0] * edge2[1] - edge1[1] * edge2[0],
        )
        brightness = 0.45 + 0.55 * abs(normal[2]) / max(math.sqrt(sum(value**2 for value in normal)), 1e-9)
        rgb[top : bottom + 1, left : right + 1][update] = np.array([60, 115, 180]) * brightness
    return RenderedMesh(Image.fromarray(rgb), Image.fromarray((np.isfinite(depth) * 255).astype(np.uint8)), depth)
