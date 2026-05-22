# 화면과 라우트

문서 상태: 최신  
기준일: 2026-05-22  
기준 코드: `frontend/src/app/*`

현재 프론트엔드에 구현된 화면과 담당 역할을 정리합니다.

## 화면 목록

| Route | 파일 | 역할 |
| --- | --- | --- |
| `/` | `frontend/src/app/page.tsx` | 랜딩 페이지 |
| `/login` | `frontend/src/app/login/page.tsx` | 회원가입/로그인/로그아웃 |
| `/dashboard` | `frontend/src/app/dashboard/page.tsx` | MVP 진행 단계 안내 |
| `/onboarding` | `frontend/src/app/onboarding/page.tsx` | 온보딩 |
| `/wardrobe` | `frontend/src/app/wardrobe/page.tsx` | 보유 의류 등록/목록 |
| `/wardrobe/sizes` | `frontend/src/app/wardrobe/sizes/page.tsx` | 보유 의류 실측값 입력 |
| `/reference` | `frontend/src/app/reference/page.tsx` | 기준 의류 등록/목록 |
| `/external-products` | `frontend/src/app/external-products/page.tsx` | 외부 상품 등록/목록 |
| `/external-products/sizes` | `frontend/src/app/external-products/sizes/page.tsx` | 외부 상품 사이즈표 입력 |
| `/fit-result` | `frontend/src/app/fit-result/page.tsx` | Fit 추천 실행/결과 표시 |

## 핵심 사용 흐름

1. `/login`에서 로그인합니다.
2. `/wardrobe`에서 보유 의류를 등록합니다.
3. `/wardrobe/sizes`에서 보유 의류 실측값을 입력합니다.
4. `/reference`에서 기준 의류를 등록합니다.
5. `/external-products`에서 외부 상품을 등록합니다.
6. `/external-products/sizes`에서 외부 상품 사이즈표를 입력합니다.
7. `/fit-result`에서 기준 의류와 외부 상품을 선택해 추천을 실행합니다.

## 화면별 주요 API

### `/login`

- `POST /auth/signup`
- `POST /auth/login`

### `/wardrobe`

- `POST /clothing-items`
- `GET /clothing-items`
- `PATCH /clothing-items/:id`
- `DELETE /clothing-items/:id`

### `/wardrobe/sizes`

- `GET /clothing-items`
- `POST /clothing-items/:id/sizes`
- `GET /clothing-items/:id/sizes`
- `PATCH /clothing-sizes/:id`
- `DELETE /clothing-sizes/:id`

### `/reference`

- `GET /clothing-items`
- `POST /reference-clothing`
- `GET /reference-clothing`
- `PATCH /reference-clothing/:id`
- `PATCH /reference-clothing/:id/deactivate`

### `/external-products`

- `POST /external-products`
- `POST /external-products/from-url`
- `GET /external-products`
- `PATCH /external-products/:id`

### `/external-products/sizes`

- `GET /external-products`
- `POST /external-products/:id/sizes`
- `GET /external-products/:id/sizes`
- `PATCH /external-product-sizes/:id`
- `DELETE /external-product-sizes/:id`

### `/fit-result`

- `GET /reference-clothing`
- `GET /external-products`
- `POST /fit/recommend`
- `GET /fit-analysis-results/recent`

## UX 보강 후보

- 추천 흐름을 하나의 wizard로 묶기
- 실측값 입력 시 카테고리별 필요한 필드만 강조
- 외부 상품 사이즈표를 table 형태로 여러 row 한 번에 입력
- 추천 결과에서 부위별 차이와 confidence를 더 명확히 표현
- 로그인하지 않은 사용자의 보호 화면 접근 처리 강화
