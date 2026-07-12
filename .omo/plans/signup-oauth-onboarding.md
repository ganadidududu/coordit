# signup-oauth-onboarding - Work Plan

## TL;DR (For humans)
**What you'll get:** Google login users can complete backend onboarding by saving a nickname, optional gender/birth year/body measurements, and required terms/privacy consent. The database will remember which consent version was accepted, and the same backend shape will be ready for Kakao later.

**Why this approach:** Supabase should own OAuth identities and provider-specific login complexity, while Coordit owns app profile, onboarding status, measurements, and consent records. This keeps the backend stable when Kakao is added and avoids touching the frontend now.

**What it will NOT do:** It will not edit frontend files, build OAuth buttons/callback pages, configure Google/Kakao dashboards, store provider tokens, or remove the existing email auth routes.

**Effort:** Medium
**Risk:** Medium - auth plus schema changes need careful migration/RLS and real token-backed endpoint QA.
**Decisions to sanity-check:** Use `birthYear` instead of age; require only terms/privacy consent; create body measurement rows only when measurements are supplied.

Your next move: start work with `$start-work .omo/plans/signup-oauth-onboarding.md`, or request a high-accuracy plan review first. Full execution detail follows below.

---

> TL;DR (machine): Medium-risk backend/DB auth onboarding plan: add consent schema, provider-agnostic protected onboarding endpoint, optional measurements, tests, SQL/HTTP QA, no frontend edits.

## Scope
### Must have
- Add a backend/DB-only signup onboarding system for Supabase OAuth users.
- Preserve existing email `/auth/signup` and `/auth/login` behavior.
- Add a protected `POST /auth/onboarding` endpoint that requires `Authorization: Bearer <supabase_access_token>`.
- Endpoint must create/upsert `public.users` for the Supabase auth user and require `displayName`/nickname.
- Endpoint must accept optional `gender` and `birthYear`/`birth_year`; do not accept mutable `age` as canonical storage.
- Endpoint must accept optional body measurements; if none are supplied, create no `body_measurements` row.
- Endpoint must be safe to retry: when body measurements are supplied during onboarding, update the user's existing onboarding-sourced measurement row when present, otherwise insert one row with `raw_data.source = "onboarding"`.
- Endpoint must require latest accepted `terms_of_service` and `privacy_policy` consent records.
- Endpoint must accept optional `fit_data_improvement` and `marketing` consents without blocking onboarding.
- Store consent records with key, version, required flag, accepted/revoked timestamps, IP/user-agent audit metadata where available.
- Make consent schema/provider contract compatible with future Kakao OAuth.
- Update Supabase base schema, migration, indexes, RLS, backend DB types, backend services/controllers/routes, and backend docs/API docs.
- Add focused backend tests or executable TypeScript test scripts for validation and persistence behavior.
- Verify with backend typecheck/build and agent-executed SQL/HTTP QA.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do not edit anything under `frontend/`.
- Do not add a frontend login button, callback route, AuthProvider change, or UI copy.
- Do not configure Google Cloud Console, Kakao Developers, or Supabase Dashboard directly.
- Do not store Google/Kakao provider access tokens or refresh tokens in Coordit tables.
- Do not mirror Supabase `auth.identities` unless a later task explicitly asks for provider audit mirroring.
- Do not replace existing email/password auth in this task.
- Do not create empty body-measurement rows for skipped onboarding.
- Do not require optional fit-data improvement or marketing consent.
- Do not use fake local JWT fallback as proof that Supabase OAuth works.
- Do not weaken or skip existing tests.
- Do not modify unrelated untracked files currently visible in the worktree.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: TDD for backend service/controller validation, then integration-style SQL/HTTP QA. Add the smallest executable test script that can go RED before the implementation and GREEN after, following the existing `tsx` direct-test style in `backend/package.json`.
- RED evidence: capture a failing run before production changes, for example `cd backend && npm run test:auth-onboarding`, with failures showing missing consent validation/onboarding endpoint.
- GREEN evidence: capture the same test passing after implementation.
- Static evidence: `cd backend && npm run typecheck` and `cd backend && npm run build`.
- SQL evidence: apply/parse migration in a disposable/local Supabase-compatible database when available; otherwise run a syntax-aware `psql --single-transaction --set ON_ERROR_STOP=1` against the configured dev DB only if credentials are present, and record if DB-backed migration QA is blocked by missing secrets.
- HTTP evidence: run the backend server against a real Supabase project/dev instance and call the onboarding endpoint with a real Supabase access token produced by Supabase Auth test setup. If no real token can be generated because credentials/provider config are absent, the worker must report that as blocked for real-surface OAuth QA and still provide unit/type/build evidence; do not substitute fake JWT success for OAuth proof.
- Evidence paths:
  - `.omo/evidence/task-1-signup-oauth-onboarding.schema-red.txt`
  - `.omo/evidence/task-1-signup-oauth-onboarding.schema-green.txt`
  - `.omo/evidence/task-2-signup-oauth-onboarding.service-red.txt`
  - `.omo/evidence/task-2-signup-oauth-onboarding.service-green.txt`
  - `.omo/evidence/task-3-signup-oauth-onboarding.http.txt`
  - `.omo/evidence/task-4-signup-oauth-onboarding.docs.txt`
  - `.omo/evidence/final-signup-oauth-onboarding.txt`

