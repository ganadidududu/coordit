import torch

from coordit_ml.network import Prediction, Sample
from coordit_ml.pair_supervision import projected_pair_loss
from coordit_ml.schema import LANDMARKS


def test_pair_objective_uses_original_pixel_aspect_for_equal_length_segments() -> None:
    # Given a horizontal GT segment and a vertically oriented prediction with identical pixel length at aspect 2.
    points = torch.zeros(1, len(LANDMARKS), 2)
    points[0, 0], points[0, 1] = torch.tensor([0.25, 0.5]), torch.tensor([0.5, 0.5])
    visibility = torch.full((1, len(LANDMARKS)), -1.0)
    visibility[0, :2] = 1
    target = Sample(
        torch.zeros(1, 3, 4, 4),
        torch.zeros(1, dtype=torch.long),
        torch.zeros(1, 1, 4, 4),
        points,
        visibility,
        torch.ones(1),
    )
    inferred = points.clone()
    inferred[0, 0], inferred[0, 1] = torch.tensor([0.5, 0.25]), torch.tensor([0.5, 0.75])
    prediction = Prediction(torch.zeros(1, 13), torch.zeros(1, 1, 4, 4), inferred, torch.zeros(1, len(LANDMARKS)))
    # When supervising the projection distance, then only the correct source aspect gives zero error.
    assert float(projected_pair_loss(prediction, target, torch.tensor([2.0]))) < 1e-6
    assert float(projected_pair_loss(prediction, target, torch.tensor([1.0]))) > 0.1


def _collapsed_pair(*, hidden: bool) -> tuple[Prediction, Sample, torch.Tensor]:
    points = torch.zeros(1, len(LANDMARKS), 2)
    points[0, 0], points[0, 1] = torch.tensor([0.2, 0.5]), torch.tensor([0.8, 0.5])
    visibility = torch.full((1, len(LANDMARKS)), -1.0)
    visibility[0, :2] = torch.tensor([1.0, 0.0 if hidden else 1.0])
    target = Sample(
        torch.zeros(1, 3, 4, 4),
        torch.zeros(1, dtype=torch.long),
        torch.zeros(1, 1, 4, 4),
        points,
        visibility,
        torch.ones(1),
    )
    inferred = torch.full_like(points, 0.5, requires_grad=True)
    prediction = Prediction(torch.zeros(1, 13), torch.zeros(1, 1, 4, 4), inferred, torch.zeros(1, len(LANDMARKS)))
    return prediction, target, inferred


def test_occluded_pair_provides_no_fabricated_distance_target() -> None:
    # Given one visible and one occluded endpoint of a known segment.
    prediction, target, _ = _collapsed_pair(hidden=True)
    # When scoring a hidden pair, then its projected distance cannot teach fabricated geometry.
    assert float(projected_pair_loss(prediction, target, torch.ones(1)).detach()) == 0


def test_collapsed_visible_pair_has_finite_loss_and_gradient() -> None:
    # Given coincident predicted endpoints and a visible nonzero ground-truth distance.
    prediction, target, inferred = _collapsed_pair(hidden=False)
    # When differentiating the distance objective, then zero separation cannot create NaN gradients.
    loss = projected_pair_loss(prediction, target, torch.ones(1))
    gradient, = torch.autograd.grad(loss, inferred)
    assert bool(loss.isfinite())
    assert bool(gradient.isfinite().all())
