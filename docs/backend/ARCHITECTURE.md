# 백엔드 아키텍처

문서 상태: 최신  
기준일: 2026-05-19  
관련 코드: `backend/src/app.ts`, `backend/src/routes.ts`, `backend/src/modules/*`

coordit 백엔드는 Express + TypeScript 기반 REST API입니다. 핵심 역할은 인증된 사용자별 데이터를 Supabase PostgreSQL에 저장하고, 기준 의류 기반 Fit Engine을 실행하는 것입니다.

## 실행 구조

```text
backend/src/
  server.ts              서버 listen
  app.ts                 Express app, middleware, health check
  routes.ts              전체 REST route 등록
  config/
    env.ts               환경변수 로딩/검증
    supabase.ts          Supabase service role client
  middleware/
    auth.middleware.ts   Bearer token 인증
    error.middleware.ts  공통 에러 응답
  modules/
    auth/
    users/
    body-measurements/
    clothing-items/
    clothing-sizes/
    reference-clothing/
    external-products/
    external-product-sizes/
    fit/
    feedback/
    recommendation-logs/
  shared/
    types/
    utils/
```

## 요청 처리 흐름

1. `server.ts`가 `app`을 가져와 `env.port`로 서버를 시작합니다.
2. `app.ts`에서 `cors`, `express.json`, `/health`, `routes`, `errorMiddleware`를 등록합니다.
3. `routes.ts`에서 공개 인증 API를 먼저 선언합니다.
4. `routes.use(authMiddleware)` 이후 보호 API를 선언합니다.
5. controller가 HTTP 요청을 받아 user id와 body를 service에 전달합니다.
6. service가 입력값 정규화와 비즈니스 규칙을 처리합니다.
7. repository 또는 service가 Supabase 쿼리를 실행합니다.
8. 에러는 `errorMiddleware`에서 `{ "message": "..." }` 형식으로 반환됩니다.

## 레이어 역할

| 레이어 | 역할 |
| --- | --- |
| controller | HTTP request/response 처리, `req.user` 확인 |
| service | 요청 body 변환, 비즈니스 규칙, DTO 구성 |
| repository | Supabase table query |
| shared utils | 공통 validation, measurement 처리, category 호환성 |
| fit engine | 순수 추천 점수 계산 |

모든 모듈이 완전히 같은 구조는 아닙니다. `fit` 모듈은 repository 파일 없이 service에서 여러 테이블을 직접 조회하고, `auth` 모듈은 Supabase Auth API를 직접 호출합니다.

## 주요 모듈

| 모듈 | 설명 |
| --- | --- |
| `auth` | 회원가입/로그인, Supabase Auth 연동 |
| `users` | 사용자 public profile 조회/수정 |
| `body-measurements` | 신체 치수 저장/조회 |
| `clothing-items` | 보유 의류 CRUD |
| `clothing-sizes` | 보유 의류 실측값 CRUD |
| `reference-clothing` | 추천 기준 의류 등록/조회/비활성화 |
| `external-products` | 외부 상품 등록/조회/수정 |
| `external-product-sizes` | 외부 상품 사이즈표 CRUD |
| `fit` | 추천 실행, 추천 결과 저장 |
| `feedback` | 추천 결과에 대한 사용자 피드백 |
| `recommendation-logs` | 추천 노출/클릭/구매 로그 |

## 개발 규칙

- 새 보호 API는 `routes.use(authMiddleware)` 이후에 선언합니다.
- 사용자 소유 테이블은 항상 `req.user.id`를 기준으로 조회합니다.
- 클라이언트가 전달한 `user_id`는 신뢰하지 않습니다.
- DB 변경 시 `supabase/schema.sql`, `backend/src/shared/types/database.ts`, repository DTO를 함께 수정합니다.
- 측정값 필드는 현재 snake_case 기준입니다.

## 검증 명령

```bash
cd backend
npm run typecheck
npm run build
```