## Execution strategy
### Parallel execution waves
- Wave 1: Schema and backend contract characterization. Create failing tests first, then add SQL/types/services.
- Wave 2: Endpoint wiring, docs, and backend verification. Can begin after schema/types land.
- Wave 3: Real-surface SQL/HTTP QA, final audits, and cleanup receipts.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1. Consent schema and DB types | none | 2, 3, 5 | none |
| 2. Onboarding service contract and tests | 1 | 3, 5 | 4 after contracts are named |
| 3. Protected onboarding controller/route | 1, 2 | 5, F3 | 4 |
| 4. Backend/API documentation | 1, 2 | F4 | 3 |
| 5. SQL/HTTP verification harness | 1, 2, 3 | final verification | none |
| 6. Final cleanup and evidence index | 1-5 | final handoff | none |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [x] 1. Add versioned consent schema, migration, indexes, RLS, and backend DB types
  What to do / Must NOT do: Add `consent_versions` and `user_consents` to `supabase/schema.sql`; add a timestamped migration under `supabase/migrations/` after `20260629_add_part_feedback_to_user_feedback.sql`; add indexes in `supabase/indexes.sql`; add RLS enablement and policies in `supabase/rls.sql`; update `backend/src/shared/types/database.ts` with exact row interfaces. Seed default version rows for `terms_of_service`, `privacy_policy`, `fit_data_improvement`, and `marketing` in the migration or a clearly documented idempotent insert section. Must not add provider-token columns or frontend-facing schema files.
  Parallelization: Wave 1 | Blocked by: none | Blocks: 2, 3, 5
  References (executor has NO interview context - be exhaustive): `supabase/AGENTS.md:24`, `supabase/AGENTS.md:43`, `supabase/schema.sql:3`, `supabase/rls.sql:12`, `backend/src/shared/types/database.ts:20`
  Acceptance criteria (agent-executable): `rg -n "consent_versions|user_consents|terms_of_service|privacy_policy" supabase backend/src/shared/types/database.ts` shows schema, migration, indexes/RLS, and TS types; SQL migration is idempotent for version seed rows; user consent RLS uses `auth.uid() = user_id`.
  QA scenarios (name the exact tool + invocation): Happy: `cd /Users/insihwan/Documents/Project/coordit/coordit-dev-signup-oauth-onboarding && rg -n "create table public.consent_versions|create table public.user_consents|enable row level security|terms_of_service|privacy_policy" supabase backend/src/shared/types/database.ts > .omo/evidence/task-1-signup-oauth-onboarding.schema-green.txt`, PASS if all expected lines exist. Failure: before schema implementation, run the same command to `.omo/evidence/task-1-signup-oauth-onboarding.schema-red.txt`, PASS as RED if it exits nonzero or lacks required tables/keys.
  Commit: N during execution | Proposed commit label: feat(auth): add consent schema for oauth onboarding

