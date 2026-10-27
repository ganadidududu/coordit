"""Development inference contract; uncalibrated RGB never returns centimeters."""

import base64
import io
from pathlib import Path
from typing import Literal

import torch
from PIL import Image, ImageOps

from coordit_ml.network import image_tensor
from coordit_ml.schema import CLASSES, LANDMARKS, BoundaryModel, Landmark, PipelineError, dimension_landmarks
from coordit_ml.training import load_model


class InferenceResult(BoundaryModel):
    """Uncalibrated development proposals, never measured centimeters."""

    schema_version: Literal[1] = 1
    status: Literal["needs_calibration", "failed"]
    reason: str
    model_version: str
    coordinate_system: Literal["upright_rgb_normalized_top_left"] = "upright_rgb_normalized_top_left"
    method: Literal["development_landmarks"] = "development_landmarks"
    category: str
    category_confidence: float
    confidence_calibrated: Literal[False] = False
    image_quality: Literal["unverified"] = "unverified"
    width: int
    height: int
    landmarks: list[Landmark]
    segmentation_polygon: list[list[float]]
    segmentation_mask_base64: str
    segmentation_mask_width: int = 64
    segmentation_mask_height: int = 64
    centimeter_values: dict[str, float]
    deployment_approved: Literal[False] = False


def infer_image(directory: Path, content: bytes) -> InferenceResult:
    """Decode/reorient metadata-free pixels in memory; no persistence and no training side effects."""
    torch.set_num_threads(2)
    model = load_model(directory)
    with Image.open(io.BytesIO(content)) as decoded:
        if decoded.width * decoded.height > 12_000_000:
            raise PipelineError("Image exceeds pixel budget")
        image = ImageOps.exif_transpose(decoded).convert("RGB")
    with torch.inference_mode():
        prediction = model.forward(image_tensor(image).unsqueeze(0))
    probabilities = prediction.category.softmax(1)[0]
    category_index = int(probabilities.argmax())
    category = CLASSES[category_index]
    permitted = {name for pair in dimension_landmarks(category).values() for name in pair}
    landmarks: list[Landmark] = []
    for index, name in enumerate(LANDMARKS):
        if name not in permitted:
            continue
        x, y = float(prediction.points[0, index, 0]), float(prediction.points[0, index, 1])
        confidence = float(prediction.visibility[0, index].sigmoid())
        landmarks.append(
            Landmark(
                landmark_type=name,
                x=x,
                y=y,
                visibility=2 if confidence >= 0.5 else 0,
                confidence=confidence,
                source="development_model",
            )
        )
    values: list[int] = prediction.mask[0, 0].sigmoid().ge(0.5).to(torch.uint8).mul(255).flatten().tolist()
    mask = Image.frombytes("L", (64, 64), bytes(values))
    output = io.BytesIO()
    mask.save(output, format="PNG")
    # A thresholded mask is available via the model; do not fabricate a polygon from its bounding box.
    return InferenceResult(
        status="needs_calibration",
        reason="absolute_scale_unavailable_and_model_unvalidated",
        model_version="coordit-tiny-multitask-v1",
        category=category,
        category_confidence=float(probabilities[category_index]),
        width=image.width,
        height=image.height,
        landmarks=landmarks,
        segmentation_polygon=[],
        segmentation_mask_base64=base64.b64encode(output.getvalue()).decode("ascii"),
        centimeter_values={},
    )
