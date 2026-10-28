"""Local human side-reference evidence; garment side is distinct from screen-x or wearer anatomy."""

import re
from typing import Literal

from coordit_ml.schema import BoundaryModel, Landmark, PipelineError, Record


class SideReference(BoundaryModel):
    """Two visible lower-hem anchors establish one consistent side assignment for the whole garment."""

    left_hem: Landmark
    right_hem: Landmark
    view: Literal["front", "back"]


def validate_side_reference(reference: SideReference | None, record: Record) -> None:
    """The left lower-hem endpoint is nearest the original-pixel bbox bottom-left, following aRTF's rule."""
    if reference is None:
        raise PipelineError("Human hem reference anchors are required for v2 seam review")
    left, right = reference.left_hem, reference.right_hem
    source_view = re.search(r"_(front|back)_", record.source_path)
    if source_view and source_view[1] != reference.view:
        raise PipelineError("Human seam view differs from original publisher view")
    corner_x, top, _, height = record.bbox
    corner_y = top + height
    left_distance = (left.x * record.width - corner_x) ** 2 + (left.y * record.height - corner_y) ** 2
    right_distance = (right.x * record.width - corner_x) ** 2 + (right.y * record.height - corner_y) ** 2
    if (
        left.visibility != 2
        or right.visibility != 2
        or left_distance >= right_distance
        or (left.x - right.x) ** 2 + (left.y - right.y) ** 2 < 0.025**2
    ):
        raise PipelineError("Ambiguous or reversed human garment-side reference")
