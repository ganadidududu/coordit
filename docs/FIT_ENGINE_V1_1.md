# Fit Engine v1.1

Fit Engine v1.1 keeps coordit's core philosophy: recommend the external product size whose measured dimensions are closest to clothing the user already knows fits well.

## Multiple References

The engine accepts multiple active reference clothing rows. Each reference produces an individual score against every external product size.

Final score:

```text
sum(reference_score * preference_score) / sum(preference_score)
```

## Category Compatibility

Compatibility is checked before scoring.

- `hoodie` can compare with `sweatshirt`.
- `pants` can compare with `jeans`.
- unrelated categories are rejected.

## Explanation

The result includes:

- global fit comment
- per-measurement explanations
- part status
- recommendation confidence

Confidence considers compared measurement count, weighted distance, score level, and top-size score gap.
