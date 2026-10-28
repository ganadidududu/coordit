import torch

from coordit_ml.augmentation import Warp, apply_warps
from coordit_ml.network import Sample


def test_rotation_keeps_landmark_and_mask_pixel_in_the_same_coordinate_system() -> None:
    # Given a known visible point at the center of pixel (24,16).
    pixels = torch.zeros(1, 3, 32, 32)
    mask = torch.zeros(1, 1, 32, 32)
    mask[0, 0, 16, 24] = 1
    target = Sample(pixels, torch.zeros(1, dtype=torch.long), mask,
                    torch.tensor([[[24.5 / 32, 16.5 / 32]]]), torch.ones(1, 1), torch.ones(1))
    # When rotating clockwise by 90 degrees about the image center.
    transformed = apply_warps(target, [Warp(angle_degrees=90, scale=1, tx=0, ty=0, brightness=1)])
    # Then point and nearest-neighbor mask still identify the same physical image pixel.
    assert torch.allclose(transformed.points, torch.tensor([[[15.5 / 32, 24.5 / 32]]]))
    assert transformed.mask[0, 0, 24, 15] == 1
    assert int(transformed.mask.sum()) == 1


def test_crop_masks_visible_points_without_inventing_visibility_for_unlabeled_heads() -> None:
    # Given visible and unannotated heads at the right of an image.
    target = Sample(torch.ones(1, 3, 32, 32), torch.zeros(1, dtype=torch.long), torch.ones(1, 1, 32, 32),
                    torch.tensor([[[0.8, 0.5], [0.8, 0.5]]]), torch.tensor([[1.0, -1.0]]), torch.ones(1))
    # When translating the points out of frame.
    transformed = apply_warps(target, [Warp(angle_degrees=0, scale=1, tx=0.5, ty=0, brightness=0.5)])
    # Then cropped truth is hidden, while missing supervision stays missing.
    assert torch.equal(transformed.visibility, torch.tensor([[0.0, -1.0]]))
    assert torch.all((transformed.points >= 0) & (transformed.points <= 1))
    assert transformed.pixels.max() == 0.5
