"""Pinned BSD-2-Clause offline annotation tool with analytics removed and network disabled."""

import json
from pathlib import Path
from typing import Literal

from coordit_ml.schema import BoundaryModel, PipelineError
from coordit_ml.source_downloads import PinnedFile, create_client, download_pinned


class PointShape(BoundaryModel):
    """VIA native pixel points, never normalized coordinates disguised as pixels."""

    name: Literal["point"] = "point"
    cx: float
    cy: float


class ViaRegion(BoundaryModel):
    """Drafts require a separate explicit human verification action."""

    shape_attributes: PointShape
    region_attributes: dict[str, str]


class ViaImage(BoundaryModel):
    """Photo identity stays in immutable bundle metadata as well as editable project attributes."""

    filename: str
    size: int
    regions: list[ViaRegion]
    file_attributes: dict[str, str]


def build_offline_via(images: dict[str, ViaImage], output: Path) -> Path:
    """Use upstream controls unchanged; prevent HTTP, telemetry, frames and image uploads with CSP."""
    pin = PinnedFile(
        path="via-2.0.12.html",
        size=424268,
        sha256="a225d22d89fd5b901769670fb94d4e117543d748c1c2dd8cf2fa7a4777f08322",
        url="https://www.robots.ox.ac.uk/~vgg/software/via/via.html",
    )
    with create_client() as client:
        source = download_pinned(client, pin, output.parent / "upstream-via-2.0.12.source.txt").read_text()
    start = source.index('<script type="text/javascript">')
    end = source.index("</script>", start) + len("</script>")
    if "GoogleAnalyticsObject" not in source[start:end]:
        raise PipelineError("Reviewed upstream telemetry block changed")
    source = source[:start] + source[end:]
    policy = (
        "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; "
        "img-src file: data: blob:; connect-src 'none'; object-src 'none'; frame-src 'none'; "
        "base-uri 'none'; form-action 'none'"
    )
    source = source.replace("<head>", '<head><meta http-equiv="Content-Security-Policy" content="' + policy + '">', 1)
    options = {
        "shoulder_left": "왼쪽 어깨 봉제선",
        "shoulder_right": "오른쪽 어깨 봉제선",
        "armpit_left": "왼쪽 겨드랑이 봉제 교차점",
        "armpit_right": "오른쪽 겨드랑이 봉제 교차점",
    }
    project = {
        "_via_settings": {
            "project": {"name": output.stem},
            "core": {"default_filepath": "images/"},
            "ui": {"image": {"region_label": "landmark_type"}},
        },
        "_via_img_metadata": {key: image.model_dump() for key, image in images.items()},
        "_via_image_id_list": list(images),
        "_via_attributes": {
            "region": {
                "landmark_type": {"type": "dropdown", "options": options},
                "visibility": {"type": "dropdown", "options": {"2": "보임", "1": "가림", "0": "확인 불가"}},
                "review_status": {
                    "type": "dropdown",
                    "options": {"proposal": "미검수", "verified": "검수 완료", "rejected": "제외"},
                },
            },
            "file": {
                name: {"type": "text"}
                for name in (
                    "coordit_image_id",
                    "image_sha256",
                    "category",
                    "purpose",
                    "reviewer",
                    "review_complete",
                    "protocol",
                    "evidence",
                )
            },
        },
    }
    encoded = json.dumps(project, ensure_ascii=True).replace("<", "\\u003c").replace(">", "\\u003e")
    bootstrap = '<script>window.addEventListener("load", function(){project_open_parse_json_file(JSON.stringify('
    bootstrap += encoded + '));select_region_shape("point");});</script>'
    if "function select_region_shape(" not in source:
        raise PipelineError("Reviewed upstream point control changed")
    source = source.replace("</body>", bootstrap + "</body>", 1)
    _ = output.write_text(source)
    return output
