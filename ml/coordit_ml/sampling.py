"""Deterministic category sampling; repeated exposures never count as new garments."""

import math
import random
from collections import defaultdict


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
