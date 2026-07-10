# manualQa Matrix - Todo 5 signup-oauth-onboarding

## surfaceEvidence

| scenario id | criterion reference | surface | exact invocation | verdict | artifactRefs |
| --- | --- | --- | --- | --- | --- |
| static-backend-green | Todo 5 Acceptance / Happy static | Backend npm scripts | `cd backend && { npm run test:auth-onboarding && npm run test:fit && npm run typecheck && npm run build; } > ../.omo/evidence/task-5-signup-oauth-onboarding.backend-green.txt 2>&1` | PASS, exit 0 observed | A1 |
| sql-prereq | Todo 5 SQL verification | Shell tool/env prerequisite check | `command -v psql`, `command -v supabase`, `command -v postgres`, env presence checks for `SUPABASE_DB_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` with values redacted | PASS for prerequisite inspection | A2 |
| sql-real-surface | Todo 5 SQL verification | Disposable/dev DB SQL apply/contract | Not run; no `SUPABASE_DB_URL`, no Supabase env, and no local SQL tooling available | BLOCKED_ALLOWED_BY_PLAN | A3 |
| http-prereq | Todo 5 HTTP real-surface | Shell env prerequisite check | Check `API_BASE_URL`, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` presence with values redacted | PASS for prerequisite inspection | A4 |
| http-oauth-happy | Todo 5 Happy/HTTP | `curl -i` protected onboarding | `curl -i -X POST "$API_BASE_URL/auth/onboarding" -H "Authorization: Bearer <REDACTED>" -H "Content-Type: application/json" --data <valid onboarding JSON>` | BLOCKED_ALLOWED_BY_PLAN: no real `SUPABASE_ACCESS_TOKEN`; fake JWT not acceptable | A5 |
| http-no-auth | Todo 5 Failure/HTTP | `curl -i` protected onboarding without bearer | `curl -i -X POST "http://localhost:4000/auth/onboarding" -H "Content-Type: application/json" --data <valid onboarding JSON without Authorization>` | BLOCKED_ALLOWED_BY_PLAN: backend cannot start without required Supabase env | A5 |
| cleanup | Todo 5 cleanup | Process/listener check | `pgrep -fl 'tsx watch src/server.ts|coordit backend|node dist/server.js'`; `lsof -nP -iTCP:4000 -sTCP:LISTEN` | PASS: no QA-started backend remained; no listener on 4000 | A6, A7 |

## adversarialCases

| scenario id | criterion reference | adversarial class | expected behavior | verdict | artifactRefs |
| --- | --- | --- | --- | --- | --- |
| adv-dirty-worktree | Scope / no frontend edits | dirty_worktree | `git diff --name-only -- frontend` is empty | PASS | A6 |
| adv-stale-state | Todo 5 stale state | stale_state | Plan is read fresh; Todos 1-4 checked before Todo 5 update | PASS | A6 |
| adv-misleading-output | Todo 5 evidence rigor | misleading_success_output | Evidence files are non-empty and static exit status is recorded | PASS | A1, A6 |
| adv-hung-commands | Cleanup | hung commands | No long-running QA backend/tmux/server is left running | PASS | A6, A7 |
| adv-secret-hygiene | Scope / no secrets | secret hygiene | Env/token values are redacted and no fake token is used | PASS | A2, A4, A5 |
| adv-malformed-no-auth | Todo 5 Failure/HTTP | malformed input | Missing bearer should return 401 if backend can start | BLOCKED_ALLOWED_BY_PLAN: backend startup requires missing Supabase env | A5 |

## artifactRefs

| id | kind | description | path |
| --- | --- | --- | --- |
| A1 | transcript | Required backend static command transcript, including auth onboarding tests, fit tests, typecheck, and build | `.omo/evidence/task-5-signup-oauth-onboarding.backend-green.txt` |
| A2 | transcript | SQL tooling and env presence check with values redacted | `.omo/evidence/task-5-signup-oauth-onboarding.sql-prereq.txt` |
| A3 | blocker | Explicit SQL real-surface blocker for missing disposable/dev DB and SQL tooling | `.omo/evidence/task-5-signup-oauth-onboarding.sql-blocked.txt` |
| A4 | transcript | HTTP env presence check with values redacted | `.omo/evidence/task-5-signup-oauth-onboarding.http-prereq.txt` |
| A5 | blocker | Explicit HTTP real-surface blocker for missing real Supabase access token and backend startup env | `.omo/evidence/task-5-signup-oauth-onboarding.http-blocked.txt` |
| A6 | transcript | Adversarial QA, frontend diff, stale-state, evidence size, process/listener, cleanup, and secret hygiene checks | `.omo/evidence/task-5-signup-oauth-onboarding.adversarial.txt` |
| A7 | transcript | Final audit showing Todo 5 checked, ledger event present, task-5 artifacts non-empty, no frontend diff, and no backend listener/process | `.omo/evidence/task-5-signup-oauth-onboarding.final-audit.txt` |
