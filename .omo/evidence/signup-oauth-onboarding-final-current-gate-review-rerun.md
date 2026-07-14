recommendation: APPROVE
gateStatus: PASS
reviewDate: 2026-07-10
worktree: /Users/insihwan/Documents/Project/coordit/coordit-dev-signup-oauth-onboarding
branch: codex/signup-oauth-onboarding

# Final Current Gate Review Rerun

## originalIntent

Implement backend/DB-only Supabase OAuth onboarding for Google users, while preserving existing email auth and leaving frontend untouched. The endpoint should upsert the Coordit user, require display name plus latest terms/privacy consent, allow optional gender/birth year/body measurements, store optional consent choices, avoid provider-token storage, and keep the schema compatible with future Kakao OAuth.

## desiredOutcome

A Supabase OAuth user can complete onboarding through protected `POST /auth/onboarding` with a real Supabase bearer token. The backend returns the raw stored `UserRow` shape, records versioned consents, creates no body-measurement row when measurements are skipped, updates the existing onboarding-sourced measurement row on retry, documents the backend/API contract honestly, and passes backend verification. External SQL/OAuth QA may remain blocked only if the blocker is explicit and no fake JWT success is claimed.

## userOutcomeReview

PASS. The shipped artifacts satisfy the requested backend/API outcome within the documented external-QA limits.

- Plan state is clean: todos 1-6 and F1-F4 are checked in `.omo/plans/signup-oauth-onboarding.md:86`, `.omo/plans/signup-oauth-onboarding.md:94`, `.omo/plans/signup-oauth-onboarding.md:102`, `.omo/plans/signup-oauth-onboarding.md:110`, `.omo/plans/signup-oauth-onboarding.md:118`, `.omo/plans/signup-oauth-onboarding.md:126`, and `.omo/plans/signup-oauth-onboarding.md:136` through `.omo/plans/signup-oauth-onboarding.md:139`.
- The prior unused-import blocker is fixed: `rg -n "OPTIONAL_CONSENT_KEYS" backend/src/modules/auth/auth-onboarding.controller.ts` returned no output. Controller imports now include `REQUIRED_CONSENT_KEYS` and types only at `backend/src/modules/auth/auth-onboarding.controller.ts:6`.
- The route is protected by existing auth middleware and mounted after it at `backend/src/routes.ts:65` and `backend/src/routes.ts:67`.
- The controller re-verifies the bearer through Supabase Auth and rejects non-Supabase/local fallback tokens before service execution at `backend/src/modules/auth/auth-onboarding.controller.ts:46` and `backend/src/modules/auth/auth-onboarding.controller.ts:109`.
- The response contract intentionally returns raw `UserRow` snake_case fields: controller test asserts `display_name` and `birth_year` at `backend/src/modules/auth/auth-onboarding.controller.test.ts:196`, `backend/src/modules/auth/auth-onboarding.controller.test.ts:200`, and `backend/src/modules/auth/auth-onboarding.controller.test.ts:202`; docs show the same shape at `docs/API_SPEC_MOBILE.md:170` through `docs/API_SPEC_MOBILE.md:179`.
- Docs do not imply frontend implementation was shipped; they explicitly mark the OAuth onboarding section as backend/API contract at `docs/API_SPEC_MOBILE.md:78`.
- Consent validation is enforced in `backend/src/modules/auth/auth-onboarding.parser.ts:117` through `backend/src/modules/auth/auth-onboarding.parser.ts:145`; optional consent handling is non-blocking at `backend/src/modules/auth/auth-onboarding.parser.ts:174` through `backend/src/modules/auth/auth-onboarding.parser.ts:180`.
- `birthYear`/`birth_year` is parsed while `age` is not canonical storage at `backend/src/modules/auth/auth-onboarding.parser.ts:107` through `backend/src/modules/auth/auth-onboarding.parser.ts:110`; docs state the same at `docs/API_SPEC_MOBILE.md:165`.
- Body measurements are skipped when absent and update the existing onboarding-sourced row on retry at `backend/src/modules/auth/auth-onboarding.service.ts:13` through `backend/src/modules/auth/auth-onboarding.service.ts:25` and `backend/src/modules/auth/auth-onboarding.repository.ts:121` through `backend/src/modules/auth/auth-onboarding.repository.ts:160`.
- Schema/migration/index/RLS artifacts include versioned consent tables, idempotent seed rows, indexes, and owner policies at `supabase/migrations/20260707_add_consent_schema.sql:1` through `supabase/migrations/20260707_add_consent_schema.sql:117`.
- No frontend changes are present: `git diff --name-only -- frontend` and `git ls-files --others --exclude-standard frontend` both returned no output. `.omo/evidence/final-final-frontend-diff.txt` is zero bytes.
- No provider-token storage was found in onboarding/schema scope. Search hits for `access_token`/`refresh_token` are docs placeholders and existing email auth response handling in `backend/src/modules/auth/auth.service.ts`, not new onboarding persistence.

## blockers

None.

## checkedArtifactPaths

