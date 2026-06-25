# Coordit Fit Engine

문서 상태: 모바일 MVP 기준 정리본  
기준일: 2026-06-25  
현재 버전: `mvp_rule_v1_3`

## 1. 문서 목적

이 문서는 Coordit Fit Engine의 입력, 계산 과정, 점수화 방식, 다중 기준 의류 처리, confidence, feedback 구조를 설명한다.

이 문서는 API endpoint, DB schema, 화면 구성을 설명하지 않는다.

## 2. 엔진 역할

Fit Engine은 사용자가 잘 맞는다고 지정한 기준 의류의 실측값과 외부 상품의 사이즈표를 비교해 가장 적합한 사이즈를 추천한다.

현재 엔진은 ML 모델이 아니라 rule-based 엔진이다. 다만 다중 기준 의류, 표준편차 기반 가중치, 가상 기준 프로필을 사용해 사용자별 핏 선호를 반영한다.

## 3. 입력

엔진은 추천 실행 시 다음 정보를 입력으로 받는다.

- 기준 의류 1개 또는 여러 개
- 기준 의류별 실측값
- 기준 의류별 선호도 점수
- 외부 상품 정보
- 외부 상품의 사이즈별 실측값
- 카테고리
- fit type

측정값 단위는 cm다.

## 4. 지원 카테고리

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

## 5. 카테고리 호환성

동일 카테고리는 항상 호환된다.

추가 호환 그룹:

- `hoodie`, `sweatshirt`
- `pants`, `jeans`
- `shirt`, `tshirt`, `knit`
- `jacket`, `coat`
- `shorts`, `skirt`

호환되지 않는 카테고리 조합은 추천 계산 대상이 아니다.

## 6. 측정값과 기본 가중치

누락된 측정값은 `0`으로 보지 않고 비교에서 제외한다. 비교 가능한 측정값이 없으면 추천을 계산할 수 없다.

### 6.1 상의

| 측정값 | 기본 가중치 |
| --- | ---: |
| `shoulder_width` | 0.35 |
| `chest_width` | 0.30 |
| `total_length` | 0.20 |
| `sleeve_length` | 0.15 |

### 6.2 하의

| 측정값 | 기본 가중치 |
| --- | ---: |
| `waist_width` | 0.35 |
| `hip_width` | 0.25 |
| `rise` | 0.15 |
| `outseam` | 0.25 |

## 7. Multiple Reference Clothing

기준 의류가 여러 개일 때 엔진은 각 기준 의류와 후보 사이즈의 점수를 단순 평균하지 않는다. 먼저 여러 기준 의류로부터 사용자의 가상 100점 핏 프로필을 만든 뒤, 후보 사이즈를 이 프로필과 비교한다.

이 방식의 목적:

- 기준 의류가 여러 개여도 최고점 후보가 불필요하게 낮아지지 않게 한다.
- 사용자의 일관된 핏 선호를 중심값으로 만든다.
- 유난히 크거나 작은 기준 의류의 영향을 완화한다.

## 8. Virtual Reference Profile

측정 항목 `k`의 기준 의류 실측값을 `xᵢₖ`, 해당 기준 의류의 선호도 점수를 `pᵢ`라고 한다. `pᵢ`가 없으면 `100`을 사용하며 최소값은 `1`이다.

```text
mₖ = weightedMedian(xᵢₖ, pᵢ)
MADₖ = weightedMedian(|xᵢₖ - mₖ|, pᵢ)
sₖ = 1.4826 × MADₖ
oᵢₖ = min(1, (1.5 × max(sₖ, toleranceFloorₖ)) / |xᵢₖ - mₖ|)
μₖ = Σ(pᵢ × oᵢₖ × xᵢₖ) / Σ(pᵢ × oᵢₖ)
```

용어:

- `mₖ`: 가중 중앙값
- `MADₖ`: median absolute deviation
- `sₖ`: robust scale
- `oᵢₖ`: 이상치 완화 계수
- `μₖ`: 가상 기준 프로필의 측정값

`1.4826`은 MAD를 표준편차와 유사한 스케일로 변환하는 보정 상수다.

## 9. 표준편차 기반 가중치

다중 기준 의류 사용 시 엔진은 기준 의류 간 측정값 편차를 분석한다.

해석:

- 특정 부위의 기준 의류 값이 일관되면 사용자가 그 부위 핏에 민감하다고 본다.
- 특정 부위의 기준 의류 값이 크게 흔들리면 그 부위에 대한 선호가 유연하다고 본다.

계산 흐름:

```text
measurement_values = 기준 의류들의 동일 측정 항목 값
stdDev = standardDeviation(measurement_values)
importanceMultiplier = stdDev가 작을수록 증가
dynamicWeight = baseWeight × importanceMultiplier
normalizedWeight = dynamicWeight / sum(dynamicWeights)
```

적용 조건:

