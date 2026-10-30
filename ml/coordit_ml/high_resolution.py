"""Explicit higher-resolution contracts reuse the original spatial weights without reinterpreting v2."""

from typing import ClassVar, final

from coordit_ml.heatmap_network import GarmentHeatmapNet


@final
class GarmentHeatmapNet256(GarmentHeatmapNet):
    """256 RGB with 128 heatmaps; exact parameter shapes remain compatible with reviewed v2 weights."""

    input_size: ClassVar[int] = 256
    model_version: ClassVar[str] = "coordit-spatial-multitask-v3-256"


@final
class GarmentHeatmapNet512(GarmentHeatmapNet):
    """512 RGB research contract; support is distinct from any claim of executed 512 training."""

    input_size: ClassVar[int] = 512
    model_version: ClassVar[str] = "coordit-spatial-multitask-v3-512"


@final
class GarmentHeatmapNet256Context(GarmentHeatmapNet):
    """Double convolution dilation to retain wider image context at twice the input resolution."""

    input_size: ClassVar[int] = 256
    model_version: ClassVar[str] = "coordit-spatial-multitask-v4-256-context"

    def __init__(self, category_heads: bool = False) -> None:
        """Keep every parameter shape, adjusting only sampling spacing in the spatial blocks."""
        super().__init__(category_heads)
        for block in (
            self.encoder0, self.encoder1, self.encoder2, self.encoder3,
            self.decoder2, self.decoder1, self.decoder0,
        ):
            block.first.dilation = (2, 2)
            block.first.padding = (2, 2)
            block.second.dilation = (2, 2)
            block.second.padding = (2, 2)
