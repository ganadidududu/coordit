# 인증과 보안

문서 상태: 최신  
기준일: 2026-05-19  
관련 코드: `backend/src/middleware/auth.middleware.ts`, `backend/src/config/supabase.ts`, `supabase/rls.sql`

coordit 백엔드는 Supabase Auth access token을 Express middleware에서 검증하고, 검증된 user id를 모든 보호 API의 데이터 범위로 사용합니다.

## 인증 대상

공개 API:

- `GET /health`
- `POST /auth/signup`
- `POST /auth/login`

나머지 API는 `backend/src/routes.ts`에서 `routes.use(authMiddleware)` 이후에 선언되어 있어 인증이 필요합니다.

## 요청 헤더

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

## 인증 미들웨어 흐름

`auth.middleware.ts`는 다음 순서로 동작합니다.

1. `Authorization` 헤더가 있는지 확인합니다.
2. `Bearer ` prefix를 제거해 token을 꺼냅니다.
3. `supabase.auth.getUser(token)`으로 Supabase user를 조회합니다.
4. user가 있으면 `req.user = { id, email }`을 설정합니다.
5. Supabase 검증이 실패하면 `JWT_SECRET` 기반 JWT 검증을 fallback으로 시도합니다.
6. 실패 시 에러를 다음 middleware로 넘깁니다.

## Supabase client

현재 백엔드는 `SUPABASE_SERVICE_ROLE_KEY`로 Supabase client를 생성합니다.

```ts
createClient(env.supabaseUrl, env.supabaseServiceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});
```

이 방식은 서버에서 강력한 권한을 사용할 수 있지만, RLS를 우회할 수 있으므로 코드 레벨 user scope가 매우 중요합니다.

## User scope 규칙

사용자 소유 테이블은 항상 `req.user.id`를 기준으로 접근해야 합니다.

좋은 패턴:

```ts
supabase
  .from("clothing_items")
  .select("*")
  .eq("user_id", userId)
```

단건 조회, 수정, 삭제에서도 `id`만 조건으로 쓰면 안 됩니다.

```ts
supabase
  .from("clothing_items")
  .update(dto)
  .eq("id", id)
  .eq("user_id", userId)
```

## RLS 정책

`supabase/rls.sql`은 다음 테이블에 RLS를 활성화합니다.

- `users`
- `body_measurements`
- `clothing_items`
- `clothing_sizes`
- `reference_clothing`
- `external_products`
- `external_product_sizes`
- `fit_analysis_results`
- `user_feedback`
- `recommendation_logs`

대부분 정책은 `auth.uid() = user_id`입니다. `users`만 `auth.uid() = id`입니다.

## 새 API 보안 체크리스트

- 보호 API라면 `routes.use(authMiddleware)` 이후에 route를 둡니다.
- controller에서 클라이언트 body의 `userId`나 `user_id`를 믿지 않습니다.
- service/repository에는 `req.user.id`에서 나온 userId만 넘깁니다.
- 모든 user-owned query에 `.eq("user_id", userId)`를 넣습니다.
- 외래키로 연결된 자식 리소스도 parent ownership을 확인합니다.
- service role key는 프론트엔드 환경변수에 절대 노출하지 않습니다.

## 현재 보강 필요 사항

- CORS가 현재 `cors()`로 열려 있어 운영 전 origin 제한이 필요합니다.
- 테스트 코드가 없으므로 인증/권한 회귀 테스트가 필요합니다.
- service role key 사용 범위를 장기적으로 재검토할 수 있습니다.
- `JWT_SECRET` fallback 경로가 실제 운영에서 필요한지 정책 결정이 필요합니다.