- [x] 2. Add backend onboarding service with required nickname, optional demographics, optional measurements, and consent validation
  What to do / Must NOT do: Create or extend backend service code so a Supabase-authenticated user can be onboarded using `{ displayName, gender?, birthYear?, bodyMeasurements?, consents }`. Reuse `upsertUserProfile` and `createBodyMeasurementForUser` where sensible, but prevent empty measurement rows. If `bodyMeasurements` contains at least one numeric value, update the user's latest `body_measurements` row where `raw_data->>'source' = 'onboarding'`; if none exists, insert one with `raw_data.source = "onboarding"`. Validate latest required consents by key/version and reject missing or false `terms_of_service` / `privacy_policy`. Accept optional `fit_data_improvement` and `marketing` as accepted or declined. Store IP/user-agent when the controller passes them. Must not require body measurements, gender, or birth year.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 3, 5
  References (executor has NO interview context - be exhaustive): `backend/src/modules/auth/auth.service.ts:14`, `backend/src/modules/auth/auth.service.ts:23`, `backend/src/modules/users/users.service.ts:17`, `backend/src/modules/body-measurements/body-measurements.service.ts:5`, `backend/src/shared/utils/request.ts:16`, `backend/src/shared/utils/request.ts:27`
  Acceptance criteria (agent-executable): Add `backend/src/modules/auth/auth-onboarding.test.ts` or equivalent direct `tsx` test and a package script such as `test:auth-onboarding`; test covers successful required-consent onboarding, rejection when required consent is missing/false, skip-body-measurements creating no row, and retry with body measurements updating the existing onboarding-sourced row rather than inserting duplicates.
  QA scenarios (name the exact tool + invocation): Failure: before production service implementation, run `cd /Users/insihwan/Documents/Project/coordit/coordit-dev-signup-oauth-onboarding/backend && npm run test:auth-onboarding > ../.omo/evidence/task-2-signup-oauth-onboarding.service-red.txt 2>&1`, PASS as RED if it fails for missing behavior. Happy: after implementation, rerun `cd /Users/insihwan/Documents/Project/coordit/coordit-dev-signup-oauth-onboarding/backend && npm run test:auth-onboarding > ../.omo/evidence/task-2-signup-oauth-onboarding.service-green.txt 2>&1`, PASS if exit 0 and test names show the required behaviors.
  Commit: N during execution | Proposed commit label: feat(auth): add oauth onboarding service

- [x] 3. Add protected backend onboarding route and response contract
  What to do / Must NOT do: Add controller(s) under `backend/src/modules/auth` or a new narrowly scoped onboarding module following existing controller/service patterns. Wire exactly `POST /auth/onboarding` after `routes.use(authMiddleware)` so it requires a Supabase bearer token. Response must use HTTP 200 for the idempotent completion call and include user profile, consent status summary, `onboardingComplete: true`, and whether body measurements were saved. Preserve public `/auth/signup` and `/auth/login`. Must not add any frontend callback logic.
  Parallelization: Wave 2 | Blocked by: 1, 2 | Blocks: 5
  References (executor has NO interview context - be exhaustive): `backend/src/routes.ts:61`, `backend/src/routes.ts:64`, `backend/src/modules/auth/auth.controller.ts:5`, `backend/src/modules/users/users.controller.ts:19`, `backend/src/modules/body-measurements/body-measurements.controller.ts:6`, `backend/src/middleware/auth.middleware.ts:24`
  Acceptance criteria (agent-executable): `cd backend && npm run test:auth-onboarding && npm run typecheck` exits 0; route is mounted after auth middleware; route rejects missing bearer token via existing middleware.
  QA scenarios (name the exact tool + invocation): Happy: with backend running and a real Supabase access token in `$SUPABASE_ACCESS_TOKEN`, run `curl -i -X POST "$API_BASE_URL/auth/onboarding" -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" -H "Content-Type: application/json" --data '{"displayName":"테스트","birthYear":1995,"gender":"female","consents":{"terms_of_service":{"accepted":true,"version":"2026-07-07"},"privacy_policy":{"accepted":true,"version":"2026-07-07"},"fit_data_improvement":{"accepted":false,"version":"2026-07-07"},"marketing":{"accepted":false,"version":"2026-07-07"}}}' > .omo/evidence/task-3-signup-oauth-onboarding.http.txt`, PASS if status is 200 and body contains `onboardingComplete:true`. Failure: run same curl without Authorization into the same evidence file or a sibling file, PASS if status is 401.
  Commit: N during execution | Proposed commit label: feat(auth): expose protected oauth onboarding endpoint

