# Fit Report with Ollama 8B Spec

문서 상태: 테스트 브랜치 초안  
기준일: 2026-06-30  
대상 브랜치: `codex/fit-report-ollama-spec`

## 1. 목적

Coordit Fit Score Engine이 계산한 수치 결과를 바탕으로, Ollama 8B LLM이 사용자가 이해하기 쉬운 핏 리포트를 작성하게 한다.

핵심 목표는 다음이다.

- 엔진 수치를 문장에 자연스럽게 녹여낸다.
- 기준 의류 기반으로 계산된 사용자 최적 수치와 구매하려는 의류 수치를 그래프로 비교한다.
- 추천 사이즈, 부위별 차이, confidence, 피드백 보정값을 하나의 리포트로 설명한다.
- LLM은 새로운 수치를 계산하지 않고, 전달된 숫자만 해석한다.

## 2. 핵심 원칙

### 2.1 계산은 Fit Engine, 설명은 LLM

Fit Engine이 담당:

- 기준 의류 기반 가상 핏 프로필
- 피드백 offset
- 피드백 weight multiplier
- 최종 adjusted profile
- 후보 사이즈별 점수
- 추천 사이즈
- 부위별 diff
- confidence

LLM이 담당:

- 수치를 한국어 문장으로 해석
- 사용자에게 중요한 차이를 우선순위화
- 리포트 섹션별 설명 작성
- 구매 판단을 돕는 요약 작성

LLM이 하면 안 되는 것:

- fit score 재계산
- 추천 사이즈 변경
- diff 임의 계산
- 없는 신체/의류 정보 추측
- 숫자 반올림 외 임의 변형

### 2.2 그래프는 앱에서 생성

그래프는 LLM이 생성하지 않는다. 앱 또는 백엔드가 numeric series를 만들고, UI에서 차트로 렌더링한다.

LLM은 그래프를 설명하는 문장만 작성한다.

## 3. 리포트 입력 데이터

리포트 입력은 `POST /fit/recommend` 또는 `GET /fit-analysis-results/:id` 결과를 기반으로 만든다.

### 3.1 필수 엔진 결과

```json
{
  "fitAnalysisResultId": "uuid",
  "recommendedSize": "L",
  "fitScore": 92,
  "fitLabel": "good_fit",
  "fitComment": "L 사이즈를 추천합니다...",
  "recommendationConfidence": "high",
  "diff": {
    "shoulder_width": 1,
    "chest_width": 1,
    "total_length": 0.5,
    "sleeve_length": 0
  },
  "partExplanations": [],
  "partStatuses": {},
  "baseWeights": {},
  "dynamicWeights": {},
  "referenceVariance": {},
  "weightingStrategy": "feedback_adjusted_profile_v1",
  "referenceProfile": {},
  "feedbackProfile": {},
  "allSizeScores": []
}
```

### 3.2 리포트용 추가 메타데이터

LLM 리포트 품질을 위해 앱/백엔드에서 다음 데이터를 함께 구성한다.

```json
{
  "userContext": {
    "displayName": "사용자",
    "preferredFit": "regular",
    "unit": "cm"
  },
  "referenceClothingSummary": [
    {
      "name": "잘 맞는 셔츠",
      "category": "shirt",
      "fitType": "regular",
      "sizeLabel": "L",
      "preferenceScore": 100,
      "measurements": {
        "shoulder_width": 48,
        "chest_width": 57,
        "total_length": 73,
        "sleeve_length": 62
      }
    }
  ],
  "targetProduct": {
    "productName": "Linen Shirt",
    "brand": "Brand",
    "mallName": "29CM",
    "category": "shirt",
    "fitType": "regular",
    "selectedSizeLabel": "L",
    "recommendedSizeLabel": "L"
  }
}
```

현재 API 응답만으로 부족할 수 있는 값:

- 기준 의류 이름
- 기준 의류별 원본 실측값
- 외부 상품명/브랜드/쇼핑몰명
- 사용자가 실제로 구매하려는 사이즈

