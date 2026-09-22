# Coordit Fit Engine

문서 상태: 모바일 MVP 기준 정리본  
기준일: 2026-07-31
현재 버전: `fit_engine_v2_0`

## 1. 문서 목적

이 문서는 Coordit Fit Engine의 입력, 계산 과정, 점수화 방식, 다중 기준 의류 처리와 결과 메타데이터를 설명한다.

이 문서는 API endpoint, DB schema, 화면 구성을 설명하지 않는다.

## 2. 엔진 역할

Fit Engine은 사용자가 잘 맞는다고 지정한 기준 의류의 실측값과 외부 상품의 사이즈표를 비교해 가장 적합한 사이즈를 추천한다.

현재 엔진은 ML 모델이 아니라 deterministic rule-based 엔진이다. 다중 기준 의류, category별 garment profile, 방향성 tolerance, Huber loss, 부위 interaction을 사용한다. 피드백은 calibration readiness가 `applied`인 경우에만 제한된 offset/weight modifier로 반영한다.

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

동일 카테고리는 `exact`다. `related`는 상의의 `tshirt`·`shirt`·`sweatshirt`·`hoodie`·`knit` 내의 명시된 조합, `jacket`↔`coat`, 하의의 `pants`·`jeans`·`shorts` 내의 명시된 조합에만 허용된다. `skirt`는 다른 category와 호환되지 않는다. 전체 방향별 목록은 `category-compatibility.ts`가 단일 출처다. 선택한 기준 의류에 exact가 하나라도 있으면 related는 제외하고, exact가 없을 때만 related를 사용한다. 둘 다 없으면 요청을 거절한다.

## 6. 측정값과 기본 가중치

누락된 측정값은 `0`으로 보지 않고 비교에서 제외한다. 비교 가능한 측정값이 없으면 추천을 계산할 수 없다.

11개 category의 기본 가중치와 방향별 허용 오차는 `garment-fit-profiles.ts`에서 각각 정의한다. 예를 들어 티셔츠는 가슴단면·총장, 재킷은 어깨·가슴단면·소매, 팬츠는 허리·힙·밑위·아웃심, 스커트는 허리·힙·총장 중심이다. 스커트에는 `rise`·`outseam` 가중치가 없다. 각 profile의 가중치 합은 1이며, 동일 부위의 cm 차이라도 category별 tolerance와 weight 때문에 점수가 달라진다.

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

V2의 최종 허용 오차는 `category`·부위·차이 방향의 profile 값에 `fitType` modifier를 곱한다. 다중 기준 의류에서 학습한 허용 오차가 있으면 profile 기본값 대비 1~1.5배의 제한된 variance modifier를 추가로 적용한다. 따라서 같은 +3cm와 -3cm도 다른 normalized loss를 낼 수 있다. `fit-tolerance.ts`가 계산의 단일 출처다.

## 11. 후보 사이즈 점수 계산

후보 사이즈의 측정값을 `yₖ`, 가상 기준 프로필 값을 `μₖ`, 동적 가중치를 `Wₖ`, 허용 오차를 `τₖ`라고 한다.

```text
diffₖ = yₖ - μₖ
zₖ = |diffₖ| / directional_tolerance(category, fit_type, direction)
normalized_loss = Σ(huber(zₖ) × Wₖ) / Σ(used Wₖ)
fit_score = clamp(100 × exp(-normalized_loss / 1.5), 0.1, 100)
final_fit_score = clamp(fit_score - capped_interaction_penalty, 0.1, 100)
```

가상 기준 프로필과 실측이 같은 후보는 정확히 100점을 받는다. 작은 차이는 완만하게 감점하고, 큰 차이는 0점에 가까워지도록 전체 점수 범위를 사용한다. 유효한 실측 비교 결과의 최저값은 0.1점이므로 화면에서 0.0점은 표시하지 않는다. `weighted_fit_distance`는 cm가 아니라 허용 오차로 정규화된 거리다.

누락 실측은 사용 가능한 weight만 다시 정규화한다. OCR confidence와 source quality는 score에 반영하지 않고 recommendation confidence metadata에만 반영한다. 피드백은 reliability가 명시적으로 `applied`일 때만 builder가 제한한 범위 안에서 적용한다.

## 12. Category, Fit Type, Interaction

11개 category는 독립 weight, smaller/larger tolerance, critical/secondary measurement, semantic concern을 가진다. `slim`, `regular`, `relaxed`, `oversized`는 방향성 tolerance와 volume measurement importance에 제한된 modifier를 적용한다.

interaction은 어깨+가슴, 어깨+소매, 가슴+총장, 허리+힙, 힙+밑위 등 category profile에 선언된다. interaction 결과와 semantic effects는 deterministic이며, 동일 차이를 두 번 과도하게 벌하지 않도록 전체 interaction penalty를 2점으로 제한한다.

## 13. Fit Score

Fit score는 0-100 범위의 숫자다. 정확히 일치한 후보만 100점이며, 비교 가능한 실측이 있는 후보의 최종 점수는 0.1점 이상이다. 0–20점 구간은 기준 의류와 매우 크게 차이 나는 후보를 구분하는 데 사용한다. 비교 가능한 실측이 없으면 점수를 0점으로 표시하지 않고 추천 계산 자체를 중단한다.

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
- 피드백 보정 신뢰도
- 상품 실측 데이터 품질