- [x] 4. Document backend contract and OAuth dashboard prerequisites without frontend implementation
  What to do / Must NOT do: Update backend/API docs only, likely `docs/API_SPEC_MOBILE.md` and optionally a focused docs note, to state that frontend/mobile must complete Supabase OAuth with Google, then call the protected onboarding endpoint with the Supabase access token. Include future Kakao provider note, required Google/Kakao dashboard prerequisites, request/response JSON, consent keys, and skip-body behavior. Must not write frontend implementation steps as if they are completed.
  Parallelization: Wave 2 | Blocked by: 1, 2 | Blocks: F4
  References (executor has NO interview context - be exhaustive): `docs/API_SPEC_MOBILE.md:60`, `docs/API_SPEC_MOBILE.md:71`, `docs/AGENTS.md:25`, Supabase Google docs `https://supabase.com/docs/guides/auth/social-login/auth-google`, Supabase Kakao docs `https://supabase.com/docs/guides/auth/social-login/auth-kakao`
  Acceptance criteria (agent-executable): `rg -n "Google|Kakao|/auth/onboarding|terms_of_service|privacy_policy|나중에|bodyMeasurements" docs` shows the OAuth onboarding contract and skip behavior.
  QA scenarios (name the exact tool + invocation): Happy: `cd /Users/insihwan/Documents/Project/coordit/coordit-dev-signup-oauth-onboarding && rg -n "Google|Kakao|/auth/onboarding|terms_of_service|privacy_policy|bodyMeasurements" docs > .omo/evidence/task-4-signup-oauth-onboarding.docs.txt`, PASS if all terms are present. Failure: verify `git diff --name-only -- frontend` outputs nothing, append that to the same evidence file, PASS if no frontend path appears.
  Commit: N during execution | Proposed commit label: docs(auth): document oauth onboarding contract

- [x] 5. Run backend static, unit, migration, and real-surface API verification
  What to do / Must NOT do: Run the full backend verification stack available in this repo. If Supabase credentials and a real OAuth/access token are available, start backend and execute the protected onboarding curl scenarios. If no real token/provider config exists, record the exact missing env/config and mark only the real OAuth surface blocked; do not claim OAuth end-to-end done. Must clean up any dev server/tmux session started for QA.
  Parallelization: Wave 3 | Blocked by: 1, 2, 3 | Blocks: final verification
  References (executor has NO interview context - be exhaustive): `backend/package.json:5`, `backend/package.json:6`, `backend/package.json:7`, `backend/package.json:8`, `backend/src/config/env.ts:16`, `backend/src/config/env.ts:17`, `backend/src/config/env.ts:18`
  Acceptance criteria (agent-executable): `cd backend && npm run test:auth-onboarding && npm run typecheck && npm run build` exits 0; `npm run test:fit` still exits 0; HTTP evidence either passes with real Supabase token or records an explicit credential/config blocker.
  QA scenarios (name the exact tool + invocation): Happy/static: `cd /Users/insihwan/Documents/Project/coordit/coordit-dev-signup-oauth-onboarding/backend && { npm run test:auth-onboarding && npm run test:fit && npm run typecheck && npm run build; } > ../.omo/evidence/task-5-signup-oauth-onboarding.backend-green.txt 2>&1`, PASS if exit 0. Happy/HTTP: `curl -i` command from Todo 3 with `$SUPABASE_ACCESS_TOKEN`, PASS if status/body match. Failure/HTTP: same endpoint without bearer token, PASS if 401.
  Commit: N during execution | Proposed commit label: test(auth): verify oauth onboarding flow

- [x] 6. Final cleanup, dirty-worktree audit, and handoff evidence index
  What to do / Must NOT do: Record `git status --short`, changed files, evidence file list, and any blocked real OAuth conditions. Confirm no frontend changes. Confirm no background server, tmux session, or temp test process remains. Do not commit unless the user explicitly asks for commit; if staging happens, stage only files in this plan's scope.
  Parallelization: Wave 3 | Blocked by: 1-5 | Blocks: final handoff
  References (executor has NO interview context - be exhaustive): `.omo/drafts/signup-oauth-onboarding.md`, this plan, project dirty-worktree finding in draft.
  Acceptance criteria (agent-executable): `git status --short` contains only expected plan-scope/backend/supabase/docs changes plus pre-existing untracked AGENTS/.omo items; `git diff --name-only -- frontend` is empty; evidence directory contains each task's evidence file.
  QA scenarios (name the exact tool + invocation): Happy: `cd /Users/insihwan/Documents/Project/coordit/coordit-dev-signup-oauth-onboarding && { git status --short; printf '\nFRONTEND DIFF:\n'; git diff --name-only -- frontend; printf '\nEVIDENCE:\n'; find .omo/evidence -maxdepth 1 -type f -name '*signup-oauth-onboarding*' -print | sort; } > .omo/evidence/final-signup-oauth-onboarding.txt`, PASS if frontend diff section is empty and evidence files are listed. Failure: if any frontend path appears, stop and remove/revert only the worker's frontend edits.
  Commit: N | final handoff only unless user asks to commit

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [x] F1. Plan compliance audit: confirm every Must Have is implemented and every Must NOT Have is respected. Evidence: append checklist to `.omo/evidence/final-signup-oauth-onboarding.txt`.
- [x] F2. Code quality review: review auth/schema changes for idempotency, RLS ownership, validation edge cases, and no provider-token storage. Evidence: append findings or OK to `.omo/evidence/final-signup-oauth-onboarding.txt`.
- [x] F3. Real manual QA: run the Todo 3 HTTP happy/failure scenarios with a real Supabase access token if available; otherwise record exact blocked reason and do not claim end-to-end OAuth completion. Evidence: `.omo/evidence/task-3-signup-oauth-onboarding.http.txt`.
- [x] F4. Scope fidelity: run `git diff --name-only -- frontend` and confirm no frontend edits; confirm docs do not imply frontend work was shipped. Evidence: `.omo/evidence/final-signup-oauth-onboarding.txt`.

