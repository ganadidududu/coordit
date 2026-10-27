"""Exact radius-four Hamming candidates without a quadratic full-corpus scan."""

from collections import defaultdict
from collections.abc import Iterator

from coordit_ml.schema import Record


def near_duplicate_pairs(records: list[Record]) -> Iterator[tuple[int, int]]:
    """Five disjoint hash blocks guarantee a match for every <=4-bit neighbor (pigeonhole rule)."""
    buckets: dict[tuple[int, int], list[int]] = defaultdict(list)
    values = [int(record.perceptual_hash, 16) for record in records]
    for index, value in enumerate(values):
        keys = [(block, (value >> (block * 13)) & (0xFFF if block == 4 else 0x1FFF)) for block in range(5)]
        candidates = {previous for key in keys for previous in buckets[key]}
        for previous in sorted(candidates):
            if (value ^ values[previous]).bit_count() <= 4:
                yield index, previous
        for key in keys:
            buckets[key].append(index)
