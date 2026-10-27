"""Bounded, content-pinned public source downloads with resumable partial files."""

import logging
import shutil
import socket
from pathlib import Path, PurePosixPath
from typing import Annotated

import httpx2
from pydantic import Field, model_validator

from coordit_ml.provenance import sha256
from coordit_ml.schema import BoundaryModel, PipelineError


class PinnedFile(BoundaryModel):
    """One publisher-listed file at an immutable revision."""

    path: str
    size: Annotated[int, Field(gt=0)]
    sha256: Annotated[str, Field(pattern=r"^[0-9a-f]{64}$")]
    url: str

    @model_validator(mode="after")
    def contained_path(self) -> "PinnedFile":
        """Publisher-controlled paths must still remain inside the destination."""
        path = PurePosixPath(self.path)
        if path.is_absolute() or ".." in path.parts or "\\" in self.path:
            raise PipelineError("Unsafe publisher path")
        return self


def create_client() -> httpx2.Client:
    """Reuse a tuned public-only client; callers own its lifetime."""
    limits = httpx2.Limits(max_connections=200, max_keepalive_connections=40, keepalive_expiry=30)
    transport = httpx2.HTTPTransport(
        http2=True, retries=3, limits=limits, socket_options=[(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)]
    )

    def log_response(response: httpx2.Response) -> None:
        logging.getLogger(__name__).info(
            "public_source status=%s host=%s", response.status_code, response.request.url.host
        )

    return httpx2.Client(
        transport=transport,
        timeout=httpx2.Timeout(connect=5, read=30, write=10, pool=10),
        follow_redirects=True,
        event_hooks={"response": [log_response]},
    )


def download_pinned(client: httpx2.Client, spec: PinnedFile, target: Path) -> Path:
    """Resume exact bytes, reject range/size/hash mismatches and never replace a verified artifact."""
    if not spec.url.startswith("https://"):
        raise PipelineError("Public download requires HTTPS")
    if target.is_file():
        if target.stat().st_size != spec.size or sha256(target) != spec.sha256:
            raise PipelineError("Existing download differs from its publisher pin")
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(target.suffix + ".partial")
    offset = partial.stat().st_size if partial.is_file() else 0
    if offset > spec.size or shutil.disk_usage(target.parent).free < spec.size - offset + 1_000_000_000:
        raise PipelineError("Partial file too large or insufficient free storage")
    if offset < spec.size:
        headers = {"Range": f"bytes={offset}-"} if offset else {}
        with client.stream("GET", spec.url, headers=headers) as response:
            _ = response.raise_for_status()
            expected = f"bytes {offset}-{spec.size - 1}/{spec.size}"
            if offset and (response.status_code != 206 or response.headers.get("content-range") != expected):
                raise PipelineError("Server did not honor the exact resume range")
            with partial.open("ab" if partial.exists() else "xb") as stream:
                written = offset
                for chunk in response.iter_bytes():
                    written += len(chunk)
                    if written > spec.size:
                        raise PipelineError("Source exceeded pinned file size")
                    _ = stream.write(chunk)
    if partial.stat().st_size != spec.size or sha256(partial) != spec.sha256:
        raise PipelineError("Downloaded source checksum mismatch; partial quarantined")
    _ = partial.rename(target)
    return target