값:

- `high`
- `medium`
- `low`

`fit_engine_v2_0`에서도 confidence 판단 근거는 `scoreExplanation`과
`confidenceBreakdown`에 선택 메타데이터로 저장될 수 있다. 이 메타데이터는
내부 진단용이며 `fit_score` 계산값이나 사용자 리포트 서술을 바꾸지 않는다.

## 16. Feedback 저장 구조

피드백은 추천 결과가 실제 착용 또는 구매 후 맞았는지 기록하는 데이터다. 현재 버전에서는 저장과 오프라인 분석에만 사용하며 다음 추천 점수에는 적용하지 않는다.

입력 개념:

- 추천 결과
- 구매한 사이즈
- 실제 핏 점수
- 실제 핏 라벨
- 부위별 실제 핏 라벨
- 사용자 코멘트

### 16.1 전체 핏 기록

`actualFitLabel`은 실제 착용 결과를 기록한다.

해석:

| 피드백 | 엔진 해석 |
| --- | --- |
| `too_small` | 다음 추천에서 조금 더 큰 실측을 선호 |
| `slightly_small` | 다음 추천에서 약간 더 큰 실측을 선호 |
| `good` | offset 없음 |
| `slightly_large` | 다음 추천에서 약간 더 작은 실측을 선호 |
| `too_large` | 다음 추천에서 조금 더 작은 실측을 선호 |

이 값은 현재 fit score의 offset으로 사용하지 않는다.

### 16.2 부위별 피드백 기록

`partFeedback`은 특정 부위의 실제 착용 결과를 측정 항목별로 기록한다.

예:

```json
{
  "chest_width": "too_small",
  "sleeve_length": "good"
}
```

부위별 값도 현재 점수의 offset이나 weight multiplier로 사용하지 않는다.

### 16.3 Feedback Profile 메타데이터

기존 호환성과 오프라인 분석을 위해 최근 피드백은 `feedbackProfile` 메타데이터로 요약될 수 있다.

포함 정보:

- `category`
- `sampleCount`
- `overallSampleCount`
- `partSampleCount`
- `weightedSampleCount`
- `status`
- `measurementOffsets`
- `weightMultipliers`
- `partFeedbackCounts`
- `strategy`

이 프로필은 `result_details.feedbackProfile`에 저장될 수 있지만 `referenceProfile`, `dynamicWeights`, fit score, 추천 사이즈에는 적용되지 않는다. 충분한 검증 전까지 ML 학습과 온라인 개인화에는 사용하지 않는다.

## 17. 결과 메타데이터

추천 결과에는 앱 설명과 디버깅을 위해 다음 메타데이터가 포함될 수 있다.

- `baseWeights`
- `dynamicWeights`
- `referenceVariance`
- `weightingStrategy`
- `referenceProfile`
- `feedbackProfile`
- `scoreExplanation`
- `confidenceBreakdown`
- `allSizeScores`
- `diff`

이 메타데이터는 앱의 수치 기반 추천 이유와 부위별 차이, 내부 진단에 사용한다.
새 메타데이터는 `fit_analysis_results.result_details` JSONB에 저장되며
legacy-tolerant 하다. 과거 row에 `scoreExplanation` 또는
`confidenceBreakdown`이 없어도 저장 결과 조회와 리포트 생성은 기존 필드로
fallback해야 한다.

## 18. 현재 한계

- 신체 치수는 아직 추천 점수에 적극 반영되지 않는다.
- 사용자 피드백은 저장과 오프라인 분석에만 사용되며 온라인 추천 점수에는 반영되지 않는다.
- 브랜드별 사이즈 보정이 없다.
- OCR/URL 파싱 결과의 신뢰도는 내부 confidence 메타데이터에만 반영되며, 추천 점수와 사용자 리포트 서술에는 반영되지 않는다.
- 측정값 단위 변환과 문자열 기반 치수 파싱은 아직 제한적이다.

## 19. ML 기반 확장 방향

피드백 데이터가 충분히 쌓이면 현재 rule-based personalization을 ML 또는 통계 기반 추천으로 확장할 수 있다.

확장 단계:

1. 카테고리별 피드백 통계 집계
2. 사용자별 선호 여유분 추정
3. 브랜드별/상품군별 실측 편차 보정
4. 부위별 민감도 모델링
5. 추천 결과와 실제 피드백 간 오차를 학습 데이터로 축적
6. rule-based score와 ML correction score를 함께 사용하는 hybrid scoring

중요 원칙:

- 충분한 피드백 데이터가 쌓이기 전까지 rule-based 엔진을 기본값으로 유지한다.
- ML 결과도 부위별 설명 가능성을 유지해야 한다.
- 사용자별 데이터는 privacy-first 방식으로 관리한다.
- ML 모델은 추천 사이즈만 바꾸는 것이 아니라 confidence와 설명 품질도 개선해야 한다.

현재 준비된 분석용 데이터 계약은 `docs/fit-engine/HYBRID_SCORING_READINESS.md`에 있다. 이 계약은 future hybrid scoring을 위한 read-only/export 기준이며, ML 학습, prediction serving, shadow recommendation, LLM 기반 점수 계산은 포함하지 않는다.
