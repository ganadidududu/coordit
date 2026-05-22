# API Reference

문서 상태: 최신  
기준일: 2026-05-22  
기준 코드: `backend/src/routes.ts`

Base URL: `http://localhost:4000`

보호 API 요청 헤더:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

공통 에러 응답:

```json
{ "message": "error message" }
```

## Public

| Method | Path | 설명 |
| --- | --- | --- |
| `GET` | `/health` | 서버 상태 확인 |
| `POST` | `/auth/signup` | 회원가입 |
| `POST` | `/auth/login` | 로그인 |

## Auth

### `POST /auth/signup`

Supabase Auth 사용자를 만들고 `public.users` 프로필을 보장합니다.

```json
{
  "email": "user@example.com",
  "password": "password123",
  "displayName": "User"
}
```

### `POST /auth/login`

로그인 후 access token과 refresh token을 반환합니다.

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

응답:

```json
{
  "accessToken": "jwt",
  "refreshToken": "token",
  "user": {
    "id": "uuid",
    "email": "user@example.com"
  }
}
```

## Users

| Method | Path | 설명 |
| --- | --- | --- |
| `GET` | `/users/me` | 현재 사용자 프로필 조회 |
| `PATCH` | `/users/me` | 현재 사용자 프로필 수정 |

수정 요청 예:

```json
{
  "displayName": "New Name",
  "gender": "female",
  "birthYear": 1995
}
```

## Body Measurements

| Method | Path | 설명 |
| --- | --- | --- |
| `POST` | `/body-measurements` | 신체 치수 등록 |
| `GET` | `/body-measurements` | 신체 치수 목록 조회 |

요청 예:

```json
{
  "heightCm": 172,
  "weightKg": 64,
  "shoulderWidth": 42,
  "outseam": 100,
  "rawData": {}
}
```

## Clothing Items

| Method | Path | 설명 |
| --- | --- | --- |
| `POST` | `/clothing-items` | 보유 의류 생성 |
| `GET` | `/clothing-items` | 보유 의류 목록 |
| `GET` | `/clothing-items/:id` | 보유 의류 단건 |
| `PATCH` | `/clothing-items/:id` | 보유 의류 수정 |
| `DELETE` | `/clothing-items/:id` | 보유 의류 삭제 |

요청 예:

```json
{
  "name": "Oxford Shirt",
  "brand": "Uniqlo",
  "category": "shirt",
  "fitType": "regular",
  "sizeLabel": "L",
  "notes": "잘 맞는 셔츠"
}
```

## Clothing Sizes

| Method | Path | 설명 |
| --- | --- | --- |
| `POST` | `/clothing-items/:id/sizes` | 보유 의류 실측값 생성 |
| `GET` | `/clothing-items/:id/sizes` | 보유 의류 실측값 목록 |
| `PATCH` | `/clothing-sizes/:id` | 보유 의류 실측값 수정 |
| `DELETE` | `/clothing-sizes/:id` | 보유 의류 실측값 삭제 |

측정값은 현재 snake_case key를 사용합니다.

```json
{
  "sizeLabel": "L",
  "total_length": 73,
  "shoulder_width": 48,
  "chest_width": 57,
  "sleeve_length": 62,
  "outseam": 100
}
```

## Reference Clothing

| Method | Path | 설명 |
| --- | --- | --- |
| `POST` | `/reference-clothing` | 기준 의류 등록 |
| `GET` | `/reference-clothing` | 기준 의류 목록 |
| `GET` | `/reference-clothing/by-category/:category` | 카테고리별 기준 의류 |
| `GET` | `/reference-clothing/:id` | 기준 의류 단건 |
| `PATCH` | `/reference-clothing/:id` | 기준 의류 수정 |
| `PATCH` | `/reference-clothing/:id/deactivate` | 기준 의류 비활성화 |

요청 예:

