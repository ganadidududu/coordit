---
slug: signup-oauth-onboarding
status: approved
intent: clear
pending-action: write .omo/plans/signup-oauth-onboarding.md
approach: Backend/DB-only provider-agnostic OAuth onboarding: Supabase OAuth creates/verifies identity, backend stores profile/body-measurement/consent state from a Supabase bearer token, with Google first and Kakao-compatible provider naming.
---

# Draft: signup-oauth-onboarding

## Components (topology ledger)
<!-- Lock the SHAPE before depth. One row per top-level component that can succeed or fail independently. -->
<!-- id | outcome (one line) | status: active|deferred | evidence path -->
AUTH | Google OAuth-backed backend session acceptance and provider-agnostic auth API contract | active | backend/src/modules/auth/auth.service.ts:14, backend/src/middleware/auth.middleware.ts:13
PROFILE | Required nickname plus optional demographic profile stored without frontend edits | active | backend/src/modules/users/users.service.ts:17, supabase/schema.sql:3
BODY | Optional body-measurement onboarding payload supports "skip for now" without blocking account entry | active | backend/src/modules/body-measurements/body-measurements.service.ts:5
CONSENT | Versioned required/optional legal consent records with revocation support | active | supabase/AGENTS.md:24, supabase/schema.sql:3
PROVIDER-FUTURE | Google first, Kakao later without schema/API rewrite | active | Supabase Google/Kakao official docs, 2026-07-07 web research
VERIFY | Backend/DB verification only; no frontend modification or browser QA | active | backend/package.json scripts, routes.ts:61

## Open assumptions (announced defaults)
<!-- Record any default you adopt instead of asking, so the user can veto it at the gate. -->
<!-- assumption | adopted default | rationale | reversible? -->
Frontend scope | Do not edit frontend files; expose backend endpoints/contracts and SQL only | User explicitly said frontend must not be touched | reversible by a later frontend task
OAuth session flow | Frontend/mobile will complete Supabase OAuth and call backend with `Authorization: Bearer <supabase_access_token>` | Existing `authMiddleware` already validates Supabase bearer tokens; avoids backend owning browser redirects while preserving backend/DB scope | reversible but would require frontend callback coordination
Provider model | Do not duplicate Supabase provider identities in app DB; use Supabase auth/identities as identity source and keep app DB focused on onboarding/profile/consent | Avoids schema churn for Google/Kakao and supports account linking semantics Supabase owns | reversible by adding audit mirror later
Age storage | Store `birth_year`, not current age | Existing `users.birth_year` column already exists and does not go stale yearly | reversible with migration/API alias
Gender storage | Keep nullable free-text `gender` with validation allowlist in service layer rather than DB enum | Existing schema has text; avoids hard DB lock while allowing inclusive labels | reversible with enum/check later
Body measurements | Optional onboarding block creates zero or one latest `body_measurements` row when supplied; skipping remains valid | User requested "나중에 입력받기"; existing service supports optional numeric fields | reversible
Consent keys | Required: `terms_of_service`, `privacy_policy`; optional: `fit_data_improvement`, `marketing` | Matches requested required terms and data-use concerns; keeps marketing/data improvement separable | reversible by version rows
Test strategy | Add backend tests for onboarding service/controller behavior plus agent-executed HTTP/SQL QA; existing repo has minimal tests but auth/DB changes need coverage | Auth/DB is high-risk and currently uncovered | reversible only if user asks to accept weaker assurance

