"""Original-author Second-Hand Fashion front images, without brand/privacy photographs."""

import json
import logging
from pathlib import Path
from typing import ClassVar, Final

from pydantic import BaseModel, ConfigDict, TypeAdapter

from coordit_ml.provenance import REGISTRY_ROOT, approved_entry, sha256
from coordit_ml.schema import PipelineError, Registry
from coordit_ml.source_downloads import PinnedFile, create_client, download_pinned

DATASET: Final = "fnauman/fashion-second-hand-front-only-rgb"
REVISION: Final = "b2559ac0157ea9b6913a65062877f487952e690b"
DATASET_ID: Final = "secondhand-fashion-v3-front"


class LFSFile(BaseModel):
    """Hub LFS content digest is SHA-256 of the actual binary."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    oid: str
    size: int


class HubFile(BaseModel):
    """Parse public repository metadata separately from the dataset's usage license."""

    model_config: ClassVar[ConfigDict] = ConfigDict(frozen=True, extra="ignore")
    path: str
    size: int
    lfs: LFSFile


def verify_source_pins(pins: list[PinnedFile]) -> None:
    """Approval covers exactly the reviewed author's revision, not a caller-supplied mirror."""
    reviewed = TypeAdapter(list[PinnedFile]).validate_json(
        (REGISTRY_ROOT / "source-pins/secondhand-v3-front.json").read_bytes()
    )
    if len(pins) != len(reviewed) or {pin.path: pin for pin in pins} != {pin.path: pin for pin in reviewed}:
        raise PipelineError("Source files differ from the reviewed publisher revision")


def download_secondhand(destination: Path, registry: Registry) -> Path:
    """Verify all official front-only shards, including upstream test for leakage grouping, not auto-training."""
    _ = approved_entry(registry, DATASET_ID)
    destination.mkdir(parents=True, exist_ok=True)
    with create_client() as client:
        response = client.get(
            f"https://huggingface.co/api/datasets/{DATASET}/tree/{REVISION}/data",
            params={"recursive": "true", "expand": "true"},
        )
        _ = response.raise_for_status()
        files = TypeAdapter(list[HubFile]).validate_json(response.content)
        if len(files) != 14 or any(not item.path.endswith(".parquet") or item.size != item.lfs.size for item in files):
            raise PipelineError("Unexpected official dataset layout")
        pins = [
            PinnedFile(
                path=item.path,
                size=item.size,
                sha256=item.lfs.oid,
                url=f"https://huggingface.co/datasets/{DATASET}/resolve/{REVISION}/{item.path}",
            )
            for item in files
        ]
        verify_source_pins(pins)
        pin_path = destination / "DOWNLOAD_PINS.json"
        serialized = json.dumps([pin.model_dump() for pin in pins], indent=2) + "\n"
        if pin_path.exists() and pin_path.read_text() != serialized:
            raise PipelineError("Source manifest changed at a pinned revision")
        _ = pin_path.write_text(serialized)
        for index, pin in enumerate(pins):
            target = destination / pin.path
            _ = download_pinned(client, pin, target)
            logging.getLogger(__name__).info(
                "verified %s/%s %s sha256=%s", index + 1, len(pins), pin.path, sha256(target)
            )
    return pin_path