```json
{
  "clothingItemId": "uuid",
  "nickname": "가장 잘 맞는 셔츠",
  "category": "shirt",
  "fitType": "regular",
  "preferenceScore": 100
}
```

## External Products

| Method | Path | 설명 |
| --- | --- | --- |
| `POST` | `/external-products` | 외부 상품 생성 |
| `POST` | `/external-products/from-url` | URL 기반 mock 상품 생성 |
| `GET` | `/external-products` | 외부 상품 목록 |
| `GET` | `/external-products/:id` | 외부 상품 단건 |
| `PATCH` | `/external-products/:id` | 외부 상품 수정 |

요청 예:

```json
{
  "productName": "Linen Shirt",
  "brand": "Brand",
  "mallName": "29CM",
  "productUrl": "https://example.com",
  "category": "shirt",
  "fitType": "regular"
}
```

`/external-products/from-url`은 현재 실제 크롤링이 아니라 mock 데이터를 반환합니다.

## External Product Sizes

| Method | Path | 설명 |
| --- | --- | --- |
| `POST` | `/external-products/:id/sizes` | 외부 상품 사이즈표 row 생성 |
| `GET` | `/external-products/:id/sizes` | 외부 상품 사이즈표 목록 |
| `PATCH` | `/external-product-sizes/:id` | 외부 상품 사이즈표 row 수정 |
| `DELETE` | `/external-product-sizes/:id` | 외부 상품 사이즈표 row 삭제 |

요청 예:

```json
{
  "sizeLabel": "L",
  "total_length": 73.5,
  "shoulder_width": 49,
  "chest_width": 58,
  "sleeve_length": 63,
  "outseam": 101,
  "parsingStatus": "manual",
  "measurementSource": "manual"
}
```

## Fit Recommendation

| Method | Path | 설명 |
| --- | --- | --- |
| `POST` | `/fit/recommend` | 단일 외부 상품 추천 |
| `POST` | `/fit/recommend/batch` | 여러 외부 상품 추천 |
| `GET` | `/fit-analysis-results/recent` | 최근 추천 결과 20개 |
| `GET` | `/fit-analysis-results` | 최근 추천 결과 20개 |
| `GET` | `/fit-analysis-results/:id` | 추천 결과 단건 |

단일 추천 요청:

```json
{
  "referenceClothingId": "reference-uuid",
  "externalProductId": "external-product-uuid"
}
```

다중 기준 의류 추천 요청:

```json
{
  "referenceClothingIds": ["reference-uuid-1", "reference-uuid-2"],
  "externalProductId": "external-product-uuid"
}
```

응답 주요 필드:

```json
{
  "fitAnalysisResultId": "uuid",
  "recommendedSize": "L",
  "fitScore": 92,
  "fitLabel": "good_fit",
  "recommendationConfidence": "medium",
  "diff": {
    "shoulder_width": 1,
    "chest_width": 2,
    "outseam": 1
  },
  "baseWeights": {},
  "dynamicWeights": {},
  "referenceVariance": {},
  "weightingStrategy": "reference_variance_v1",
  "allSizeScores": [],
  "algorithmVersion": "mvp_rule_v1_2"
}
```

## Feedback

| Method | Path | 설명 |
| --- | --- | --- |
| `POST` | `/fit-analysis-results/:id/feedback` | 추천 결과 피드백 생성 |
| `GET` | `/user-feedback` | 사용자 피드백 목록 |

요청 예:

```json
{
  "purchasedSizeLabel": "L",
  "actualFitRating": 5,
  "actualFitLabel": "good_fit",
  "comment": "잘 맞음"
}
```

## Recommendation Logs

| Method | Path | 설명 |
| --- | --- | --- |
| `GET` | `/recommendation-logs` | 추천 로그 목록 |
| `PATCH` | `/recommendation-logs/:id/click` | 추천 클릭 처리 |
| `PATCH` | `/recommendation-logs/:id/purchase` | 추천 구매 처리 |
