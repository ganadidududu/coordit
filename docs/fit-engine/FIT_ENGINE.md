# Fit Engine

문서 상태: 최신  
기준일: 2026-06-23
관련 코드: `backend/src/modules/fit/*`, `backend/src/shared/utils/category-compatibility.ts`

coordit의 현재 Fit Engine은 ML이 아닌 rule-based 추천 엔진입니다. 사용자가 이미 가지고 있고 잘 맞는 기준 의류의 실측값과 외부 상품의 사이즈표를 비교해 가장 가까운 사이즈를 추천합니다.

## 현재 버전

```ts
ALGORITHM_VERSION = "mvp_rule_v1_3"
```

## 입력 데이터

추천 엔진은 API에서 다음 데이터를 조합해 입력을 만듭니다.

- 활성화된 `reference_clothing`
- 기준 의류와 연결된 `clothing_items`
- 기준 의류의 `clothing_sizes`
- 비교 대상 `external_products`
- 외부 상품의 `external_product_sizes`

## 지원 카테고리

상의:

- `tshirt`
- `shirt`
- `sweatshirt`
- `hoodie`
- `knit`
- `jacket`
- `coat`

하의:

- `pants`
- `jeans`
- `shorts`
- `skirt`

## 카테고리 호환성

동일 카테고리는 항상 호환됩니다. 추가 호환 그룹은 다음입니다.

- `hoodie`, `sweatshirt`
- `pants`, `jeans`
- `shirt`, `tshirt`, `knit`
- `jacket`, `coat`
- `shorts`, `skirt`

호환되지 않는 카테고리 조합은 추천 전에 `400` 에러가 납니다.

## 측정값

상의 가중치:

| 측정값 | 가중치 |
| --- | --- |
| `shoulder_width` | 0.35 |
| `chest_width` | 0.30 |
| `total_length` | 0.20 |
| `sleeve_length` | 0.15 |

하의 가중치:

| 측정값 | 가중치 |
| --- | --- |
| `waist_width` | 0.35 |
| `hip_width` | 0.25 |
| `rise` | 0.15 |
| `outseam` | 0.25 |

누락된 측정값은 `0`으로 보지 않고 비교에서 제외합니다. 비교 가능한 측정값이 없으면 추천을 계산할 수 없습니다.

## 점수 계산

기준 의류가 여러 벌이면, 각 기준 의류와 후보 사이즈의 점수를 평균내지 않습니다. 여러 기준 의류로부터 사용자의 **가상 100점 핏 프로필**을 먼저 만들고, 후보 사이즈를 이 프로필과 비교합니다. 따라서 기준 의류가 많아져도 기준 의류 간 차이만으로 최고점이 낮아지지 않습니다.

### 가상 100점 핏 프로필

측정 항목 `k`의 기준 의류 실측값을 `xᵢₖ`, 해당 기준 의류의 `preference_score`를 `pᵢ`라고 합니다. `pᵢ`가 없으면 `100`을 사용하며 최소값은 `1`입니다.

```text
mₖ = weightedMedian(xᵢₖ, pᵢ)
MADₖ = weightedMedian(|xᵢₖ - mₖ|, pᵢ)
sₖ = 1.4826 × MADₖ
oᵢₖ = min(1, (1.5 × max(sₖ, toleranceFloorₖ)) / |xᵢₖ - mₖ|)
μₖ = Σ(pᵢ × oᵢₖ × xᵢₖ) / Σ(pᵢ × oᵢₖ)
```

`μₖ`는 가상 프로필의 해당 항목 값입니다. 먼저 가중 중앙값으로 중심을 잡고, Huber 방식의 이상치 완화 계수 `oᵢₖ`를 적용한 가중 평균으로 최종값을 계산합니다. 중심에서 멀리 떨어진 기준 의류는 프로필에 미치는 영향이 점진적으로 줄어듭니다.

`1.4826`은 MAD를 표준편차와 같은 스케일로 바꾸는 보정 상수입니다. 정규분포에서 `MAD ≈ 0.67449 × 표준편차`이므로 `1 / 0.67449 ≈ 1.4826`입니다.

### 항목별 허용 오차

허용 오차 `τₖ`는 해당 측정 항목에서 사용자가 자연스럽게 받아들이는 실측 편차입니다. 중요도와는 다른 값입니다.

```text
τₖ = clamp(sₖ, toleranceFloorₖ, toleranceCeilingₖ)
```

- 동적 가중치 `Wₖ`: 전체 점수에서 해당 항목이 차지하는 중요도
- 허용 오차 `τₖ`: 해당 항목의 cm 차이에 얼마나 민감하게 감점할지 정하는 기준

현재 하한/상한 값은 다음과 같습니다. 하한은 기준 의류의 값이 거의 같을 때 과도하게 민감해지는 것을 막고, 상한은 서로 다른 스타일이 섞였을 때 지나치게 관대해지는 것을 막습니다.

