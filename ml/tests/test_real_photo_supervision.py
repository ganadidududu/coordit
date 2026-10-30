import hashlib
import random
from collections.abc import Callable
from pathlib import Path

import httpx2
import pytest
import torch

from coordit_ml.heatmap_network import spatial_loss
from coordit_ml.network import Prediction, Sample, loss
from coordit_ml.provenance import read_records
from coordit_ml.sampling import balance_categories
from coordit_ml.schema import PipelineError
from coordit_ml.secondhand_download import verify_source_pins
from coordit_ml.similarity import near_duplicate_pairs
from coordit_ml.source_downloads import PinnedFile, download_pinned
from coordit_ml.synthetic import generate


def test_approved_source_cannot_be_substituted_with_an_unreviewed_photo_mirror() -> None:
    mirror = PinnedFile(path="data/train.parquet", size=6, sha256="a" * 64, url="https://mirror.invalid/photo")
    with pytest.raises(PipelineError, match="reviewed publisher revision"):
        verify_source_pins([mirror])


@pytest.mark.parametrize("objective_function", [loss, spatial_loss])
def test_classification_only_photos_never_backpropagate_fake_mask_or_seam_truth(
    objective_function: Callable[[Prediction, Sample], torch.Tensor],
) -> None:
    torch.set_num_threads(2)
    prediction = Prediction(
        torch.zeros(2, 13, requires_grad=True),
        torch.ones(2, 1, 8, 8, requires_grad=True),
        torch.zeros(2, 17, 2, requires_grad=True),
        torch.zeros(2, 17, requires_grad=True),
        torch.ones(2, 17, 4, 4, requires_grad=True),
    )
    target = Sample(
        torch.zeros(2, 3, 8, 8),
        torch.tensor([1, 2]),
        torch.zeros(2, 1, 8, 8),
        torch.ones(2, 17, 2),
        torch.full((2, 17), -1.0),
        torch.zeros(2),
    )
    objective = objective_function(prediction, target)
    _ = objective.backward()
    assert prediction.mask.grad is not None
    assert torch.count_nonzero(prediction.mask.grad) == 0
    assert prediction.points.grad is not None
    assert torch.count_nonzero(prediction.points.grad) == 0
    assert prediction.category.grad is not None
    assert torch.count_nonzero(prediction.category.grad) > 0


def test_sampler_balances_exposures_without_inventing_independent_image_ids() -> None:
    labels = ["coat", "shirt", "shirt", "shirt", "shirt", "shirt"]
    samples = balance_categories(list(range(6)), labels, random.Random(42))
    assert set(samples) <= set(range(6))
    assert sum(labels[index] == "coat" for index in samples) == sum(labels[index] == "shirt" for index in samples)
    assert len(samples) > len(set(samples))


def test_download_resumes_exact_content_and_verifies_publisher_digest(tmp_path: Path) -> None:
    content = b"abcdef"
    target = tmp_path / "data.parquet"
    _ = target.with_suffix(".parquet.partial").write_bytes(content[:3])
    spec = PinnedFile(
        path="data/file.parquet", size=6, sha256=hashlib.sha256(content).hexdigest(), url="https://fixture.invalid/data"
    )

    def wire(request: httpx2.Request) -> httpx2.Response:
        assert request.headers["range"] == "bytes=3-"
        return httpx2.Response(206, headers={"content-range": "bytes 3-5/6"}, content=content[3:])

    with httpx2.Client(transport=httpx2.MockTransport(wire)) as client:
        actual = download_pinned(client, spec, target)
    assert actual.read_bytes() == content


def test_download_refuses_a_server_that_ignores_resume_range(tmp_path: Path) -> None:
    target = tmp_path / "data.parquet"
    _ = target.with_suffix(".parquet.partial").write_bytes(b"abc")
    spec = PinnedFile(
        path="data/file.parquet",
        size=6,
        sha256=hashlib.sha256(b"abcdef").hexdigest(),
        url="https://fixture.invalid/data",
    )
    with (
        httpx2.Client(transport=httpx2.MockTransport(lambda _: httpx2.Response(200, content=b"abcdef"))) as client,
        pytest.raises(PipelineError, match="exact resume range"),
    ):
        _ = download_pinned(client, spec, target)
    assert not target.exists()


def test_indexed_near_hash_search_matches_exhaustive_radius_four(tmp_path: Path) -> None:

    base = read_records(generate(tmp_path / "corpus", per_category=1))[0]
    values = [int.from_bytes(hashlib.sha256(str(i).encode()).digest()[:8], "big") for i in range(80)]
    values += [0, 1, (1 << 12) | (1 << 25) | (1 << 38) | (1 << 63), 0xFFFFFFFFFFFFFFFF]
    records = [base.model_copy(update={"perceptual_hash": f"{value:016x}"}) for value in values]
    expected = {(i, j) for i in range(len(values)) for j in range(i) if (values[i] ^ values[j]).bit_count() <= 4}
    assert set(near_duplicate_pairs(records)) == expected