테스트 단계에서는 앱에서 이미 가지고 있는 목록 데이터를 합쳐 `reportInput`을 만든다. 운영 단계에서는 백엔드가 report용 aggregate endpoint를 제공할 수 있다.

## 4. 기준 수치와 구매 의류 수치

리포트에서 비교할 핵심 수치는 다음이다.

### 4.1 Ideal Fit Numbers

사용자에게 가장 잘 맞는 기준 수치다.

우선순위:

1. `referenceProfile.measurements`
2. `feedbackProfile.measurementOffsets`가 있으면 적용된 adjusted profile
3. fallback: 단일 기준 의류 실측값

엔진 v1.4에서는 최종 비교 기준이 다음이다.

```text
adjustedProfile = referenceProfile.measurements + feedbackProfile.measurementOffsets
```

### 4.2 Current Product Numbers

구매하려는 의류의 실측값이다.

추천 사이즈 기준 비교:

```text
productMeasurement = adjustedProfile + diff
```

단, 사용자가 구매하려는 사이즈가 추천 사이즈와 다르면 해당 사이즈의 실제 `external_product_sizes` row를 직접 사용해야 한다.

### 4.3 Difference

각 부위별 차이다.

```text
diff = productMeasurement - adjustedProfile
```

해석:

- `diff < 0`: 기준보다 작음, 더 타이트할 수 있음
- `diff = 0`: 기준과 동일
- `diff > 0`: 기준보다 큼, 더 여유로울 수 있음

## 5. 그래프 구성

### 5.1 Ideal vs Product Bar Chart

목적: 사용자 최적 수치와 구매 의류 수치를 직접 비교한다.

데이터:

```json
{
  "type": "ideal_vs_product_bar",
  "unit": "cm",
  "series": [
    {
      "measurement": "chest_width",
      "label": "가슴단면",
      "ideal": 58,
      "product": 59,
      "diff": 1,
      "status": "slightly_large"
    }
  ]
}
```

UI:

- x축: 측정 항목
- y축: cm
- series 1: 나에게 맞는 기준 수치
- series 2: 구매 의류 수치

### 5.2 Difference Bar Chart

목적: 어느 부위가 얼마나 차이 나는지 빠르게 보여준다.

데이터:

```json
{
  "type": "difference_bar",
  "unit": "cm",
  "series": [
    {
      "measurement": "chest_width",
      "label": "가슴단면",
      "diff": 1,
      "direction": "larger",
      "status": "slightly_large"
    }
  ]
}
```

UI:

- 0 기준선
- 음수: 기준보다 작음
- 양수: 기준보다 큼

### 5.3 Size Score Ranking

목적: 추천 사이즈가 왜 1위인지 보여준다.

데이터:

```json
{
  "type": "size_score_ranking",
  "series": [
    {
      "sizeLabel": "M",
      "fitScore": 78,
      "fitLabel": "acceptable",
      "weightedFitDistance": 0.72
    },
    {
      "sizeLabel": "L",
      "fitScore": 92,
      "fitLabel": "good_fit",
      "weightedFitDistance": 0.26
    }
  ]
}
```

UI:

- 사이즈별 horizontal bar
- 추천 사이즈 강조
- 1위와 2위 점수 차이 표시

### 5.4 Feedback Adjustment Chart

목적: 피드백이 실제로 어떤 부위를 어떻게 보정했는지 보여준다.

데이터:

```json
{
  "type": "feedback_adjustment",
  "series": [
    {
      "measurement": "chest_width",
      "label": "가슴단면",
      "offset": 1,
      "weightMultiplier": 1.2
    }
  ]
}
```

UI:

- offset cm bar
- weight multiplier badge
- 피드백이 없으면 숨김

## 6. 리포트 섹션

LLM 리포트는 아래 섹션을 기본으로 한다.

### 6.1 한 줄 결론

예:

> 이 상품은 L 사이즈가 가장 적합하며, 기준 의류 대비 가슴과 어깨 차이가 작아 전체적으로 안정적인 핏이 예상됩니다.

