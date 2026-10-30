"""Approved downloads and aRTF nested COCO archive conversion."""

import hashlib
import io
import logging
import socket
import zipfile
from pathlib import Path
from typing import ClassVar

import httpx2
from PIL import Image
from pydantic import BaseModel, ConfigDict

from coordit_ml.provenance import approved_entry, perceptual_hash, sha256, write_records
from coordit_ml.schema import Acquisition, Landmark, PipelineError, Record, Registry


class CocoImage(BaseModel):
    """Original COCO image dimensions and path."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True)
    id: int
    width: int
    height: int
    file_name: str


class CocoCategory(BaseModel):
    """Source landmark names, never assumed to be Coordit seam names."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True)
    id: int
    name: str
    keypoints: list[str] = []


class CocoAnnotation(BaseModel):
    """Original polygon and keypoint labels."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True, allow_inf_nan=False)
    image_id: int
    category_id: int
    bbox: list[float]
    segmentation: list[list[float]]
    keypoints: list[float] = []


class Coco(BaseModel):
    """Publisher COCO envelope."""

    model_config: ClassVar[ConfigDict] = ConfigDict(extra="ignore", frozen=True)
    images: list[CocoImage]
    categories: list[CocoCategory]
    annotations: list[CocoAnnotation]


def download_artf(destination: Path, registry: Registry) -> Path:
    """Download the pinned publisher archive with MD5 and SHA-256 evidence."""
    entry = approved_entry(registry, "artf-1.0.1")
    if not entry.download_url or not entry.download_url.startswith("https://zenodo.org/"):
        raise PipelineError("Unapproved download host")
    destination.mkdir(parents=True, exist_ok=True)
    target = destination / "aRTFClothes-resized-paper-splits.zip"
    if target.exists():
        raise PipelineError("Archive already exists; verify or use a fresh destination")
    limits = httpx2.Limits(max_connections=200, max_keepalive_connections=40, keepalive_expiry=30)
    transport = httpx2.HTTPTransport(
        http2=True, retries=3, limits=limits, socket_options=[(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)]
    )

    def log_response(response: httpx2.Response) -> None:
        logging.getLogger(__name__).info(
            "dataset_download status=%s host=%s", response.status_code, response.request.url.host
        )

    with (
        httpx2.Client(
            transport=transport,
            timeout=httpx2.Timeout(connect=5, read=30, write=10, pool=10),
            follow_redirects=True,
            event_hooks={"response": [log_response]},
        ) as client,
        client.stream("GET", entry.download_url) as response,
        target.with_suffix(".partial").open("xb") as output,
    ):
        _ = response.raise_for_status()
        for chunk in response.iter_bytes():
            _ = output.write(chunk)
    partial = target.with_suffix(".partial")
    digest = hashlib.md5(partial.read_bytes(), usedforsecurity=False).hexdigest()
    if digest != entry.archive_md5:
        raise PipelineError("Publisher archive checksum mismatch; quarantined .partial file")
    _ = partial.rename(target)
    _ = target.with_suffix(".sha256").write_text(sha256(target) + "\n")
    return target


def convert_artf(archive: Path, destination: Path, registry: Registry) -> Path:
    """Read only publisher train/val pools; all publisher test garments/scenes stay excluded."""
    entry = approved_entry(registry, "artf-1.0.1")
    if hashlib.md5(archive.read_bytes(), usedforsecurity=False).hexdigest() != entry.archive_md5:
        raise PipelineError("Archive does not match reviewed publisher version")
    destination.mkdir(parents=True, exist_ok=False)
    image_directory = destination / "images"
    image_directory.mkdir()
    records: list[Record] = []
    seen: set[str] = set()
    with zipfile.ZipFile(archive) as outer:
        for nested_name in sorted(outer.namelist()):
            if not nested_name.endswith(".zip"):
                continue
            with zipfile.ZipFile(io.BytesIO(outer.read(nested_name))) as nested:
                for annotation_path in sorted(nested.namelist()):
                    if not annotation_path.endswith(("-train.json", "-val.json")):
                        continue
                    coco = Coco.model_validate_json(nested.read(annotation_path))
                    categories = {c.id: c for c in coco.categories}
                    annotations = {a.image_id: a for a in coco.annotations}
                    for image in coco.images:
                        if not image.file_name.startswith("train/"):
                            raise PipelineError("Unexpected publisher training layout")
                        annotation = annotations.get(image.id)
                        if annotation is None:
                            continue
                        category = categories[annotation.category_id]
                        content = nested.read(str(Path(annotation_path).parent / image.file_name))
                        digest = hashlib.sha256(content).hexdigest()
                        if digest in seen:
                            continue
                        seen.add(digest)
                        output = image_directory / f"{digest}.png"
                        _ = output.write_bytes(content)
                        with Image.open(output) as decoded:
                            if decoded.size != (image.width, image.height):
                                raise PipelineError("COCO/image dimensions disagree")
                        landmarks: list[Landmark] = []
                        for index, name in enumerate(category.keypoints):
                            x, y, visibility = annotation.keypoints[index * 3 : index * 3 + 3]
                            if visibility in (0, 1, 2) and 0 <= x <= image.width and 0 <= y <= image.height:
                                landmarks.append(
                                    Landmark(
                                        landmark_type="artf:" + name,
                                        x=x / image.width,
                                        y=y / image.height,
                                        visibility=2 if visibility == 2 else (1 if visibility == 1 else 0),
                                        source="publisher_coco",
                                    )
                                )
                        label = {"towel": "aux_towel", "boxershorts": "aux_boxershorts"}.get(
                            category.name, category.name
                        )
                        records.append(
                            Record(
                                image_id=digest,
                                garment_id="artf-unknown-training-pool",
                                category=label,
                                source_dataset=entry.id,
                                original_license=entry.data_license,
                                license_status="approved",
                                source_url=entry.original_url,
                                source_path=image.file_name,
                                source_group="artf-publisher-training-garments-and-scenes",
                                split="train",
                                file_name=str(output.relative_to(destination)),
                                sha256=digest,
                                perceptual_hash=perceptual_hash(output),
                                width=image.width,
                                height=image.height,
                                bbox=[
                                    min(v for p in annotation.segmentation for v in p[::2]),
                                    min(v for p in annotation.segmentation for v in p[1::2]),
                                    max(v for p in annotation.segmentation for v in p[::2])
                                    - min(v for p in annotation.segmentation for v in p[::2]),
                                    max(v for p in annotation.segmentation for v in p[1::2])
                                    - min(v for p in annotation.segmentation for v in p[1::2]),
                                ],
                                source_bbox=annotation.bbox,
                                segmentation=annotation.segmentation,
                                keypoints=[],
                                source_keypoints=landmarks,
                                acquisition_metadata=Acquisition(synthetic=False),
                            )
                        )
    manifest = destination / "records.jsonl"
    write_records(manifest, records)
    return manifest
