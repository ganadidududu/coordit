"""Small, pinned sample from the publisher's public v2 archive; never fetch the full 368 GB."""

import tarfile
from pathlib import Path, PurePosixPath
from typing import Final

import httpx2

from coordit_ml.provenance import approved_entry, sha256
from coordit_ml.schema import BoundaryModel, PipelineError, Registry
from coordit_ml.source_downloads import PinnedFile, create_client, download_pinned

PUBLIC_SHARE: Final = "4UtC8smtLOGwKoZ"
SOURCE_URL: Final = (
    "https://libdrive.ethz.ch/public.php/webdav/GarmentCodeData_v2/garments_5000_0/default_body/data.tar.gz"
)
PREFIX_SIZE: Final = 33_554_432
PREFIX_SHA256: Final = "1bf2e45edfda77e3c8dda9d4851c0bd8c6030dd36671dff4df87fc4813921a58"
_SUFFIXES: Final = (
    "_specification.json",
    "_sim.ply",
    "_boxmesh.ply",
    "_sim_segmentation.txt",
    "_vertex_labels.yaml",
    "_design_params.yaml",
)


class SourceMember(BoundaryModel):
    """Original bytes from an identified publisher archive member."""

    path: str
    sha256: str
    size: int


class SampleReceipt(BoundaryModel):
    """A prefix is explicitly not a downloaded or verified full archive."""

    source_url: str = SOURCE_URL
    full_archive_downloaded: bool = False
    byte_range: str = "0-33554431"
    prefix_sha256: str = PREFIX_SHA256
    garments: list[str]
    files: list[SourceMember]


def download_garmentcode_metadata(output: Path) -> None:
    """Pin official design split and documentation alongside the bounded archive sample."""
    base_url = f"https://libdrive.ethz.ch/index.php/s/{PUBLIC_SHARE}/download?path=%2F&files="
    pins = [
        PinnedFile(
            path="official-split.json",
            size=6_074_953,
            sha256="4a8a591a1112bd635324bc04b19a7871ac7fa88d0426fa020076dbe4bc584b8f",
            url=base_url + "GarmentCodeData_v2_official_train_valid_test_data_split.json",
        ),
        PinnedFile(
            path="Dataset_documentation_v2.pdf",
            size=605_885,
            sha256="5d35bd7ebf8cf37ed3ced6493cb75aa839f106235e73b1a425951017b87cbe5d",
            url=f"https://libdrive.ethz.ch/index.php/s/{PUBLIC_SHARE}/download?path=%2F&files=Dataset_documentation_v2.pdf",
        ),
    ]
    with create_client() as client:
        for pin in pins:
            _ = download_pinned(client, pin, output / pin.path)


def download_sample_prefix(target: Path) -> Path:
    """Request exact reviewed bytes, reject ignored ranges and quarantine mismatched responses."""
    if target.exists():
        if target.stat().st_size != PREFIX_SIZE or sha256(target) != PREFIX_SHA256:
            raise PipelineError("Existing GarmentCode prefix differs from its reviewed pin")
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(".partial")
    with (
        create_client() as client,
        client.stream(
            "GET", SOURCE_URL, auth=httpx2.BasicAuth(PUBLIC_SHARE, ""), headers={"Range": "bytes=0-33554431"}
        ) as response,
        partial.open("xb") as output,
    ):
        _ = response.raise_for_status()
        if response.status_code != 206 or response.headers.get("content-range") != "bytes 0-33554431/5121727032":
            raise PipelineError("Publisher did not honor bounded GarmentCode sample range")
        written = 0
        for chunk in response.iter_bytes():
            written += len(chunk)
            if written > PREFIX_SIZE:
                raise PipelineError("GarmentCode sample exceeds its bounded download")
            _ = output.write(chunk)
    if partial.stat().st_size != PREFIX_SIZE or sha256(partial) != PREFIX_SHA256:
        raise PipelineError("GarmentCode sample checksum mismatch; partial quarantined")
    _ = partial.rename(target)
    return target


def prepare_garmentcode_sample(prefix: Path, output: Path, registry: Registry) -> Path:
    """Extract 15 complete garment geometries; exclude bodies, textures, pickle and publisher renders."""
    _ = approved_entry(registry, "garmentcodedata-v2")
    if prefix.stat().st_size != PREFIX_SIZE or sha256(prefix) != PREFIX_SHA256:
        raise PipelineError("Unreviewed GarmentCode prefix")
    output.mkdir(parents=True, exist_ok=False)
    garments: list[str] = []
    files: list[SourceMember] = []
    with tarfile.open(prefix, "r|gz") as archive:
        for member in archive:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts or member.issym() or member.islnk():
                raise PipelineError("Unsafe GarmentCode archive member")
            if member.isdir() and path.name.startswith("rand_"):
                if len(garments) == 15:
                    break
                garments.append(path.name)
            if member.isfile() and member.name.endswith(_SUFFIXES):
                if path.parts[0] not in garments or member.size > 40_000_000:
                    raise PipelineError("Unexpected sample member layout or size")
                source = archive.extractfile(member)
                if source is None:
                    raise PipelineError("Missing source member")
                target = output / str(path)
                target.parent.mkdir(exist_ok=True)
                with source, target.open("xb") as destination:
                    _ = destination.write(source.read())
                files.append(SourceMember(path=str(path), sha256=sha256(target), size=member.size))
    if len(garments) != 15 or any(sum(file.path.startswith(name + "/") for file in files) != 6 for name in garments):
        raise PipelineError("Incomplete GarmentCode sample; output remains quarantined")
    receipt = output / "source-receipt.json"
    _ = receipt.write_text(SampleReceipt(garments=garments, files=files).model_dump_json(indent=2) + "\n")
    return receipt