포함해야 할 수치:

- 추천 사이즈
- fit score
- confidence

### 6.2 추천 사이즈 판단

설명:

- 왜 해당 사이즈가 추천됐는지
- 1위와 2위 점수 차이
- confidence가 높거나 낮은 이유

### 6.3 나에게 맞는 기준 수치

설명:

- 기준 의류들이 만든 ideal fit profile
- 피드백이 반영된 adjusted profile
- 사용자에게 가장 일관적인 부위

### 6.4 구매 의류와 수치 비교

설명:

- 부위별 ideal vs product
- 가장 차이가 큰 부위
- 착용감 예측

### 6.5 부위별 상세 분석

항목별로 다음을 설명한다.

- 기준 수치
- 상품 수치
- 차이
- 상태
- 예상 착용감

### 6.6 피드백 개인화 설명

피드백이 있을 때만 표시한다.

설명:

- 어떤 피드백이 반영됐는지
- offset이 어디에 적용됐는지
- weight multiplier가 어느 부위를 더 중요하게 만들었는지

### 6.7 주의할 점

설명:

- confidence가 낮은 이유
- 측정값 부족
- 사이즈표 수동 입력/OCR/URL 파싱 신뢰도
- 소재, 신축성, 핏 타입 차이

### 6.8 최종 액션

예:

- 추천 사이즈 구매
- 한 사이즈 업/다운도 함께 확인
- 특정 부위 실측 재확인
- 구매 후 피드백 남기기

## 7. LLM 입력 Payload

Ollama 8B에는 아래처럼 계산 완료된 payload만 전달한다.

```json
{
  "locale": "ko-KR",
  "reportStyle": "concise_but_explanatory",
  "engineVersion": "mvp_rule_v1_4",
  "recommendation": {
    "recommendedSize": "L",
    "fitScore": 92,
    "fitLabel": "good_fit",
    "recommendationConfidence": "high",
    "scoreGapToSecond": 8
  },
  "targetProduct": {
    "productName": "Linen Shirt",
    "brand": "Brand",
    "selectedSizeLabel": "L",
    "recommendedSizeLabel": "L"
  },
  "measurements": [
    {
      "key": "chest_width",
      "label": "가슴단면",
      "ideal": 58,
      "product": 59,
      "diff": 1,
      "unit": "cm",
      "weight": 0.32,
      "tolerance": 1.4,
      "status": "slightly_large"
    }
  ],
  "sizeScores": [
    {
      "sizeLabel": "M",
      "fitScore": 78,
      "fitLabel": "acceptable",
      "weightedFitDistance": 0.72
    },
    {
      "sizeLabel": "L",
      "fitScore": 92,
      "fitLabel": "good_fit",
      "weightedFitDistance": 0.26
    }
  ],
  "feedbackPersonalization": {
    "applied": true,
    "sampleCount": 3,
    "measurementOffsets": {
      "chest_width": 1
    },
    "weightMultipliers": {
      "chest_width": 1.2
    }
  },
  "chartData": {
    "idealVsProduct": [],
    "differenceBar": [],
    "sizeScoreRanking": [],
    "feedbackAdjustment": []
  }
}
```

## 8. Ollama 8B Prompt

### 8.1 System Prompt

```text
너는 Coordit의 핏 리포트 작성자다.
너는 패션 핏 컨설턴트처럼 설명하지만, 반드시 제공된 숫자만 사용한다.
절대 새로운 수치를 계산하거나 추측하지 마라.
추천 사이즈, fit score, confidence는 입력값을 그대로 따른다.
사용자가 이해하기 쉬운 한국어로 짧고 명확하게 작성한다.
수치가 부족하면 부족하다고 말한다.
소재, 신축성, 실제 착용감은 확정하지 말고 가능성으로만 표현한다.
```

### 8.2 User Prompt Template

