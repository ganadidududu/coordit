# Fit Score Engine

coordit's MVP Fit Score Engine is rule-based. It does not use ML yet.

## Principles

- Reference clothing is more important than body measurements.
- Missing measurements are skipped, never treated as `0`.
- Distances are normalized by the sum of weights actually used.
- Each category uses a different set of measurement weights.
- The recommended size is the size with the highest final score.

## Formula

```text
diff = target_measurement - reference_measurement
weighted_fit_distance = sum(abs(diff) * weight) / used_weight_sum
fit_score = clamp(100 - weighted_fit_distance * 10, 0, 100)
final_fit_score = max(fit_score - fit_type_penalty, 0)
```

## Top Categories

- `shoulder_width`: 0.35
- `chest_width`: 0.30
- `total_length`: 0.20
- `sleeve_length`: 0.15

## Bottom Categories

- `waist_width`: 0.35
- `hip_width`: 0.25
- `rise`: 0.15
- `inseam`: 0.25

## Labels

- 95-100: `very_good_fit`
- 85-94: `good_fit`
- 70-84: `acceptable`
- 50-69: `slightly_small` or `slightly_large`
- 0-49: `too_small` or `too_large`

