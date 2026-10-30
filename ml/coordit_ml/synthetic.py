"""Asset-free planar garment scenes with exact camera/metric labels (not cloth physics)."""

import hashlib
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

from coordit_ml.provenance import group_splits, perceptual_hash, sha256, write_records
from coordit_ml.schema import CATEGORIES, Acquisition, Landmark, PipelineError, Record, dimension_landmarks


def generate(destination: Path, per_category: int, seed: int = 17) -> Path:
    """Generate independently seeded garments, then split connected source/hash groups."""
    if per_category < 1:
        raise PipelineError("per_category must be positive")
    destination.mkdir(parents=True, exist_ok=False)
    (destination / "images").mkdir()
    (destination / "masks").mkdir()
    records: list[Record] = []
    for category in CATEGORIES:
        for index in range(per_category):
            identity = f"coordit-procedural-v1:{seed}:{category}:{index}"
            record = render_scene(destination, identity, category)
            records.append(record)
    manifest = destination / "records.jsonl"
    write_records(manifest, group_splits(records))
    return manifest


def render_scene(root: Path, identity: str, category: str) -> Record:
    """Project authored garment polygons/seams through a pinhole camera in centimeter units."""
    rng = random.Random(int(hashlib.sha256(identity.encode()).hexdigest()[:16], 16))
    width, length = rng.uniform(42, 62), rng.uniform(55, 85)
    is_lower = category in ("pants", "jeans", "shorts", "skirt")
    if is_lower:
        width, length = rng.uniform(32, 48), rng.uniform(70, 108)
    if category == "shorts":
        length = rng.uniform(35, 54)
    if category == "coat":
        length = rng.uniform(90, 120)
    top, bottom = -length / 2, length / 2
    half = width / 2
    world: dict[str, tuple[float, float]]
    if not is_lower:
        cuff_y = top + (rng.uniform(14, 23) if category == "tshirt" else rng.uniform(40, 58))
        cuff_x = half + rng.uniform(16, 30)
        world = {
            "shoulder_left": (-half, top + 7),
            "shoulder_right": (half, top + 7),
            "armpit_left": (-half, top + 24),
            "armpit_right": (half, top + 24),
            "length_start": (-width / 5, top),
            "hem_center": (0, bottom),
            "sleeve_start": (half, top + 7),
            "sleeve_end": (cuff_x, cuff_y),
        }
        polygon = [
            (-half, top + 7),
            (-width / 5, top),
            (-width / 7, top + 4),
            (width / 7, top + 4),
            (width / 5, top),
            (half, top + 7),
            (cuff_x + 4, cuff_y - 4),
            (cuff_x - 4, cuff_y + 5),
            (half, top + 24),
            (half, bottom),
            (-half, bottom),
            (-half, top + 24),
            (-cuff_x + 4, cuff_y + 5),
            (-cuff_x - 4, cuff_y - 4),
        ]
    else:
        hip = half + rng.uniform(3, 9)
        world = {
            "waist_left": (-half, top),
            "waist_right": (half, top),
            "hip_left": (-hip, top + 18),
            "hip_right": (hip, top + 18),
            "waist_center": (0, top),
        }
        if category == "skirt":
            hem = hip + rng.uniform(0, 22)
            world["skirt_hem"] = (0, bottom)
            polygon = [(-half, top), (half, top), (hip, top + 18), (hem, bottom), (-hem, bottom), (-hip, top + 18)]
        else:
            crotch = top + min(length * 0.52, rng.uniform(23, 32))
            world.update(crotch=(0, crotch), side_waist=(half, top), side_hem=(hip, bottom))
            gap = rng.uniform(3, 7)
            polygon = [
                (-half, top),
                (half, top),
                (hip, top + 18),
                (hip, bottom),
                (gap, bottom),
                (0, crotch),
                (-gap, bottom),
                (-hip, bottom),
                (-hip, top + 18),
            ]
    roll, tilt = rng.uniform(-0.7, 0.7), rng.uniform(-0.22, 0.22)
    cr, sr, ct, st = math.cos(roll), math.sin(roll), math.cos(tilt), math.sin(tilt)
    rotation = [[cr, -sr * ct, sr * st], [sr, cr * ct, -cr * st], [0, st, ct]]
    distance, focal = rng.uniform(150, 190), 240.0
    shift_x, shift_y = rng.uniform(-10, 10), rng.uniform(-10, 10)

    def project(point: tuple[float, float]) -> tuple[float, float]:
        x, y = point
        z = rotation[2][1] * y + distance
        return (
            (rotation[0][0] * x + rotation[0][1] * y + shift_x) * focal / z + 128,
            (rotation[1][0] * x + rotation[1][1] * y + shift_y) * focal / z + 128,
        )

    projected = [project(p) for p in polygon]
    polygons = [projected]
    if category == "hoodie":
        polygons.append(
            [project(p) for p in [(-13, top + 4), (-15, top - 12), (0, top - 20), (15, top - 12), (13, top + 4)]]
        )
    image = Image.new("RGB", (256, 256), tuple(rng.randrange(80, 245) for _ in range(3)))
    mask = Image.new("L", image.size)
    for outline in polygons:
        ImageDraw.Draw(mask).polygon(outline, fill=255)
    # Shadows and wrinkle shading do not claim physical cloth deformation.
    shadow = ImageChops.offset(mask.filter(ImageFilter.GaussianBlur(4)), 3, 4)
    image.paste(Image.new("RGB", image.size, (50, 50, 50)), mask=shadow)
    fabric = Image.new("RGB", image.size, tuple(rng.randrange(20, 220) for _ in range(3)))
    detail = ImageDraw.Draw(fabric)
    for _ in range(rng.randint(8, 30)):
        color = tuple(rng.randrange(30, 230) for _ in range(3))
        x, y = rng.randrange(256), rng.randrange(256)
        detail.line(
            [(x, y), (x + rng.randrange(-50, 50), y + rng.randrange(10, 80))], fill=color, width=rng.randint(1, 3)
        )
    if category in ("shirt", "jacket", "coat", "hoodie"):
        detail.line([project((0, top + 8)), project((0, bottom))], fill=(35, 35, 35), width=2)
        for offset in range(15, int(length), 10):
            x, y = project((0, top + offset))
            detail.ellipse((x - 1, y - 1, x + 1, y + 1), fill=(225, 225, 225))
    image.paste(fabric, mask=mask)
    occluder: tuple[int, int, int, int] | None = None
    if rng.random() < 0.2:
        x, y = rng.randint(60, 160), rng.randint(60, 180)
        occluder = (x, y, x + 35, y + 25)
        ImageDraw.Draw(image).rectangle(occluder, fill=(105, 105, 100))
        ImageDraw.Draw(mask).rectangle(occluder, fill=0)
    landmarks: list[Landmark] = []
    for name, point in world.items():
        x, y = project(point)
        visible = not occluder or not (occluder[0] <= x <= occluder[2] and occluder[1] <= y <= occluder[3])
        landmarks.append(
            Landmark(landmark_type=name, x=x / 256, y=y / 256, visibility=2 if visible else 1, source="procedural_seam")
        )
    name = hashlib.sha256(identity.encode()).hexdigest()
    image_path, mask_path = root / "images" / f"{name}.png", root / "masks" / f"{name}.png"
    image.save(image_path)
    mask.save(mask_path)
    truth = {key: math.dist(world[a], world[b]) for key, (a, b) in dimension_landmarks(category).items()}
    xs, ys = [p[0] for outline in polygons for p in outline], [p[1] for outline in polygons for p in outline]
    return Record(
        image_id=name,
        garment_id=identity,
        category=category,
        source_dataset="coordit-procedural-v1",
        original_license="Coordit-owned",
        license_status="approved",
        source_url="repo:ml/coordit_ml/synthetic.py",
        source_path=identity,
        source_group=identity,
        split="train",
        file_name=str(image_path.relative_to(root)),
        sha256=sha256(image_path),
        perceptual_hash=perceptual_hash(image_path),
        width=256,
        height=256,
        bbox=[min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)],
        segmentation=[[v for p in outline for v in p] for outline in polygons],
        keypoints=landmarks,
        mask_file_name=str(mask_path.relative_to(root)),
        mask_sha256=sha256(mask_path),
        measurement_ground_truth=truth,
        acquisition_metadata=Acquisition(
            synthetic=True,
            camera_intrinsics=[[focal, 0, 128], [0, focal, 128], [0, 0, 1]],
            camera_rotation=rotation,
            camera_translation_cm=[shift_x, shift_y, distance],
            keypoints_3d_cm={key: [x, y, 0] for key, (x, y) in world.items()},
            background="procedural_color",
            occlusion="partial" if occluder else "none",
            wrinkles="shading_only",
            difficulty="planar_synthetic",
        ),
    )