## Findings (cited - path:lines)
- Current public auth routes are only email signup/login: `backend/src/routes.ts:61`, `backend/src/routes.ts:62`.
- All protected routes run after `routes.use(authMiddleware)`: `backend/src/routes.ts:64`.
- `authMiddleware` already accepts Supabase access tokens via `supabase.auth.getUser(token)`: `backend/src/middleware/auth.middleware.ts:24`, `backend/src/middleware/auth.middleware.ts:25`.
- Email auth currently creates/upserts `public.users` inside `toAuthResponse`: `backend/src/modules/auth/auth.service.ts:14`, `backend/src/modules/auth/auth.service.ts:23`.
- `users` already stores `display_name`, `gender`, and `birth_year`: `supabase/schema.sql:3`, `supabase/schema.sql:6`, `supabase/schema.sql:7`, `supabase/schema.sql:8`.
- `updateMe` accepts `displayName/display_name`, `gender`, and `birthYear/birth_year`: `backend/src/modules/users/users.controller.ts:27`, `backend/src/modules/users/users.controller.ts:28`, `backend/src/modules/users/users.controller.ts:29`, `backend/src/modules/users/users.controller.ts:30`.
- Body measurements are already user-owned and optional numeric fields: `supabase/schema.sql:13`, `supabase/schema.sql:16`, `supabase/schema.sql:17`, `supabase/schema.sql:18`, `supabase/schema.sql:19`, `supabase/schema.sql:20`, `supabase/schema.sql:21`, `supabase/schema.sql:22`.
- Body measurement creation maps camelCase and snake_case fields: `backend/src/modules/body-measurements/body-measurements.service.ts:10`, `backend/src/modules/body-measurements/body-measurements.service.ts:17`.
- Supabase SQL convention requires live schema changes to include migrations and RLS policies, not only base schema edits: `supabase/AGENTS.md:24`, `supabase/AGENTS.md:43`.
- Supabase Google docs require Google OAuth client configuration, Supabase project callback URL, redirect allow-list, and `signInWithOAuth({ provider: "google", options: { redirectTo } })`; PKCE callback uses `exchangeCodeForSession`. Source: https://supabase.com/docs/guides/auth/social-login/auth-google and https://supabase.com/docs/reference/javascript/auth-signinwithoauth (searched 2026-07-07).
- Supabase Kakao docs use provider `"kakao"`, Kakao REST API key/client secret, Supabase callback URL, Kakao Login redirect URI, and optional email caveat for non-Biz apps. Source: https://supabase.com/docs/guides/auth/social-login/auth-kakao (searched 2026-07-07).
- 개인정보보호위원회 2026 guide list includes current 개인정보 처리방침 작성지침; PIPC guidance says service-contract data can be processed without blanket mandatory consent, and consent should be separated where used. Sources: https://www.pipc.go.kr/np/cop/bbs/selectBoardList.do?bbsId=BS217&mCode=D010030000 and https://www.pipc.go.kr/np/cop/bbs/selectBoardArticle.do?bbsId=BS074&mCode=C020010000&nttId=10566 (searched 2026-07-07).
- Dirty worktree risk: `git status --short` shows untracked `.omo/` and AGENTS files. Plan must not modify unrelated untracked files except its own `.omo/drafts/signup-oauth-onboarding.md` and `.omo/plans/signup-oauth-onboarding.md`.

## Decisions (with rationale)
- Plan will be Architecture tier because it touches auth, DB schema/migrations, legal consent storage, and future OAuth provider extensibility.
- Backend surface will add a protected onboarding endpoint instead of replacing existing email `/auth/signup` and `/auth/login`; this preserves current API compatibility while adding OAuth onboarding.
- The onboarding endpoint will be idempotent: repeated calls with the same Supabase user update profile/demographics, upsert a single onboarding-sourced body measurement row only when measurements are supplied, and upsert consent records by key/version.
- Consent will be versioned in DB so future 약관 changes can require re-acceptance without overwriting historical acceptance.
- Frontend is explicitly out of scope; the plan will define API contracts that frontend/mobile can call later.
- User approved defaults on 2026-07-07: use `birthYear`/`birth_year`, require only `terms_of_service` and `privacy_policy`, and create body measurement rows only when at least one measurement is supplied.

## Scope IN
- Supabase SQL migration(s) for consent versions/user consents and any user-profile metadata needed for onboarding status.
- Updates to `supabase/schema.sql`, `supabase/indexes.sql`, `supabase/rls.sql`, and `backend/src/shared/types/database.ts`.
- Backend auth/onboarding module changes under `backend/src/modules/auth`, `backend/src/modules/users`, and body-measurement reuse as needed.
- Provider-agnostic endpoint contract compatible with Google now and Kakao later.
- Required nickname/display name, optional gender/birth year/body measurements, required consent validation.
- Backend tests, typecheck/build, and agent-executed HTTP/SQL QA plan.

## Scope OUT (Must NOT have)
- No frontend file edits, including login page, callback route, AuthProvider, or UI copy.
- No direct Google Cloud Console, Kakao Developers, or Supabase Dashboard configuration changes by the worker; document env/dashboard prerequisites only.
- No custom password auth redesign or removal of existing email auth.
- No fake OAuth tokens or local JWT bypass as proof of done.
- No broad legal document drafting beyond consent keys/storage/API validation needed for implementation.
- No provider-token storage unless explicitly required later.

## Open questions
- None. User approved the recommended defaults.

## Approval gate
status: approved
approved action: write decision-complete implementation plan to `.omo/plans/signup-oauth-onboarding.md`.
<!-- When exploration is exhausted and unknowns are answered, set status: awaiting-approval. -->
<!-- That durable record is the loop guard: on a later turn read it and resume at the gate instead of re-running exploration. -->
