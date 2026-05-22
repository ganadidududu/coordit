# API Flow

문서 상태: 최신  
기준일: 2026-05-22  
관련 코드: `backend/src/routes.ts`, `backend/src/modules/fit/fit.service.ts`

이 문서는 MVP 사용 흐름을 API 호출 순서로 설명합니다.

## 기본 라이프사이클

1. `POST /auth/signup`
2. `POST /auth/login`
3. `POST /clothing-items`
4. `POST /clothing-items/:id/sizes`
5. `POST /reference-clothing`
6. `POST /external-products`
7. `POST /external-products/:id/sizes`
8. `POST /fit/recommend`
9. `GET /fit-analysis-results/recent`
10. `POST /fit-analysis-results/:id/feedback`

## 인증 흐름

1. 사용자가 이메일/비밀번호로 회원가입 또는 로그인합니다.
2. 백엔드는 Supabase Auth session의 access token을 반환합니다.
3. 프론트엔드는 access token을 저장합니다.
4. 보호 API 요청 시 `Authorization: Bearer <token>` 헤더를 붙입니다.
5. `authMiddleware`가 token으로 Supabase user를 확인합니다.
6. 확인된 user id가 이후 모든 DB 쿼리의 user scope가 됩니다.

## 추천 실행 전 필요한 데이터

추천을 실행하려면 아래 데이터가 필요합니다.

| 데이터 | 테이블 | 필요 이유 |
| --- | --- | --- |
| 보유 의류 | `clothing_items` | 기준 의류의 원본 의류 |
| 보유 의류 실측값 | `clothing_sizes` | 기준 측정값 |
| 기준 의류 | `reference_clothing` | 추천 기준 선택 |
| 외부 상품 | `external_products` | 비교 대상 상품 |
| 외부 상품 사이즈표 | `external_product_sizes` | 후보 사이즈 목록 |

## `POST /fit/recommend` 내부 흐름

1. 요청에서 `referenceClothingId` 또는 `referenceClothingIds`를 확인합니다.
2. 활성화된 기준 의류만 조회합니다.
3. 기준 의류와 연결된 보유 의류를 조회합니다.
4. 기준 의류의 실측값을 조회합니다.
5. 외부 상품을 조회합니다.
6. 외부 상품 사이즈표를 조회합니다.
7. 기준 의류와 외부 상품의 카테고리 호환성을 검사합니다.
8. Fit Engine이 각 사이즈 후보의 점수를 계산합니다.
9. 최고 점수 사이즈를 추천합니다.
10. `fit_analysis_results`에 결과를 저장합니다.
11. `recommendation_logs`에 `shown` 이벤트를 저장합니다.
12. 추천 결과를 응답합니다.

다중 기준 의류가 들어오면 기준 의류 간 표준편차를 이용해 `dynamicWeights`를 계산합니다. 변화 폭이 작은 측정 항목은 사용자의 일관된 선호로 보고 가중치를 높이고, 변화 폭이 큰 측정 항목은 상대적으로 낮춥니다.

## 추천 요청 예시

```json
{
  "referenceClothingIds": ["reference-id-1", "reference-id-2"],
  "externalProductId": "external-product-id"
}
```

## 추천 응답 예시

```json
{
  "recommendedSize": "L",
  "fitScore": 92,
  "fitLabel": "good_fit",
  "recommendationConfidence": "high",
  "diff": {
    "shoulder_width": 1,
    "chest_width": 1
  }
}
```

## 실패하기 쉬운 케이스

- 기준 의류가 비활성화되어 있음
- 기준 의류에 연결된 보유 의류가 없음
- 기준 의류에 실측값이 없음
- 외부 상품에 사이즈표가 없음
- 카테고리가 호환되지 않음
- 양쪽에 비교 가능한 측정값이 하나도 없음

## URL/OCR 확장 준비

`external_product_sizes`에는 자동 파싱 확장을 위한 컬럼이 이미 있습니다.

- `raw_size_data`
- `parsing_status`
- `measurement_source`
- `extracted_text`
- `extraction_confidence`

현재 `POST /external-products/from-url`은 mock 상품 데이터를 반환하며, 실제 scraping/OCR 구현은 아직 없습니다.