```text
아래 JSON은 Coordit Fit Score Engine의 계산 결과다.
이 숫자를 바탕으로 한국어 핏 리포트를 작성해라.

요구사항:
1. 추천 사이즈와 fit score를 첫 문단에 포함해라.
2. 기준 수치와 상품 수치를 부위별로 자연스럽게 설명해라.
3. 가장 중요한 차이 2~3개를 우선 설명해라.
4. feedbackPersonalization.applied가 true면 피드백 보정이 어떻게 반영됐는지 설명해라.
5. confidence가 low 또는 medium이면 주의할 점을 분명히 써라.
6. JSON에 없는 숫자는 만들지 마라.
7. 출력은 아래 JSON 형식으로만 해라.

출력 형식:
{
  "title": "...",
  "summary": "...",
  "recommendationReason": "...",
  "fitDnaSummary": "...",
  "measurementAnalysis": [
    {
      "measurement": "...",
      "text": "..."
    }
  ],
  "feedbackPersonalization": "...",
  "cautions": ["..."],
  "nextActions": ["..."]
}

입력 JSON:
{{REPORT_INPUT_JSON}}
```

### 8.3 Ollama 호출 예시

```bash
curl http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:8b",
    "prompt": "...",
    "stream": false,
    "options": {
      "temperature": 0.2,
      "top_p": 0.9
    }
  }'
```

모델 후보:

- `llama3.1:8b`
- `llama3:8b`
- `qwen2.5:7b`

테스트 시작은 `llama3.1:8b` 또는 설치된 8B급 모델로 한다.

## 9. 구현 구조 제안

### 9.1 테스트 단계

현재 테스트 브랜치에서는 `fit-score-tester.html`이 아래 흐름을 한 파일 안에서 수행한다.

1. 기준 의류, 피드백, 상품 사이즈 후보 입력
2. Fit Score Engine v1.4 계산 재현
3. `reportInput` 생성
4. `chartData` 생성
5. Ollama prompt 생성
6. 로컬 Ollama API 호출
7. LLM JSON 응답 파싱
8. 리포트 화면 렌더링
9. Ollama 실패 시 fallback 리포트 표시

테스트 단계에서는 DB 저장 없이 on-demand 생성으로 충분하다.

테스터 기본값:

- URL: `http://localhost:11434/api/generate`
- Model: `llama3.1:8b`
- Temperature: `0.2`
- Stream: `false`

실행 전 확인:

```bash
ollama run llama3.1:8b
```

브라우저에서 직접 Ollama를 호출하므로 로컬 환경에 따라 CORS 설정이 필요할 수 있다.

### 9.2 백엔드 API

1단계 구현에서는 아래 API를 사용한다. 리포트는 DB에 저장하지 않고 요청 시점에 생성해 반환한다.

```text
POST /fit-analysis-results/:id/report
```

목적:

- fit result id 기준으로 report input aggregate 생성
- Ollama 호출
- LLM 응답 검증
- 리포트 반환
- Ollama 실패 시 fallback 리포트 반환

요청:

```json
{
  "selectedSizeLabel": "L",
  "style": "concise_but_explanatory",
  "model": "llama3.1:8b",
  "includeDebug": false
}
```

응답:

```json
{
  "fitAnalysisResultId": "uuid",
  "source": "ollama",
  "modelName": "llama3.1:8b",
  "promptVersion": "fit_report_v1",
  "report": {
    "title": "...",
    "summary": "...",
    "recommendationReason": "...",
    "fitDnaSummary": "...",
    "measurementAnalysis": [],
    "feedbackPersonalization": "...",
    "cautions": [],
    "nextActions": []
  },
  "chartData": {
    "idealVsProduct": [],
    "differenceBar": [],
    "sizeScoreRanking": [],
    "feedbackAdjustment": []
  }
}
```

환경변수:

- `OLLAMA_GENERATE_URL`: 기본값 `http://localhost:11434/api/generate`
- `OLLAMA_MODEL`: 기본값 `llama3.1:8b`

`includeDebug`가 `true`이면 테스트를 위해 `reportInput`과 `prompt`를 응답에 포함한다.

### 9.3 저장 테이블 후보

초기 테스트에서는 저장하지 않는다.