- `.omo/plans/signup-oauth-onboarding.md`
- `.omo/evidence/final-signup-oauth-onboarding.txt`
- `.omo/evidence/final-final-auth-test.txt`
- `.omo/evidence/final-final-fit-test.txt`
- `.omo/evidence/final-final-typecheck.txt`
- `.omo/evidence/final-final-build.txt`
- `.omo/evidence/final-final-frontend-diff.txt`
- `.omo/evidence/final-final-gate-blocker-audit.txt`
- `.omo/evidence/final-final-git-status.txt`
- `.omo/evidence/signup-oauth-onboarding-final-current-code-review.md`
- `.omo/evidence/signup-oauth-onboarding-final-current-gate-review.md`
- `.omo/evidence/task-5-signup-oauth-onboarding.manualQa.md`
- `.omo/evidence/task-5-signup-oauth-onboarding.backend-green.txt`
- `.omo/evidence/task-5-signup-oauth-onboarding.sql-blocked.txt`
- `.omo/evidence/task-5-signup-oauth-onboarding.http-blocked.txt`
- `.omo/evidence/task-5-signup-oauth-onboarding.adversarial.txt`
- `backend/package.json`
- `backend/src/routes.ts`
- `backend/src/middleware/auth.middleware.ts`
- `backend/src/modules/auth/auth-onboarding.controller.ts`
- `backend/src/modules/auth/auth-onboarding.parser.ts`
- `backend/src/modules/auth/auth-onboarding.repository.ts`
- `backend/src/modules/auth/auth-onboarding.service.ts`
- `backend/src/modules/auth/auth-onboarding.types.ts`
- `backend/src/modules/auth/auth-onboarding.controller.test.ts`
- `backend/src/modules/auth/auth-onboarding.service.test.ts`
- `backend/src/modules/auth/auth-onboarding.validation.test.ts`
- `backend/src/modules/auth/auth-onboarding.test-fixtures.ts`
- `backend/src/shared/types/database.ts`
- `docs/API_SPEC_MOBILE.md`
- `supabase/schema.sql`
- `supabase/indexes.sql`
- `supabase/rls.sql`
- `supabase/migrations/20260707_add_consent_schema.sql`

## verificationPerformed

- Loaded and applied `omo:remove-ai-slops` and `omo:programming`; also consulted the TypeScript programming reference.
- Reviewed the current source, tests, SQL, docs, manual QA matrix, final evidence, and current code-review artifact directly rather than trusting summaries.
- Confirmed the current code-review report includes skill-perspective and overfit/slop coverage in `.omo/evidence/signup-oauth-onboarding-final-current-code-review.md`, including behavior-oriented tests, no deletion-only/tautological coverage, no unnecessary production extraction, and no blocking slop.
- Direct slop pass: no controller `OPTIONAL_CONSENT_KEYS`; no `as any`, `@ts-ignore`, or `@ts-expect-error`; no production debug logging; tests are behavior-oriented around required consent, optional consent, skipped measurement rows, retry updates, auth boundary, and response shape.
- Pure LOC check passed for changed auth TS files: controller 113, parser 170, repository 149, service 82, types 96, controller test 234, service test 123, validation test 136, fixtures 158.
- `git diff --check` exited 0.
- `git diff --name-only -- frontend` exited 0 with no output.
- `git ls-files --others --exclude-standard frontend` exited 0 with no output.
- `wc -c .omo/evidence/final-final-frontend-diff.txt .omo/evidence/final-final-gate-blocker-audit.txt` reported both files as 0 bytes.
- Reran `cd backend && npm run test:auth-onboarding`: exit 0; 17 PASS lines, including validation tests.
- Reran `cd backend && npm run test:fit`: exit 0; fit-score engine tests passed.
- Reran `cd backend && npm run typecheck`: exit 0; `tsc --noEmit` passed.
- Did not rerun `npm run build` because this gate was requested as read-only and `tsc` emits compiled files; verified fresh `.omo/evidence/final-final-build.txt` instead, which shows `npm run build` / `tsc` completed without errors.

## evidenceGaps

- Local `main` is not available as a branch name in this worktree, so `git diff main...HEAD` cannot be used; `origin/main` points at current `HEAD`, and the reviewed implementation is the dirty worktree/untracked plan-scope files.
- Real SQL migration/apply QA remains externally blocked by missing `SUPABASE_DB_URL`, Supabase env, and local SQL tooling. This is recorded honestly in `.omo/evidence/task-5-signup-oauth-onboarding.sql-blocked.txt`.
- Real OAuth HTTP happy-path QA remains externally blocked by missing `SUPABASE_ACCESS_TOKEN` and required backend Supabase env. This is recorded honestly in `.omo/evidence/task-5-signup-oauth-onboarding.http-blocked.txt`.
- No fake JWT/local-token success is claimed as OAuth proof; controller tests only prove fake/local fallback is rejected before service execution.
- Older stale reject artifacts remain in `.omo/evidence`, but the current code-review artifact identifies them as stale and the direct review confirms the current source/evidence is clean.

Final decision: PASS / APPROVE.
