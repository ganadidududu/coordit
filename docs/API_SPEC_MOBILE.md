# Coordit Mobile API Spec

문서 상태: 모바일 MVP 기준 정리본  
기준일: 2026-06-25  
Base URL: `http://localhost:4000`

## 1. 문서 목적

이 문서는 모바일 앱 개발자가 Coordit MVP 기능을 구현할 때 필요한 API만 사용자 플로우 중심으로 정리한다.

API 문서는 다음을 설명하지 않는다.

- SQL
- ERD
- 테이블/컬럼 상세
- 인덱스
- RLS 정책 상세
- migration
- repository/service/controller 구조

DB 상세는 `docs/DATABASE_SCHEMA.md`, 추천 알고리즘 상세는 `docs/fit-engine/FIT_ENGINE.md`를 기준으로 한다.

## 2. 공통 규칙

보호 API 요청 헤더:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

공통 에러 응답:

```json
{ "message": "error message" }
```

측정값 규칙:

- 측정값 단위는 cm다.
- 측정값 key는 snake_case를 기준으로 한다.
- 앱 입력에서는 카테고리에 맞는 측정 항목을 우선 노출한다.

주요 모바일 화면:

- `Home`
- `Closet`
- `Fit Lab`
- `Styling`
- `Profile`

## 3. Auth

### 회원가입

| 항목 | 내용 |
| --- | --- |
| 기능명 | 회원가입 |
| 목적 | 신규 사용자를 만들고 기본 프로필을 준비한다. |
| Endpoint | `POST /auth/signup` |
| 필수 입력 | `email`, `password`, `displayName` |
| 주요 반환값 | 사용자 정보, 인증 세션 또는 로그인 가능 상태 |
| 사용 화면 | Auth |

### 로그인

| 항목 | 내용 |
| --- | --- |
| 기능명 | 로그인 |
| 목적 | access token과 refresh token을 받아 보호 API를 호출할 수 있게 한다. |
| Endpoint | `POST /auth/login` |
| 필수 입력 | `email`, `password` |
| 주요 반환값 | `accessToken`, `refreshToken`, `user` |
| 사용 화면 | Auth |

### 인증 상태 확인

| 항목 | 내용 |
| --- | --- |
| 기능명 | 내 프로필 조회 기반 인증 확인 |
| 목적 | 저장된 token이 유효한지 확인하고 앱 진입 여부를 결정한다. |
| Endpoint | `GET /users/me` |
| 필수 입력 | Authorization header |
| 주요 반환값 | 사용자 프로필 |
| 사용 화면 | App bootstrap, Profile |

## 4. Profile

### 내 프로필 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 프로필 조회 |
| 목적 | 사용자 표시 이름과 기본 정보를 가져온다. |
| Endpoint | `GET /users/me` |
| 필수 입력 | Authorization header |
| 주요 반환값 | `id`, `email`, `displayName`, `gender`, `birthYear` |
| 사용 화면 | Home, Profile |

### 내 프로필 수정

| 항목 | 내용 |
| --- | --- |
| 기능명 | 프로필 수정 |
| 목적 | 사용자의 기본 정보를 수정한다. |
| Endpoint | `PATCH /users/me` |
| 필수 입력 | 수정할 프로필 값 |
| 주요 반환값 | 수정된 사용자 프로필 |
| 사용 화면 | Profile |

### 신체 치수 등록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 신체 치수 등록 |
| 목적 | 키, 몸무게, 어깨너비 등 보조 프로필 데이터를 저장한다. |
| Endpoint | `POST /body-measurements` |
| 필수 입력 | 앱에서 입력받은 신체 치수 |
| 주요 반환값 | 저장된 신체 치수 |
| 사용 화면 | Profile |

### 신체 치수 목록 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 신체 치수 조회 |
| 목적 | 사용자가 저장한 신체 치수 이력을 확인한다. |
| Endpoint | `GET /body-measurements` |
| 필수 입력 | Authorization header |
| 주요 반환값 | 신체 치수 목록 |
| 사용 화면 | Profile |