## Commit strategy
- Do not auto-commit unless the user explicitly requests it.
- If commits are requested later, use atomic Conventional Commits:
  - `feat(auth): add consent schema for oauth onboarding`
  - `feat(auth): add oauth onboarding service`
  - `feat(auth): expose protected oauth onboarding endpoint`
  - `docs(auth): document oauth onboarding contract`
  - `test(auth): verify oauth onboarding flow`
- Each commit should pass its relevant backend test/typecheck subset before the next commit.
- Final commit footer, if a final combined commit is requested: `Plan: .omo/plans/signup-oauth-onboarding.md`

## Success criteria
- Supabase-backed OAuth users can call the backend onboarding endpoint with a Supabase bearer token.
- The endpoint requires nickname/display name and latest required terms/privacy consent.
- The endpoint stores approved consent versions and optional consent choices.
- The endpoint stores `birth_year` and `gender` only when supplied.
- The endpoint creates no body measurement row when measurements are skipped and does not create duplicate onboarding measurement rows on retry.
- Existing email signup/login routes still work and remain mounted.
- Kakao can be added later without changing the app DB's core onboarding schema.
- Backend tests, fit test, typecheck, and build pass.
- SQL/RLS/index changes are present in base schema plus migration.
- No frontend files are changed.
- Real HTTP OAuth-surface QA is either passing with a real Supabase token or explicitly blocked by missing external credentials/config; no fake token proof is accepted.

## Ledger
- 2026-07-08 task-completed Todo 2 | verifier: fast-state-worker | artifacts: `.omo/evidence/task-2-signup-oauth-onboarding.service-red.txt`, `.omo/evidence/task-2-signup-oauth-onboarding.service-green.txt`, `.omo/evidence/task-2-signup-oauth-onboarding.typecheck.txt` | cleanup: no processes
- {"event":"task-completed","task":"Todo 2","verifier":"current-state-worker","artifacts":[".omo/evidence/task-2-signup-oauth-onboarding.service-green.txt",".omo/evidence/task-2-signup-oauth-onboarding.typecheck.txt"],"adversarial":["malformed_input","dirty_worktree","stale_state","misleading_success_output","flaky_tests"]}
- {"event":"task-completed","task":"Todo 3","verifier":"current-state-worker","artifacts":["task-3 route-red","task-3 route-green","typecheck","route-audit","frontend-diff"],"adversarial":["missing bearer","local jwt","stale evidence","no frontend"],"cleanup":"no processes"}
- {"event":"task-completed","task":"Todo 5","verifier":"current-state-worker","artifacts":[".omo/evidence/task-5-signup-oauth-onboarding.backend-green.txt",".omo/evidence/task-5-signup-oauth-onboarding.sql-prereq.txt",".omo/evidence/task-5-signup-oauth-onboarding.sql-blocked.txt",".omo/evidence/task-5-signup-oauth-onboarding.http-prereq.txt",".omo/evidence/task-5-signup-oauth-onboarding.http-blocked.txt"],"notes":"SQL DB verification and real OAuth HTTP happy path are externally blocked per plan; fake JWT is explicitly non-evidence; no-auth HTTP is blocked by backend start secrets.","cleanup":"no server"}
