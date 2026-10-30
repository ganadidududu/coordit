"""Review coarse source types visually without inventing segmentation or seam labels."""

import hashlib
import io
from collections import defaultdict
from pathlib import Path

import polars as pl
from PIL import Image, ImageDraw, ImageOps
from pydantic import TypeAdapter

from coordit_ml.schema import BoundaryModel, PipelineError
from coordit_ml.secondhand_conversion import SourceGarment
from coordit_ml.source_downloads import PinnedFile


class ReviewCandidate(BoundaryModel):
    """A contact-sheet cell is pinned to original photo bytes and source type."""

    index: int
    source_path: str
    original_sha256: str
    source_type: str
    preview: str


def prepare_review(source: Path, output: Path) -> Path:
    """Prepare deterministic, diverse-date examples only from publisher train, never its held-out test."""
    pins = TypeAdapter(list[PinnedFile]).validate_json((source / "DOWNLOAD_PINS.json").read_bytes())
    groups: dict[str, list[SourceGarment]] = defaultdict(list)
    for pin in sorted(pins, key=lambda item: item.path):
        if not Path(pin.path).name.startswith("train-"):
            continue
        rows = (
            pl.scan_parquet(source / pin.path)
            .select("image", "type")
            .filter(pl.col("type").is_in(["Sweater", "Outerwear", "Winter Jacket"]))
            .collect()
        )
        for raw in rows.iter_rows(named=True):
            item = SourceGarment.model_validate(raw)
            groups[item.type].append(item)
    if not groups:
        raise PipelineError("No fine-category review candidates")
    output.mkdir(parents=True, exist_ok=False)
    (output / "previews").mkdir()
    candidates: list[ReviewCandidate] = []
    for source_type, items in sorted(groups.items()):
        ordered = sorted(items, key=lambda item: hashlib.sha256(item.image.path.encode()).hexdigest())
        for item in ordered[:144]:
            index = len(candidates)
            with Image.open(io.BytesIO(item.image.bytes)) as original:
                image = ImageOps.exif_transpose(original).convert("RGB")
                image.thumbnail((480, 480))
                preview = f"previews/{index:04}.jpg"
                image.save(output / preview, quality=95)
            candidates.append(
                ReviewCandidate(
                    index=index,
                    source_path=item.image.path,
                    original_sha256=hashlib.sha256(item.image.bytes).hexdigest(),
                    source_type=source_type,
                    preview=preview,
                )
            )
    for offset in range(0, len(candidates), 48):
        sheet = Image.new("RGB", (1152, 2048), "white")
        draw = ImageDraw.Draw(sheet)
        for position, item in enumerate(candidates[offset : offset + 48]):
            x, y = (position % 6) * 192, (position // 6) * 256
            with Image.open(output / item.preview) as original:
                image = ImageOps.contain(original, (188, 226))
                sheet.paste(image, (x + (192 - image.width) // 2, y + 24))
            draw.text((x + 3, y + 3), f"{item.index:04} {item.source_type}", fill="black", font_size=13)
        sheet.save(output / f"sheet-{offset // 48:02}.jpg", quality=94)
    path = output / "candidates.json"
    _ = path.write_text(TypeAdapter(list[ReviewCandidate]).dump_json(candidates, indent=2).decode() + "\n")
    return path