## 5. Wardrobe

Wardrobe API는 모바일 앱의 `Closet` 탭에서 사용한다.

### 보유 의류 등록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 보유 의류 등록 |
| 목적 | 사용자가 이미 가지고 있는 옷을 옷장에 추가한다. |
| Endpoint | `POST /clothing-items` |
| 필수 입력 | `name`, `category`, `sizeLabel` |
| 주요 반환값 | 생성된 의류 |
| 사용 화면 | Closet |

선택 입력:

- `brand`
- `fitType`
- `notes`
- `imageUrl`

### 보유 의류 목록 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 보유 의류 목록 |
| 목적 | Closet에 표시할 사용자의 의류 목록을 가져온다. |
| Endpoint | `GET /clothing-items` |
| 필수 입력 | Authorization header |
| 주요 반환값 | 의류 목록 |
| 사용 화면 | Home, Closet |

### 보유 의류 상세 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 보유 의류 상세 |
| 목적 | 의류 수정, 실측값 입력, 기준 의류 지정 전 상세 정보를 가져온다. |
| Endpoint | `GET /clothing-items/:id` |
| 필수 입력 | `id` |
| 주요 반환값 | 의류 상세 |
| 사용 화면 | Closet |

### 보유 의류 수정

| 항목 | 내용 |
| --- | --- |
| 기능명 | 보유 의류 수정 |
| 목적 | 이름, 브랜드, 카테고리, 사이즈 라벨 등 의류 정보를 수정한다. |
| Endpoint | `PATCH /clothing-items/:id` |
| 필수 입력 | `id`, 수정할 값 |
| 주요 반환값 | 수정된 의류 |
| 사용 화면 | Closet |

### 보유 의류 삭제

| 항목 | 내용 |
| --- | --- |
| 기능명 | 보유 의류 삭제 |
| 목적 | 더 이상 사용하지 않는 보유 의류를 제거한다. |
| Endpoint | `DELETE /clothing-items/:id` |
| 필수 입력 | `id` |
| 주요 반환값 | 삭제 완료 상태 |
| 사용 화면 | Closet |

### 보유 의류 실측값 등록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 보유 의류 실측값 등록 |
| 목적 | 추천 기준으로 사용할 의류 실측값을 저장한다. |
| Endpoint | `POST /clothing-items/:id/sizes` |
| 필수 입력 | `id`, `sizeLabel`, 카테고리별 측정값 |
| 주요 반환값 | 저장된 실측값 |
| 사용 화면 | Closet |

상의 주요 입력:

- `total_length`
- `shoulder_width`
- `chest_width`
- `sleeve_length`

하의 주요 입력:

- `waist_width`
- `hip_width`
- `rise`
- `outseam`

### 보유 의류 실측값 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 보유 의류 실측값 조회 |
| 목적 | 의류별 실측값 입력 상태와 값을 확인한다. |
| Endpoint | `GET /clothing-items/:id/sizes` |
| 필수 입력 | `id` |
| 주요 반환값 | 실측값 목록 |
| 사용 화면 | Closet, Fit Lab |

### 보유 의류 실측값 수정

| 항목 | 내용 |
| --- | --- |
| 기능명 | 보유 의류 실측값 수정 |
| 목적 | 잘못 입력한 실측값을 수정한다. |
| Endpoint | `PATCH /clothing-sizes/:id` |
| 필수 입력 | `id`, 수정할 측정값 |
| 주요 반환값 | 수정된 실측값 |
| 사용 화면 | Closet |

### 보유 의류 실측값 삭제

| 항목 | 내용 |
| --- | --- |
| 기능명 | 보유 의류 실측값 삭제 |
| 목적 | 사용하지 않는 실측값 row를 삭제한다. |
| Endpoint | `DELETE /clothing-sizes/:id` |
| 필수 입력 | `id` |
| 주요 반환값 | 삭제 완료 상태 |
| 사용 화면 | Closet |

