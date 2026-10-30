"""Deterministic category sampling; repeated exposures never count as new garments."""

import math
import random
from collections import defaultdict

from coordit_ml.schema import BoundaryModel, PipelineError


class SourceSampling(BoundaryModel):
    """Fixed exposure budget and explicitly reviewed source ratios; not an accuracy optimum."""

    weights: dict[str, float]
    epoch_images: int


def sample_sources(sources: list[str], policy: SourceSampling, generator: random.Random) -> list[int]:
    """Allocate exact quotas, then cycle shuffled source pools before repeating an image."""
    groups: dict[str, list[int]] = defaultdict(list)
    for index, source in enumerate(sources):
        groups[source].append(index)
    if (
        set(groups) != set(policy.weights)
        or policy.epoch_images < len(groups)
        or any(weight <= 0 for weight in policy.weights.values())
    ):
        raise PipelineError("Source sampling requires positive weights for every observed source")
    total = sum(policy.weights.values())
    quotas = {source: int(policy.epoch_images * weight / total) for source, weight in policy.weights.items()}
    remainders = sorted(
        groups, key=lambda source: (-(policy.epoch_images * policy.weights[source] / total - quotas[source]), source)
    )
    for source in remainders[: policy.epoch_images - sum(quotas.values())]:
        quotas[source] += 1
    if any(quota == 0 for quota in quotas.values()):
        raise PipelineError("Source sampling budget drops a requested source")
    selected: list[int] = []
    for source in sorted(groups):
        choices = groups[source]
        generator.shuffle(choices)
        selected.extend(choices[offset % len(choices)] for offset in range(quotas[source]))
    generator.shuffle(selected)
    return selected


def balance_categories(indices: list[int], labels: list[str], generator: random.Random) -> list[int]:
    """Balance observed real classes before source-ratio sampling, retaining explicit repeated indices."""
    groups: dict[str, list[int]] = defaultdict(list)
    for index in indices:
        groups[labels[index]].append(index)
    if not groups:
        return []
    quota = math.ceil(len(indices) / len(groups))
    balanced: list[int] = []
    for category in sorted(groups):
        choices = sorted(groups[category])
        generator.shuffle(choices)
        balanced.extend(choices[offset % len(choices)] for offset in range(quota))
    generator.shuffle(balanced)
    return balanced
