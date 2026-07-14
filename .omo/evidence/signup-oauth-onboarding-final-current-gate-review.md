recommendation: REJECT
gateStatus: REJECT
reviewDate: 2026-07-10
worktree: /Users/insihwan/Documents/Project/coordit/coordit-dev-signup-oauth-onboarding
branch: codex/signup-oauth-onboarding

# Final Current Gate Review

## originalIntent

Implement backend/DB-only Supabase Google OAuth onboarding. Do not modify frontend. Require nickname/display name plus terms/privacy consent, allow optional gender/birth year/body measurements to be skipped, remain compatible with future Kakao, and do not store provider tokens.

## desiredOutcome

A Supabase OAuth user can call protected `POST /auth/onboarding` with a real Supabase bearer token. The backend creates/upserts the Coordit user, stores required and optional consent choices, stores optional demographics and onboarding-sourced body measurements only when numeric measurements are supplied, updates the onboarding measurement row on retry, documents the raw snake_case response contract, and passes backend tests/typecheck/build. Real SQL/HTTP checks may be blocked only if recorded honestly.

## userOutcomeReview

The shipped source largely satisfies the user-visible backend outcome:

- No frontend diff was present: `git diff --name-only -- frontend` and `git ls-files --others --exclude-standard frontend` both returned empty output.
- `POST /auth/onboarding` is mounted after `authMiddleware` in `backend/src/routes.ts`.
- The controller re-verifies the bearer token through Supabase Auth and rejects local JWT fallback before calling the onboarding service.
- Docs and controller tests now match the current raw `UserRow` snake_case response contract: `display_name` and `birth_year`.
- Required `terms_of_service` and `privacy_policy` consent checks, optional consent handling, optional measurement skipping, and retry update behavior are covered by auth onboarding tests.
- SQL schema, migration, indexes, and RLS include `consent_versions` and `user_consents` with owner policies and idempotent version seed rows.
- No provider access/refresh token storage was found in changed onboarding/schema files.

The gate still rejects because the artifact/control state is not clean enough for approval under the requested final-gate criteria.

## blockers

1. Final verification wave remains unchecked in the plan.
   - Evidence: `.omo/plans/signup-oauth-onboarding.md:136` through `.omo/plans/signup-oauth-onboarding.md:139` still show `[ ]` for F1-F4.
   - This conflicts with the gate check requiring top-level plan TODOs/final checks to be completed with evidence.

2. Direct `remove-ai-slops` pass found unresolved dead code.
   - Evidence: `backend/src/modules/auth/auth-onboarding.controller.ts:7` imports `OPTIONAL_CONSENT_KEYS`, but `rg -n "\bOPTIONAL_CONSENT_KEYS\b" backend/src/modules/auth/auth-onboarding.controller.ts` only finds the import line.
   - This is a small unused import, but the required slop criteria treat unused imports as dead code. The final gate instructions require rejection when unresolved slop remains.

3. The current code-review report's slop coverage is unsupported by the direct pass.
   - Evidence: `.omo/evidence/signup-oauth-onboarding-final-current-code-review.md:10` says no blocking `remove-ai-slops` violations were found and tests are not tautological/deletion-only.
   - That report missed the unused `OPTIONAL_CONSENT_KEYS` import above, so its "no blocking violations" claim is unsupported.

## checkedArtifactPaths