## 6. Reference Clothing

Reference Clothing API는 사용자가 잘 맞는 옷을 추천 기준으로 지정할 때 사용한다.

### 기준 의류 등록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 기준 의류 등록 |
| 목적 | 보유 의류 중 잘 맞는 옷을 추천 기준으로 지정한다. |
| Endpoint | `POST /reference-clothing` |
| 필수 입력 | `clothingItemId`, `category`, `fitType`, `preferenceScore` |
| 주요 반환값 | 생성된 기준 의류 |
| 사용 화면 | Closet |

### 기준 의류 목록 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 기준 의류 목록 |
| 목적 | Fit Lab에서 선택할 수 있는 기준 의류 목록을 가져온다. |
| Endpoint | `GET /reference-clothing` |
| 필수 입력 | Authorization header |
| 주요 반환값 | 활성 기준 의류 목록 |
| 사용 화면 | Home, Closet, Fit Lab |

### 카테고리별 기준 의류 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 카테고리별 기준 의류 |
| 목적 | 외부 상품 카테고리와 호환되는 기준 의류만 선택하게 한다. |
| Endpoint | `GET /reference-clothing/by-category/:category` |
| 필수 입력 | `category` |
| 주요 반환값 | 카테고리 기준 의류 목록 |
| 사용 화면 | Fit Lab |

### 기준 의류 상세 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 기준 의류 상세 |
| 목적 | 기준 의류 수정 또는 추천 결과 상세 표시를 위한 정보를 가져온다. |
| Endpoint | `GET /reference-clothing/:id` |
| 필수 입력 | `id` |
| 주요 반환값 | 기준 의류 상세 |
| 사용 화면 | Closet, Fit Lab |

### 기준 의류 수정

| 항목 | 내용 |
| --- | --- |
| 기능명 | 기준 의류 수정 |
| 목적 | 닉네임, fit type, 선호도 점수, 메모를 수정한다. |
| Endpoint | `PATCH /reference-clothing/:id` |
| 필수 입력 | `id`, 수정할 값 |
| 주요 반환값 | 수정된 기준 의류 |
| 사용 화면 | Closet |

### 기준 의류 비활성화

| 항목 | 내용 |
| --- | --- |
| 기능명 | 기준 의류 비활성화 |
| 목적 | 추천 기준에서 제외하되 원본 의류 데이터는 유지한다. |
| Endpoint | `PATCH /reference-clothing/:id/deactivate` |
| 필수 입력 | `id` |
| 주요 반환값 | 비활성화된 기준 의류 |
| 사용 화면 | Closet |

## 7. Fit Lab

Fit Lab은 외부 상품과 사용자의 기준 의류를 비교해 추천 사이즈를 도출하는 모바일 핵심 화면이다.

### 7.1 Fit Lab 개념

#### 핏 DNA

핏 DNA는 사용자가 잘 맞는다고 선택한 기준 의류들의 실측값을 모아 만든 개인 핏 프로필이다. 단일 기준 의류일 때는 해당 의류가 기준이 되고, 다중 기준 의류일 때는 여러 기준 의류를 종합해 가상 기준 프로필을 만든다.

#### 부위별 중요도

상의와 하의는 서로 다른 측정 항목을 중요하게 본다. 예를 들어 상의는 어깨너비와 가슴단면이 중요하고, 하의는 허리단면과 바깥기장이 중요하다.

#### 표준편차 분석

여러 기준 의류에서 특정 부위의 측정값이 일관되면 사용자의 선호가 명확한 부위로 해석한다. Fit Lab은 이런 항목의 중요도를 높여 추천 정확도를 보정한다.

#### 기준 의류 통계

다중 기준 의류 추천에서는 기준 의류 간 중심값, 편차, 항목별 표본 수를 활용한다. 앱은 이를 추천 결과의 설명, 신뢰도, 부위별 차이 표시로 활용할 수 있다.

