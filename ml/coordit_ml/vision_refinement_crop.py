"""Label-free self-review crops and exact crop-to-original coordinate transforms."""

import base64
import io
import json
import math
from dataclasses import dataclass
from typing import Literal, assert_never

from PIL import Image
from pydantic import Field

from coordit_ml.external_pilot import TARGETS
from coordit_ml.schema import BoundaryModel, PipelineError
from coordit_ml.vision_api_inputs import PublicPhoto
from coordit_ml.vision_api_types import ApiAnnotation, ApiAttempt, BenchmarkConfig


class CropBox(BoundaryModel):
    """Integer bounds in the original image; no publisher bbox or landmark can enter this boundary."""

    left: int = Field(ge=0)
    top: int = Field(ge=0)
    right: int = Field(gt=0)
    bottom: int = Field(gt=0)
    image_width: int = Field(gt=0)
    image_height: int = Field(gt=0)

    def restore(self, annotation: ApiAnnotation, output_frame: Literal["crop", "original"] = "crop") -> ApiAnnotation:
        """Apply the exact affine inverse, preserving abstentions and uncertainty without inferred pixels."""
        if not (self.left < self.right <= self.image_width and self.top < self.bottom <= self.image_height):
            raise PipelineError("Invalid refinement crop bounds")
        match output_frame:
            case "original":
                return annotation
            case "crop":
                pass
            case unreachable:
                assert_never(unreachable)
        points = [
            p
            if p.x is None or p.y is None
            else p.model_copy(
                update={
                    "x": (self.left + p.x * (self.right - self.left)) / self.image_width,
                    "y": (self.top + p.y * (self.bottom - self.top)) / self.image_height,
                }
            )
            for p in annotation.points
        ]
        return annotation.model_copy(update={"points": points})


def proposal_crop(photo: PublicPhoto, draft: ApiAnnotation | None) -> CropBox:
    """Use only the model's own coordinates; missing drafts fall back to the original frame, never GT."""
    width, height = photo.case.width, photo.case.height
    points = [(p.x * width, p.y * height) for p in draft.points if p.x is not None and p.y is not None] if draft else []
    if len(points) < 2:
        return CropBox(left=0, top=0, right=width, bottom=height, image_width=width, image_height=height)
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    margin = max(24, 0.2 * max(max(xs) - min(xs), max(ys) - min(ys)))
    left, right = max(0, math.floor(min(xs) - margin)), min(width, math.ceil(max(xs) + margin))
    top, bottom = max(0, math.floor(min(ys) - margin)), min(height, math.ceil(max(ys) + margin))
    return CropBox(left=left, top=top, right=right, bottom=bottom, image_width=width, image_height=height)


@dataclass(frozen=True, slots=True)
class ReviewInput:
    """Public pixels, the model's own draft and a predeclared output-coordinate contract."""

    photo: PublicPhoto
    parent: ApiAttempt
    output_frame: Literal["crop", "original"] = "crop"


def refinement_payload(source: ReviewInput, config: BenchmarkConfig) -> tuple[bytes, CropBox]:
    """Original context plus enlarged crop; target names and draft come from public pixels and own inference only."""
    photo, parent = source.photo, source.parent
    crop = proposal_crop(photo, parent.annotation)
    with Image.open(io.BytesIO(photo.pixels)) as original:
        pixels = original.convert("RGB").crop((crop.left, crop.top, crop.right, crop.bottom))
        pixels.info.clear()
        pixels = pixels.resize((pixels.width * 3, pixels.height * 3), Image.Resampling.LANCZOS)
        stream = io.BytesIO()
        pixels.save(stream, format="PNG")
    draft = parent.annotation.model_dump_json() if parent.annotation else "No valid draft available."
    match source.output_frame:
        case "crop":
            frame_instructions = """\
OUTPUT FRAME OVERRIDE: returned x,y must be normalized to the SECOND image/crop, top-left origin.
The caller applies the exact affine inverse. Resolve whole-garment left/right using the FIRST image,
not crop corners. A target outside the crop must abstain, never clamp to its border."""
        case "original":
            frame_instructions = """OUTPUT FRAME: return x,y normalized to the FIRST original image, top-left origin.
The SECOND crop is for visual inspection only; never return crop-relative or resized-pixel coordinates.
Keep whole-garment side names from the FIRST image. Correct the original draft directly; no affine remapping."""
        case unreachable:
            assert_never(unreachable)
    instructions = (
        config.protocol.read_text()
        + f"""
Category: {photo.case.category}. Requested targets: {", ".join(TARGETS[photo.case.category])}.
The FIRST image is original context used to determine garment side. The SECOND image is its 3x enlarged crop.
Enlargement creates no source detail. Critically verify your own draft against the unmarked photograph.
Correct cuff/shoulder confusion, garment-side swaps and scale errors. Do not merely copy the draft or
mark an uncertain seam visible. If stitching/junction is not identifiable, retain uncertainty or abstain.
No reference annotation or correct coordinate is supplied.
{frame_instructions}
Crop rectangle in original pixels: {crop.model_dump_json()}.
Your previous unverified draft was normalized to the FIRST/original image: {draft}
"""
    )
    payload = {
        "model": parent.model_requested,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": instructions},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": "data:image/png;base64," + base64.b64encode(photo.pixels).decode(),
                            "detail": "high",
                        },
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": "data:image/png;base64," + base64.b64encode(stream.getvalue()).decode(),
                            "detail": "high",
                        },
                    },
                ],
            }
        ],
        "response_format": {
            "type": "json_schema",
            "json_schema": {"name": "garment_landmarks", "strict": True, "schema": ApiAnnotation.model_json_schema()},
        },
        "max_tokens": config.max_tokens,
        "stream": False,
        "reasoning": {"effort": "low", "exclude": True},
        "provider": {"allow_fallbacks": False, "require_parameters": True, "data_collection": "deny", "zdr": True},
        "usage": {"include": True},
    }
    return json.dumps(payload, separators=(",", ":"), allow_nan=False).encode(), crop
