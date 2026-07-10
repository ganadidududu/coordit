# Signup OAuth Onboarding Final Full-Diff Code Review

codeQualityStatus: BLOCK
recommendation: REQUEST_CHANGES
reportPath: .omo/evidence/signup-oauth-onboarding-final-full-diff-code-review.md

## Scope

- Worktree: `/Users/insihwan/Documents/Project/coordit/coordit-dev-signup-oauth-onboarding`
- Base used: `origin/main` because local `main` is not present.
- Reviewed current tracked diff for `backend/`, `supabase/`, `docs/`, plus untracked new auth onboarding and migration files.
- Ignored old stale `.omo` review artifacts except to verify the requested evidence/blocker files existed and were honest.

## Skill-Perspective Check

- Ran: loaded `omo:remove-ai-slops` skill criteria.
- Ran: loaded `omo:programming` skill criteria and `references/typescript/README.md`.
- Result: the diff violates the skill perspective through a contract test that locks the raw implementation/database row instead of the documented API response shape. No `as any`, `@ts-ignore`, or `@ts-expect-error` violations were found in changed TS.

## CRITICAL

- None.

## HIGH

1. `POST /auth/onboarding` docs do not match the controller response user shape.
   - Docs promise a camelCase, client-facing `user` object with `displayName` and `birthYear`: `docs/API_SPEC_MOBILE.md:174`.
   - The controller returns `user: result.user` unchanged: `backend/src/modules/auth/auth-onboarding.controller.ts:99`.
   - `CompleteOnboardingResult.user` is `UserRow`: `backend/src/modules/auth/auth-onboarding.types.ts:103`.
   - `UserRow` is database-shaped: `display_name`, `birth_year`, `created_at`, `updated_at`: `backend/src/shared/types/database.ts:30`.
   - The controller test pins the raw row with `user: result.user`, giving false confidence that the public contract matches docs: `backend/src/modules/auth/auth-onboarding.controller.test.ts:204`.
   - Blocker: either map the controller response to the documented camelCase user shape and update the controller test to assert that public contract, or change the docs to the actual raw response shape including snake_case/timestamps. Do not leave them divergent.

## MEDIUM

- None.

## LOW

- None.

## Requested Checks

- Auth onboarding `.ts` pure LOC <= 250: PASS. Largest is `auth-onboarding.controller.test.ts` at 241 pure LOC.
- `completeAuthOnboarding` unused compatibility wrapper/dependency adapter removed: PASS. No `completeAuthOnboarding` or `AuthOnboardingDependencies` hits remain. `completeOnboarding` is actually called by the controller.
- Docs response contract vs controller: FAIL. See HIGH finding.
- No `as any`, `@ts-ignore`, `@ts-expect-error` in changed TS: PASS.
- No provider/access/refresh token storage in changed onboarding/backend schema code: PASS. Existing auth login token return code is outside this change; onboarding changed code stores no provider/access/refresh tokens.
- Evidence exists and was rerun locally:
  - `npm run test:auth-onboarding`: PASS.
  - `npm run test:fit`: PASS.
  - `npm run typecheck`: PASS.
  - `npm run build`: PASS.
- No frontend diff: PASS.
- SQL/OAuth external blockers recorded honestly: PASS. `task-5-signup-oauth-onboarding.sql-blocked.txt` and `task-5-signup-oauth-onboarding.http-blocked.txt` record missing Supabase/database/token prerequisites without leaking secret values.

## Blockers

- Fix the onboarding response contract mismatch between `docs/API_SPEC_MOBILE.md` and `backend/src/modules/auth/auth-onboarding.controller.ts`, and update `backend/src/modules/auth/auth-onboarding.controller.test.ts` so it asserts the chosen public response shape instead of blindly accepting `result.user`.