#### 추천 신뢰도

추천 신뢰도는 비교 가능한 측정값 수, 최종 점수, 1등과 2등 사이즈의 점수 차이, 기준 데이터의 충분성 등을 반영한다.

### 외부 상품 등록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 외부 상품 등록 |
| 목적 | 구매하려는 쇼핑몰 상품을 Fit Lab에 추가한다. |
| Endpoint | `POST /external-products` |
| 필수 입력 | `productName`, `category` |
| 주요 반환값 | 생성된 외부 상품 |
| 사용 화면 | Fit Lab |

선택 입력:

- `brand`
- `mallName`
- `productUrl`
- `fitType`
- `imageUrl`

### URL 기반 상품 생성

| 항목 | 내용 |
| --- | --- |
| 기능명 | URL 기반 상품 생성 |
| 목적 | 상품 URL로 외부 상품을 빠르게 생성한다. |
| Endpoint | `POST /external-products/from-url` |
| 필수 입력 | `productUrl` |
| 주요 반환값 | 생성된 외부 상품 |
| 사용 화면 | Fit Lab |

현재 이 기능은 실제 크롤링이 아니라 mock 상품 생성이다.

### 외부 상품 목록 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 외부 상품 목록 |
| 목적 | Fit Lab에서 선택할 상품 목록을 가져온다. |
| Endpoint | `GET /external-products` |
| 필수 입력 | Authorization header |
| 주요 반환값 | 외부 상품 목록 |
| 사용 화면 | Home, Fit Lab |

### 외부 상품 상세 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 외부 상품 상세 |
| 목적 | 상품 수정, 사이즈표 입력, 추천 실행 전 상세 정보를 가져온다. |
| Endpoint | `GET /external-products/:id` |
| 필수 입력 | `id` |
| 주요 반환값 | 외부 상품 상세 |
| 사용 화면 | Fit Lab |

### 외부 상품 수정

| 항목 | 내용 |
| --- | --- |
| 기능명 | 외부 상품 수정 |
| 목적 | 상품명, 브랜드, URL, 카테고리 등을 수정한다. |
| Endpoint | `PATCH /external-products/:id` |
| 필수 입력 | `id`, 수정할 값 |
| 주요 반환값 | 수정된 외부 상품 |
| 사용 화면 | Fit Lab |

### 외부 상품 사이즈표 등록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 상품 사이즈표 row 등록 |
| 목적 | 외부 상품의 사이즈별 실측값을 저장한다. |
| Endpoint | `POST /external-products/:id/sizes` |
| 필수 입력 | `id`, `sizeLabel`, 카테고리별 측정값 |
| 주요 반환값 | 저장된 사이즈표 row |
| 사용 화면 | Fit Lab |

### 외부 상품 사이즈표 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 상품 사이즈표 조회 |
| 목적 | 추천 실행에 사용할 후보 사이즈 목록을 가져온다. |
| Endpoint | `GET /external-products/:id/sizes` |
| 필수 입력 | `id` |
| 주요 반환값 | 사이즈표 row 목록 |
| 사용 화면 | Fit Lab |

### 외부 상품 사이즈표 수정

| 항목 | 내용 |
| --- | --- |
| 기능명 | 상품 사이즈표 row 수정 |
| 목적 | 잘못 입력한 외부 상품 측정값을 수정한다. |
| Endpoint | `PATCH /external-product-sizes/:id` |
| 필수 입력 | `id`, 수정할 측정값 |
| 주요 반환값 | 수정된 사이즈표 row |
| 사용 화면 | Fit Lab |

### 외부 상품 사이즈표 삭제

| 항목 | 내용 |
| --- | --- |
| 기능명 | 상품 사이즈표 row 삭제 |
| 목적 | 사용하지 않는 사이즈 row를 삭제한다. |
| Endpoint | `DELETE /external-product-sizes/:id` |
| 필수 입력 | `id` |
| 주요 반환값 | 삭제 완료 상태 |
| 사용 화면 | Fit Lab |

