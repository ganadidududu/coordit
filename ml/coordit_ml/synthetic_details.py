"""Asset-free fabric, seams and garment construction details for procedural scenes."""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

from coordit_ml.schema import PipelineError, Record


def add_details(root: Path, record: Record) -> None:
    """Draw category-appropriate construction, never text labels or class watermarks."""
    rng = random.Random(record.image_id)
    metadata = record.acquisition_metadata
    rotation, translation, intrinsic = (
        metadata.camera_rotation,
        metadata.camera_translation_cm,
        metadata.camera_intrinsics,
    )
    if rotation is None or translation is None or intrinsic is None:
        raise PipelineError("Procedural camera metadata is required")
    world = metadata.keypoints_3d_cm

    def project(x: float, y: float) -> tuple[float, float]:
        z = rotation[2][0] * x + rotation[2][1] * y + translation[2]
        return (
            (rotation[0][0] * x + rotation[0][1] * y + translation[0]) * intrinsic[0][0] / z + intrinsic[0][2],
            (rotation[1][0] * x + rotation[1][1] * y + translation[1]) * intrinsic[1][1] / z + intrinsic[1][2],
        )

    with Image.open(root / record.file_name) as original:
        image = original.convert("RGB")
    mask_file = record.mask_file_name
    if mask_file is None:
        raise PipelineError("Procedural mask is missing")
    with Image.open(root / mask_file) as source_mask:
        mask = source_mask.convert("L")
    fabric = image.copy()
    draw = ImageDraw.Draw(fabric)
    dark = tuple(rng.randint(25, 85) for _ in range(3))
    light = tuple(rng.randint(160, 235) for _ in range(3))
    if "shoulder_left" in world:
        half = abs(world["shoulder_right"][0])
        top, bottom = world["length_start"][1], world["hem_center"][1]
        for side in (-1, 1):
            draw.line(
                [project(side * half * 0.4, top), project(side * half, top + 7), project(side * half, top + 24)],
                fill=dark,
                width=1,
            )
        if record.category == "knit":
            for offset in range(-80, 81, 3):
                curve = [project(offset + math.sin(y / 2), y) for y in range(int(top), int(bottom) + 1, 2)]
                draw.line(curve, fill=light, width=1)
            for y in range(int(top), int(bottom), 3):
                draw.line([project(-80, y), project(80, y + 1)], fill=dark, width=1)
        if record.category in ("shirt", "jacket", "coat"):
            depth = 24 if record.category == "coat" else 12
            for side in (-1, 1):
                draw.polygon(
                    [project(0, top + 7), project(side * half * 0.4, top), project(side * half * 0.3, top + depth)],
                    fill=light,
                    outline=dark,
                )
            if record.category == "jacket":
                draw.line([project(0, top + 8), project(0, bottom)], fill=dark, width=3)
                for y in range(int(top + 10), int(bottom), 3):
                    draw.line([project(-2, y), project(2, y)], fill=light, width=1)
            if record.category == "coat":
                for side in (-1, 1):
                    for y in range(int(top + 28), int(bottom - 10), 12):
                        x, py = project(side * 5, y)
                        draw.ellipse((x - 2, py - 2, x + 2, py + 2), fill=dark)
        if record.category == "hoodie":
            for side in (-1, 1):
                draw.line([project(side * 7, top + 4), project(side * 7, top + 22)], fill=light, width=2)
            draw.polygon(
                [
                    project(-half * 0.7, bottom - 20),
                    project(half * 0.7, bottom - 20),
                    project(half * 0.55, bottom - 5),
                    project(-half * 0.55, bottom - 5),
                ],
                outline=dark,
            )
        if record.category in ("sweatshirt", "knit", "hoodie"):
            for y in range(int(bottom - 5), int(bottom), 2):
                draw.line([project(-half, y), project(half, y)], fill=light, width=1)
        if record.category == "tshirt":
            draw.line(
                [project(-half * 0.35, top + 3), project(0, top + 8), project(half * 0.35, top + 3)],
                fill=light,
                width=2,
            )
    else:
        half = abs(world["waist_right"][0])
        top = world["waist_center"][1]
        bottom = world.get("side_hem", world.get("skirt_hem", [0, top + 80, 0]))[1]
        if record.category == "skirt":
            for offset in range(-int(half), int(half) + 1, 5):
                draw.line([project(offset, top + 3), project(offset * 1.4, bottom)], fill=light, width=2)
        else:
            for side in (-1, 1):
                if record.category == "jeans":
                    draw.line(
                        [
                            project(side * half, top + 4),
                            project(side * half * 0.65, top + 12),
                            project(side * half * 0.25, top + 15),
                        ],
                        fill=light,
                        width=2,
                    )
                    draw.line([project(side * half, top + 18), project(side * half, bottom)], fill=light, width=2)
                    draw.line(
                        [project(side * (half - 2), top + 18), project(side * (half - 2), bottom)], fill=dark, width=1
                    )
                else:
                    draw.line(
                        [project(side * half * 0.55, top + 20), project(side * half * 0.55, bottom - 3)],
                        fill=dark,
                        width=1,
                    )
            draw.line([project(0, top + 2), project(0, top + 16)], fill=dark, width=1)
    image.paste(fabric, mask=mask)
    image.save(root / record.file_name)
