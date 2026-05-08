# Backend Architecture

coordit backend is an Express + TypeScript API for a reference-clothing-based fit recommendation engine.

## Layering

- controller: parses HTTP input, reads `req.user`, returns API responses.
- service: owns business rules and DTO normalization.
- repository: owns Supabase table queries.
- fit engine: pure scoring functions where possible.

Example module shape:

```text
modules/clothing-items/
  clothing-items.controller.ts
  clothing-items.service.ts
  clothing-items.repository.ts
  clothing-items.types.ts
```

## Auth Flow

1. `POST /auth/signup` or `POST /auth/login` calls Supabase Auth.
2. The backend upserts `public.users`.
3. Frontend stores the Supabase access token.
4. Protected routes pass `Authorization: Bearer <token>`.
5. `auth.middleware.ts` validates the token with `supabase.auth.getUser`.
6. `req.user.id` becomes the user scope for every query.

## Data Ownership

All user-owned tables are filtered by `user_id`. CRUD modules never accept a client-supplied `user_id`; they derive it from `req.user`.

## Fit Persistence

`/fit/recommend` stores:

- `fit_analysis_results`
- `recommendation_logs`

The result detail JSON keeps per-size scores, compared reference ids, part diffs, and explanation details.
