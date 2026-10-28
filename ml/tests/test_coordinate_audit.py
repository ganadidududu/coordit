import torch
from PIL import Image, ImageDraw

from coordit_ml.coordinate_audit import coordinate_variants, peak_coordinates
from coordit_ml.network import image_tensor
from coordit_ml.schema import LANDMARKS


def test_nonsquare_photo_resize_and_normalized_landmark_keep_the_same_pixel_location() -> None:
    # Given a source photo with independent horizontal and vertical dimensions.
    image = Image.new("RGB", (512, 256))
    ImageDraw.Draw(image).rectangle((198, 28, 202, 32), fill=(0, 255, 0))
    point = torch.tensor([200.5 / 512, 30.5 / 256])
    # When the current preprocessing resizes the full image to a square.
    rgb = image_tensor(image, 128)
    position = int(rgb[1].flatten().argmax())
    center = torch.tensor([(position % 128 + 0.5) / 128, (position // 128 + 0.5) / 128])
    # Then normalized coordinates stay aligned, despite the altered image appearance aspect ratio.
    assert bool((point - center).abs().max() <= 1 / 128)


def test_coordinate_diagnostics_swap_names_without_mutating_original_predictions() -> None:
    # Given distinct landmark coordinates and a distinct maximum heatmap cell.
    points = torch.arange(len(LANDMARKS) * 2, dtype=torch.float32).reshape(1, len(LANDMARKS), 2) / 40
    original = points.clone()
    maps = torch.zeros(1, len(LANDMARKS), 4, 8)
    maps[:, :, 1, 6] = 2
    # When creating diagnostics, then original geometry is preserved and name swapping is explicit.
    variants = coordinate_variants(points, maps)
    assert torch.equal(points, original)
    assert torch.equal(variants["endpoint_names_swapped"][:, 0], original[:, 1])
    assert torch.equal(variants["mirror_x"][..., 0], 1 - original[..., 0])
    assert torch.allclose(peak_coordinates(maps)[0, 0], torch.tensor([6.5 / 8, 1.5 / 4]))