| 항목 | 최소 허용 오차 | 최대 허용 오차 |
| --- | ---: | ---: |
| `waist_width` | 0.5cm | 3cm |
| `hip_width` | 0.75cm | 5cm |
| `rise` | 0.5cm | 4cm |
| `outseam` | 1cm | 8cm |

### 후보 사이즈 점수

후보 실측값을 `yₖ`, 동적 가중치를 `Wₖ`라고 할 때:

```text
diffₖ = yₖ - μₖ
normalized_distance = Σ((|diffₖ| / τₖ) × Wₖ) / Σ(used Wₖ)
fit_score = clamp(100 - normalized_distance × 30, 0, 100)
final_fit_score = max(fit_score - fit_type_penalty, 0)
```

가상 프로필과 실측이 같은 후보는 100점입니다. `weighted_fit_distance`는 이 경로에서 cm가 아니라 허용 오차로 정규화된 무차원 거리입니다.

## Fit label

| 점수 | label |
| --- | --- |
| 95 이상 | `very_good_fit` |
| 85 이상 | `good_fit` |
| 70 이상 | `acceptable` |
| 50 이상 | `slightly_small` 또는 `slightly_large` |
| 50 미만 | `too_small` 또는 `too_large` |

small/large 계열 label은 주요 부위 평균 차이가 음수인지 양수인지에 따라 결정됩니다.

## Fit type penalty

현재 penalty는 간단한 rule로 적용됩니다.

- `oversized`인데 어깨/가슴이 기준보다 너무 작으면 penalty
- `relaxed`인데 가슴이 기준보다 너무 작으면 penalty
- `slim`인데 가슴/허리가 너무 크면 penalty
- `regular`인데 주요 부위 차이가 과도하면 penalty

## 다중 기준 의류

`referenceClothingIds`로 여러 기준 의류를 전달할 수 있습니다.

각 기준 의류는 가상 100점 핏 프로필을 만드는 입력으로 사용됩니다. `preference_score`는 프로필 중심값 계산에 반영되며, 기준 의류별 점수를 평균내는 용도로는 사용하지 않습니다.

대표 diff와 설명은 후보 사이즈와 가상 프로필의 차이를 기반으로 합니다.

### Reference Variance Weighting

사용자가 여러 기준 의류를 선택한 경우, coordit은 단순 평균만 사용하지 않습니다. 기준 의류들 사이에서 측정값이 일관되게 유지되는 항목을 더 중요한 핏 기준으로 봅니다. 예를 들어 사용자의 여러 기준 상의에서 어깨너비의 표준편차가 작다면, 사용자가 어깨 핏에 대해 비교적 일관된 선호를 가지고 있다고 해석할 수 있습니다. 따라서 해당 항목의 가중치를 높여 추천 정확도를 개선합니다.

수식 흐름:

```text
measurement_values = 여러 reference clothing의 동일 측정 항목 값 목록
stdDev = standardDeviation(measurement_values)
importanceMultiplier = stdDev가 작을수록 증가
dynamicWeight = baseWeight × importanceMultiplier
normalizedWeight = dynamicWeight / sum(dynamicWeights)
```

적용 조건:

- 기준 의류가 2개 이상일 때만 적용합니다.
- 기준 의류가 1개뿐이면 기존 base weight를 그대로 사용합니다.
- 특정 측정 항목의 값이 2개 미만이면 동적 보정 대상에서 제외합니다.
- 누락값은 표준편차 계산에서 제외합니다.
- 최종 dynamic weight 합은 항상 1이 되도록 정규화합니다.

추천 결과의 `result_details`에는 다음 메타데이터가 저장됩니다.

- `baseWeights`
- `dynamicWeights`
- `referenceVariance`
- `weightingStrategy`
- `referenceProfile` (가상 프로필 실측값, 허용 오차, robust scale, 항목별 표본 수)

## Confidence

`recommendationConfidence`는 다음 요소를 고려합니다.

- 비교 가능한 측정값 개수
- 최종 점수
- weighted distance
- 1등 사이즈와 2등 사이즈의 점수 차이

결과는 `high`, `medium`, `low` 중 하나입니다.

## 저장 데이터

추천 실행 후 다음 테이블에 저장됩니다.

### `fit_analysis_results`

- 추천 사이즈
- 점수
- label
- comment
- weighted distance
- algorithm version
- confidence
- `result_details`

### `recommendation_logs`

- 추천 결과 ID
- 외부 상품 ID
- 추천 사이즈
- `event_type = "shown"`
- algorithm version

## 현재 한계

- 신체 치수는 아직 추천 점수에 적극 반영되지 않습니다.
- 사용자 피드백은 저장되지만 추천 가중치 학습에는 아직 사용되지 않습니다.
- 브랜드별 사이즈 보정이 없습니다.
- 다중 기준 의류를 사용해도 DB의 `reference_clothing_id`에는 첫 번째 기준 의류만 저장됩니다.
- OCR/URL 파싱 결과의 신뢰도는 추천 점수에 아직 반영되지 않습니다.