## 8. Product Analysis

Product Analysis는 외부 상품 정보를 자동으로 가져오거나 분석하는 확장 영역이다.

현재 MVP에서 실제 자동 분석은 제한적이다.

### URL 상품 분석

| 항목 | 내용 |
| --- | --- |
| 기능명 | URL 상품 분석 |
| 목적 | 상품 URL을 기반으로 상품 정보를 생성하는 진입점을 제공한다. |
| Endpoint | `POST /external-products/from-url` |
| 필수 입력 | `productUrl` |
| 주요 반환값 | mock 기반 외부 상품 |
| 사용 화면 | Fit Lab |

향후 확장:

- 상품명 자동 추출
- 브랜드/쇼핑몰명 자동 추출
- 사이즈표 텍스트 파싱
- 사이즈표 이미지 OCR
- 추출 신뢰도 반환

## 9. Fit Recommendation

### 단일 기준 의류 추천

| 항목 | 내용 |
| --- | --- |
| 기능명 | 단일 기준 의류 추천 |
| 목적 | 하나의 기준 의류와 외부 상품 사이즈표를 비교해 추천 사이즈를 계산한다. |
| Endpoint | `POST /fit/recommend` |
| 필수 입력 | `referenceClothingId`, `externalProductId` |
| 주요 반환값 | 추천 사이즈, fit score, fit label, confidence, 부위별 차이, 사이즈별 점수, feedback profile |
| 사용 화면 | Fit Lab |

### 다중 기준 의류 추천

| 항목 | 내용 |
| --- | --- |
| 기능명 | 다중 기준 의류 추천 |
| 목적 | 여러 기준 의류로 사용자의 핏 DNA를 만들고 외부 상품의 최적 사이즈를 추천한다. |
| Endpoint | `POST /fit/recommend` 또는 `POST /fit/recommend/batch` |
| 필수 입력 | `referenceClothingIds`, `externalProductId` |
| 주요 반환값 | 추천 사이즈, fit score, confidence, 기준 의류 통계, 피드백 보정값, 부위별 차이, 사이즈별 점수 |
| 사용 화면 | Fit Lab |

추천 결과의 `feedbackProfile`은 최근 같은 카테고리 피드백이 있을 때만 포함된다.

### 최근 추천 결과 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 최근 추천 결과 |
| 목적 | Home과 Styling에서 최근 추천 이력을 보여준다. |
| Endpoint | `GET /fit-analysis-results/recent` |
| 필수 입력 | Authorization header |
| 주요 반환값 | 최근 추천 결과 목록 |
| 사용 화면 | Home, Styling |

### 추천 결과 상세 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 추천 결과 상세 |
| 목적 | 추천 사이즈, 부위별 차이, 후보 사이즈 점수를 다시 확인한다. |
| Endpoint | `GET /fit-analysis-results/:id` |
| 필수 입력 | `id` |
| 주요 반환값 | 추천 결과 상세 |
| 사용 화면 | Fit Lab, Styling |

## 10. Feedback

### 추천 결과 피드백 등록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 추천 피드백 등록 |
| 목적 | 실제 구매/착용 후 추천 결과가 맞았는지 저장하고 다음 추천의 사용자별 보정값으로 사용한다. |
| Endpoint | `POST /fit-analysis-results/:id/feedback` |
| 필수 입력 | `id`, `actualFitLabel` |
| 주요 반환값 | 저장된 피드백 |
| 사용 화면 | Styling, Fit Lab result |

선택 입력:

- `purchasedSizeLabel`
- `actualFitRating`
- `partFeedback`
- `comment`
- `rawData`

`actualFitLabel` 값:

- `too_small`
- `slightly_small`
- `good`
- `slightly_large`
- `too_large`

`partFeedback`은 측정 항목별 실제 핏을 저장한다.