- 기준 의류가 2개 이상일 때만 적용한다.
- 기준 의류가 1개뿐이면 기본 가중치를 사용한다.
- 특정 측정 항목 값이 2개 미만이면 동적 보정 대상에서 제외한다.
- 누락값은 표준편차 계산에서 제외한다.
- 최종 동적 가중치 합은 1이 되도록 정규화한다.

## 10. 허용 오차

허용 오차는 해당 부위의 cm 차이에 얼마나 민감하게 감점할지 정하는 기준이다. 중요도 가중치와 다른 개념이다.

```text
τₖ = clamp(sₖ, toleranceFloorₖ, toleranceCeilingₖ)
```

현재 하의 기준 허용 오차:

| 항목 | 최소 허용 오차 | 최대 허용 오차 |
| --- | ---: | ---: |
| `waist_width` | 0.5cm | 3cm |
| `hip_width` | 0.75cm | 5cm |
| `rise` | 0.5cm | 4cm |
| `outseam` | 1cm | 8cm |

허용 오차 하한은 지나치게 민감한 감점을 막고, 상한은 지나치게 관대한 추천을 막는다.

## 11. 후보 사이즈 점수 계산

후보 사이즈의 측정값을 `yₖ`, 가상 기준 프로필 값을 `μₖ`, 동적 가중치를 `Wₖ`, 허용 오차를 `τₖ`라고 한다.

```text
diffₖ = yₖ - μₖ
normalized_distance = Σ((|diffₖ| / τₖ) × Wₖ) / Σ(used Wₖ)
fit_score = clamp(100 - normalized_distance × 30, 0, 100)
final_fit_score = max(fit_score - fit_type_penalty, 0)
```

가상 기준 프로필과 실측이 같은 후보는 100점에 가까운 점수를 받는다. `weighted_fit_distance`는 cm가 아니라 허용 오차로 정규화된 거리다.

## 12. Fit Type Penalty

Fit type penalty는 상품 fit type과 기준 프로필의 차이를 보정한다.

현재 규칙:

- `oversized`인데 어깨/가슴이 기준보다 너무 작으면 penalty
- `relaxed`인데 가슴이 기준보다 너무 작으면 penalty
- `slim`인데 가슴/허리가 너무 크면 penalty
- `regular`인데 주요 부위 차이가 과도하면 penalty

## 13. Fit Score

Fit score는 0-100 범위의 숫자다.

해석:

- 높을수록 기준 의류 또는 가상 기준 프로필과 가깝다.
- 비교 가능한 측정값이 많을수록 결과 해석이 안정적이다.
- 같은 점수라도 confidence가 낮으면 사용자가 주의해서 봐야 한다.

## 14. Fit Label

| 점수 | label |
| --- | --- |
| 95 이상 | `very_good_fit` |
| 85 이상 | `good_fit` |
| 70 이상 | `acceptable` |
| 50 이상 | `slightly_small` 또는 `slightly_large` |
| 50 미만 | `too_small` 또는 `too_large` |

small/large 계열 label은 주요 부위 평균 차이가 음수인지 양수인지에 따라 결정된다.

## 15. Confidence

`recommendationConfidence`는 추천 결과의 신뢰도를 나타낸다.

고려 요소:

- 비교 가능한 측정값 개수
- 최종 fit score
- weighted distance
- 1등 사이즈와 2등 사이즈의 점수 차이
- 기준 의류 데이터의 충분성

값:

- `high`
- `medium`
- `low`

## 16. Feedback 구조

피드백은 추천 결과가 실제 착용 또는 구매 후 맞았는지 기록하는 데이터다.

입력 개념:

- 추천 결과
- 구매한 사이즈
- 실제 핏 점수
- 실제 핏 라벨
- 사용자 코멘트

피드백 활용 방향:

- 사용자별 선호 여유분 보정
- 카테고리별 penalty 조정
- 브랜드별 사이즈 편차 보정
- confidence 개선

현재 MVP에서는 피드백을 저장하지만 추천 가중치 학습에는 아직 적극 반영하지 않는다.

## 17. 결과 메타데이터

추천 결과에는 앱 설명과 디버깅을 위해 다음 메타데이터가 포함될 수 있다.

- `baseWeights`
- `dynamicWeights`
- `referenceVariance`
- `weightingStrategy`
- `referenceProfile`
- `allSizeScores`
- `diff`

이 메타데이터는 앱에서 추천 이유, 부위별 차이, 신뢰도 설명을 표현하는 데 사용한다.

## 18. 현재 한계

- 신체 치수는 아직 추천 점수에 적극 반영되지 않는다.
- 사용자 피드백은 저장되지만 추천 가중치 학습에는 아직 사용되지 않는다.
- 브랜드별 사이즈 보정이 없다.
- OCR/URL 파싱 결과의 신뢰도는 추천 점수에 아직 반영되지 않는다.
- 측정값 단위 변환과 문자열 기반 치수 파싱은 아직 제한적이다.