- `.omo/plans/signup-oauth-onboarding.md`
- `.omo/evidence/signup-oauth-onboarding-final-current-code-review.md`
- `.omo/evidence/signup-oauth-onboarding-code-review.md`
- `.omo/evidence/signup-oauth-onboarding-final-full-diff-code-review.md`
- `.omo/evidence/signup-oauth-onboarding-todo-4-docs-code-review.md`
- `.omo/evidence/final-signup-oauth-onboarding.txt`
- `.omo/evidence/task-5-signup-oauth-onboarding.manualQa.md`
- `.omo/evidence/task-5-signup-oauth-onboarding.backend-green.txt`
- `.omo/evidence/task-5-signup-oauth-onboarding.sql-blocked.txt`
- `.omo/evidence/task-5-signup-oauth-onboarding.http-blocked.txt`
- `.omo/evidence/final-postfix-auth-test.txt`
- `.omo/evidence/final-postfix-fit-test.txt`
- `.omo/evidence/final-postfix-typecheck.txt`
- `.omo/evidence/final-postfix-build.txt`
- `backend/package.json`
- `backend/src/routes.ts`
- `backend/src/modules/auth/auth-onboarding.controller.ts`
- `backend/src/modules/auth/auth-onboarding.parser.ts`
- `backend/src/modules/auth/auth-onboarding.repository.ts`
- `backend/src/modules/auth/auth-onboarding.service.ts`
- `backend/src/modules/auth/auth-onboarding.types.ts`
- `backend/src/modules/auth/auth-onboarding.service.test.ts`
- `backend/src/modules/auth/auth-onboarding.validation.test.ts`
- `backend/src/modules/auth/auth-onboarding.controller.test.ts`
- `backend/src/modules/auth/auth-onboarding.test-fixtures.ts`
- `backend/src/shared/types/database.ts`
- `docs/API_SPEC_MOBILE.md`
- `supabase/schema.sql`
- `supabase/indexes.sql`
- `supabase/rls.sql`
- `supabase/migrations/20260707_add_consent_schema.sql`

## verificationPerformed

- Loaded and applied `omo:remove-ai-slops` and `omo:programming` criteria, including the TypeScript reference entry point.
- `git status --short --branch`: branch is `codex/signup-oauth-onboarding`; source changes are backend/docs/supabase plus untracked onboarding files/evidence.
- `git diff --name-only -- frontend`: PASS, empty.
- `git ls-files --others --exclude-standard frontend`: PASS, empty.
- `wc -l backend/src/modules/auth/auth-onboarding.controller.test.ts`: PASS, exactly 250 physical lines.
- Pure LOC spot check: changed auth TS files are under 250 pure LOC; largest is controller test at 234 pure LOC.
- `cd backend && npm run test:auth-onboarding`: PASS, 17 tests.
- `cd backend && npm run test:fit`: PASS.
- `cd backend && npm run typecheck`: PASS.
- `cd backend && npm run build`: not rerun by this gate because it emits `dist/` and the task is read-only. Current transcripts in `.omo/evidence/final-postfix-build.txt` and `.omo/evidence/task-5-signup-oauth-onboarding.backend-green.txt` show `tsc` exited 0.
- `git diff --check -- <scoped files>`: PASS.
- Secret hygiene scan found placeholders such as `anon-key` / `service-role-key` in tests and missing-env markers in evidence; no real JWT/access token was found.

## previousBlockerStatus

- Docs response mismatch: fixed. Current docs use `display_name` and `birth_year`, and controller test asserts the same raw user row shape.
- Stale REQUEST_CHANGES artifacts: stale artifacts remain at `.omo/evidence/signup-oauth-onboarding-final-full-diff-code-review.md` and `.omo/evidence/signup-oauth-onboarding-todo-4-docs-code-review.md`; the newer current code-review artifact explicitly identifies them as stale. This is evidence debt, not the primary blocker for this gate.
- Unused exported `BodyMeasurementRow`: fixed for the requested concern. No exported generic `BodyMeasurementRow` remains in `backend/src/modules/body-measurements/body-measurements.service.ts`; only the used onboarding-scoped `OnboardingBodyMeasurementRow` exists.
- Controller test physical LOC: fixed at exactly 250 lines.

## evidenceGaps

- Real SQL migration/apply QA remains blocked by missing `SUPABASE_DB_URL`, Supabase env, and local SQL tooling. This is recorded honestly in `.omo/evidence/task-5-signup-oauth-onboarding.sql-blocked.txt`.
- Real OAuth HTTP happy path remains blocked by missing `SUPABASE_ACCESS_TOKEN`; no fake JWT success is claimed. This is recorded honestly in `.omo/evidence/task-5-signup-oauth-onboarding.http-blocked.txt`.
- The plan still has unchecked F1-F4 final verification items despite evidence existing elsewhere.
- The current code-review artifact's slop coverage is incomplete because it missed the unused controller import.

Final decision: REJECT.
