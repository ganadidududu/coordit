# Fit Engine

문서 상태: 최신  
기준일: 2026-05-19  
관련 코드: `backend/src/modules/fit/*`, `backend/src/shared/utils/category-compatibility.ts`

coordit의 현재 Fit Engine은 ML이 아닌 rule-based 추천 엔진입니다. 사용자가 이미 가지고 있고 잘 맞는 기준 의류의 실측값과 외부 상품의 사이즈표를 비교해 가장 가까운 사이즈를 추천합니다.

## 현재 버전

```ts
ALGORITHM_VERSION = "mvp_rule_v1"
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
| `inseam` | 0.25 |

누락된 측정값은 `0`으로 보지 않고 비교에서 제외합니다. 비교 가능한 측정값이 없으면 추천을 계산할 수 없습니다.

## 점수 계산

기본 공식:

```text
diff = target_measurement - reference_measurement
weighted_fit_distance = sum(abs(diff) * weight) / used_weight_sum
fit_score = clamp(100 - weighted_fit_distance * 10, 0, 100)
final_fit_score = max(fit_score - fit_type_penalty, 0)
```

각 외부 상품 사이즈마다 점수를 계산하고, `final_fit_score`가 가장 높은 사이즈를 추천합니다.

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

각 기준 의류는 외부 상품 사이즈마다 개별 점수를 만들고, 최종 점수는 `preference_score`를 가중치로 평균냅니다.

```text
final_score = sum(reference_score * preference_score) / sum(preference_score)
```

대표 diff와 설명은 가장 점수가 높은 기준 의류 결과를 기반으로 합니다.

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
