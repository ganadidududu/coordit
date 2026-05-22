# 프론트엔드 아키텍처

문서 상태: 최신  
기준일: 2026-05-22  
관련 코드: `frontend/src/app/*`, `frontend/src/lib/*`, `frontend/src/components/*`

coordit 프론트엔드는 Next.js App Router 기반 MVP입니다. 백엔드 Express API와 통신하며, access token을 API client에 주입해 보호 API를 호출합니다.

## 디렉터리 구조

```text
frontend/src/
  app/
    page.tsx
    layout.tsx
    login/page.tsx
    dashboard/page.tsx
    onboarding/page.tsx
    wardrobe/page.tsx
    wardrobe/sizes/page.tsx
    reference/page.tsx
    external-products/page.tsx
    external-products/sizes/page.tsx
    fit-result/page.tsx
  components/
    Button.tsx
    Card.tsx
    ClothingItemCard.tsx
    ExternalProductCard.tsx
    FitScoreResultCard.tsx
    FormSection.tsx
    Input.tsx
    Layout.tsx
    Logo.tsx
    MeasurementComparisonTable.tsx
    MeasurementInputGroup.tsx
    ReferenceClothingCard.tsx
    SizeScoreTable.tsx
    TopBar.tsx
    Footer.tsx
  lib/
    api.ts
    auth-context.tsx
    images.ts
    types.ts
  styles/
    globals.css
```

## API 연결

`frontend/src/lib/api.ts`에서 Axios client를 생성합니다.

```ts
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:4000";
```

`setApiToken(token)`이 Authorization header를 설정하거나 제거합니다.

```ts
Authorization: Bearer <token>
```

## 인증 상태 흐름

`frontend/src/lib/auth-context.tsx`가 인증 상태를 관리합니다.

기본 흐름:

1. 로그인/회원가입 API 호출
2. access token 저장
3. API client header에 token 주입
4. 보호 화면에서 API 호출
5. logout 시 token 제거

## UI 구성 원칙

현재 화면은 실측 기반 핏 추천 MVP를 구현하기 위한 폼과 결과 표시 중심입니다.

- `Layout`으로 공통 페이지 구조를 감쌉니다.
- `Card`, `Button`, `Input`, `FormSection` 등 공통 컴포넌트를 재사용합니다.
- 의류/상품/추천 결과는 전용 카드 컴포넌트로 표시합니다.
- 측정값 입력은 `MeasurementInputGroup` 중심으로 구성됩니다.

## 현재 프론트와 제품 방향 차이

현재 `frontend/src/app/page.tsx` 랜딩 페이지는 AI 옷장, TPO 스타일링, 날씨 큐레이션 등 더 넓은 제품처럼 보이는 문구와 시각 요소가 포함되어 있습니다.

하지만 현재 실제 구현의 중심은 다음입니다.

- 보유 의류 실측 등록
- 기준 의류 선택
- 외부 상품 사이즈표 입력
- 기준 의류와 외부 상품 사이즈표 비교
- 추천 사이즈 결과 확인

따라서 발표/제출/배포 전에 랜딩 페이지 문구를 현재 MVP 범위에 맞게 정리하는 것이 좋습니다.

## 개발 시 주의사항

- API base URL은 `NEXT_PUBLIC_API_BASE_URL`로 바꿀 수 있습니다.
- 보호 API 호출 전 token이 설정되어 있어야 합니다.
- 측정값 필드는 백엔드 기준으로 snake_case를 사용해야 합니다.
- 하의 길이 측정값은 `outseam`을 사용합니다.
- 백엔드 route가 바뀌면 `frontend/src/lib/types.ts`와 화면 호출부를 함께 수정해야 합니다.
- 화면별 데이터 흐름은 `frontend/ROUTES_AND_SCREENS.md`를 참고합니다.