```json
{
  "purchasedSizeLabel": "L",
  "actualFitRating": 4,
  "actualFitLabel": "slightly_small",
  "partFeedback": {
    "chest_width": "too_small",
    "sleeve_length": "good"
  },
  "comment": "가슴은 작고 소매는 괜찮았음"
}
```

엔진 반영:

- MVP+1: `actualFitLabel`로 카테고리별 전체 선호 여유분을 계산한다.
- MVP+2: `partFeedback`으로 부위별 offset과 weight multiplier를 계산한다.
- 다음 추천 실행 시 같은 카테고리의 최근 피드백이 `feedbackProfile`로 요약되어 추천 결과에 반영된다.

### 사용자 피드백 목록 조회

| 항목 | 내용 |
| --- | --- |
| 기능명 | 피드백 목록 |
| 목적 | 사용자가 남긴 피드백 이력을 확인한다. |
| Endpoint | `GET /user-feedback` |
| 필수 입력 | Authorization header |
| 주요 반환값 | 피드백 목록 |
| 사용 화면 | Styling, Profile |

### 추천 클릭 기록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 추천 클릭 기록 |
| 목적 | 사용자가 추천 결과 또는 상품 링크를 눌렀는지 기록한다. |
| Endpoint | `PATCH /recommendation-logs/:id/click` |
| 필수 입력 | `id` |
| 주요 반환값 | 갱신된 추천 로그 |
| 사용 화면 | Fit Lab, Styling |

### 추천 구매 기록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 추천 구매 기록 |
| 목적 | 사용자가 추천 결과를 구매로 연결했는지 기록한다. |
| Endpoint | `PATCH /recommendation-logs/:id/purchase` |
| 필수 입력 | `id` |
| 주요 반환값 | 갱신된 추천 로그 |
| 사용 화면 | Styling |

## 11. 모바일 MVP 추가 후보 API

아래 API는 현재 구조에서 앱 개발 편의를 위해 추가를 검토할 수 있다. 현재 구현된 API가 아니라 후보로 관리한다.

### Home 요약

| 항목 | 내용 |
| --- | --- |
| 기능명 | Home 요약 |
| 목적 | Home 카드에 필요한 상태를 한 번에 가져온다. |
| Endpoint | `GET /app/home` |
| 필수 입력 | Authorization header |
| 주요 반환값 | 보유 의류 수, 기준 의류 수, 외부 상품 수, 최근 결과, 다음 액션 |
| 사용 화면 | Home |

### 추천 준비 상태

| 항목 | 내용 |
| --- | --- |
| 기능명 | 추천 준비 상태 확인 |
| 목적 | Fit Lab에서 추천 실행 전 부족한 데이터를 서버 기준으로 확인한다. |
| Endpoint | `GET /fit/readiness` |
| 필수 입력 | 선택한 기준 의류 ID, 외부 상품 ID |
| 주요 반환값 | 추천 가능 여부, 부족한 데이터 목록 |
| 사용 화면 | Home, Fit Lab |

### 사이즈표 일괄 등록

| 항목 | 내용 |
| --- | --- |
| 기능명 | 사이즈표 일괄 등록 |
| 목적 | 모바일에서 여러 사이즈 row를 한 번에 저장한다. |
| Endpoint | `POST /external-products/:id/sizes/bulk` |
| 필수 입력 | `id`, `sizes` |
| 주요 반환값 | 저장된 사이즈표 row 목록 |
| 사용 화면 | Fit Lab |

### 카테고리 메타데이터

| 항목 | 내용 |
| --- | --- |
| 기능명 | 카테고리 메타데이터 |
| 목적 | 앱이 카테고리별 측정 필드와 fit type을 서버에서 가져온다. |
| Endpoint | `GET /categories` |
| 필수 입력 | 없음 또는 Authorization header |
| 주요 반환값 | 카테고리, fit type, 측정 필드 |
| 사용 화면 | Closet, Fit Lab |