리포트 재조회가 필요해지면 추후 테이블을 고려한다.

```text
fit_reports
```

후보 컬럼:

- `id`
- `user_id`
- `fit_analysis_result_id`
- `model_name`
- `prompt_version`
- `report_json`
- `chart_data`
- `created_at`

## 10. Chart Data Builder

엔진 응답에서 차트 데이터를 만드는 규칙이다.

### 10.1 adjusted profile 계산

엔진 응답의 `referenceProfile.measurements`는 이미 피드백 offset이 적용된 값이다. 따라서 리포트에서는 이를 ideal로 사용한다.

```ts
const ideal = result.referenceProfile.measurements;
```

### 10.2 recommended product measurement 계산

추천 사이즈 기준이면 `diff`로 역산한다.

```ts
const productMeasurement = ideal[key] + result.diff[key];
```

사용자가 선택한 사이즈가 추천 사이즈와 다르면 해당 사이즈의 `external_product_sizes` row를 직접 사용한다.

### 10.3 ideal vs product

```ts
const idealVsProduct = measurementKeys.map((key) => ({
  measurement: key,
  label: labels[key],
  ideal: ideal[key],
  product: productMeasurement[key],
  diff: result.diff[key],
  status: result.partStatuses[key]
}));
```

### 10.4 size score ranking

```ts
const sizeScoreRanking = result.allSizeScores.map((size) => ({
  sizeLabel: size.sizeLabel,
  fitScore: size.fitScore,
  fitLabel: size.fitLabel,
  weightedFitDistance: size.weightedFitDistance,
  recommendationConfidence: size.recommendationConfidence
}));
```

## 11. 화면 구성 제안

리포트 화면은 다음 순서가 좋다.

1. 추천 요약 카드
2. Ideal vs Product 그래프
3. 부위별 diff 그래프
4. 사이즈 점수 ranking
5. LLM 리포트 본문
6. 피드백 개인화 설명
7. 구매 후 피드백 CTA

## 12. 구현 시 주의사항

- Ollama 8B는 긴 JSON을 넣으면 핵심을 놓칠 수 있으므로 payload를 압축한다.
- LLM에 모든 원본 DB row를 주지 말고 report용 summary만 전달한다.
- LLM 응답은 JSON parse를 시도하고 실패하면 fallback 문구를 사용한다.
- 모델 온도는 낮게 유지한다.
- 개인정보와 raw user data는 prompt에 넣지 않는다.
- 그래프 수치는 LLM 응답이 아니라 `chartData`를 기준으로 렌더링한다.

## 13. 테스트 체크리스트

- 추천 사이즈와 LLM 문장 속 사이즈가 일치한다.
- fit score가 입력값과 동일하게 출력된다.
- ideal/product/diff 수치가 그래프와 문장에서 일치한다.
- 피드백 보정이 있을 때만 개인화 설명이 나온다.
- confidence가 low일 때 주의 문구가 나온다.
- LLM이 없는 숫자를 만들어내지 않는다.
- Ollama 서버가 꺼져 있으면 fallback UI가 나온다.

## 14. 향후 ML 기반 분석으로 확장

LLM 리포트는 설명 레이어이고, ML 기반 분석은 추천 계산 레이어다.

장기적으로는 다음 순서로 확장한다.

1. fit result와 user feedback을 분석용 데이터셋으로 축적
2. 카테고리별 실패 패턴 분석
3. 사용자별 선호 여유분 추정
4. 브랜드별/쇼핑몰별 사이즈 편차 모델링
5. OCR/URL parsing confidence를 추천 confidence에 반영
6. rule-based score와 ML correction score를 결합
7. LLM 리포트에는 ML 보정 이유를 설명 가능한 형태로 전달

중요한 점:

- ML은 최종 추천을 보정하되, 왜 보정됐는지 설명 가능해야 한다.
- LLM은 ML 결과를 해석하는 역할이지, 모델 학습이나 점수 계산을 대신하지 않는다.
- 사용자가 납득할 수 있는 부위별 수치 비교는 계속 유지한다.
