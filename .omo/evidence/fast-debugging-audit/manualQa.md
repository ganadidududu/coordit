# manualQa Matrix - fast-debugging-audit

## surfaceEvidence

| scenario id | criterion reference | surface | exact invocation | verdict | artifactRefs |
| --- | --- | --- | --- | --- | --- |
| h1-local-jwt-onboarding-bypass | local JWT onboarding bypass | Backend auth onboarding tests | `cd backend && npm run test:auth-onboarding` | PASS | A2, A3 |
| h2-optional-fields-required | optional fields required | Backend parser/service tests and docs/code grep | `cd backend && npm run test:auth-onboarding`; `rg -n "required\|gender\|birthYear\|bodyMeasurements\|terms_of_service\|privacy_policy\|fit_data_improvement\|marketing" frontend/src/app/onboarding/page.tsx` | PASS | A2, A8, A9 |
| h3-duplicate-body-rows | duplicate body rows | Backend service/repository tests and code grep | `cd backend && npm run test:auth-onboarding`; `rg -n "findExistingOnboardingBodyMeasurement\|insertBodyMeasurement\|updateBodyMeasurement\|body measurements without numeric\|retry body measurements" backend/src/modules/auth` | PASS | A2, A7 |
| h4-docs-response-mismatch | docs response mismatch | Docs/API response contract vs controller/test grep | `sed -n "55,210p" docs/API_SPEC_MOBILE.md`; `rg -n "toOnboardingResponse\|consentStatus\|bodyMeasurementsSaved\|onboardingComplete\|authUser\|accessToken\|user" backend/src/modules/auth docs/API_SPEC_MOBILE.md frontend/src/app/onboarding/page.tsx frontend/src/lib/types.ts` | PASS | A5, A6 |
| h5-fake-external-qa | fake external QA | Existing QA evidence plus live HTTP prerequisite probe | `sed -n '1,260p' .omo/evidence/task-5-signup-oauth-onboarding.manualQa.md`; `curl -i --max-time 2 http://localhost:4000/health`; `cd backend && npm run dev` with current env | FAIL | A4, A10 |
| tc-backend | current backend typecheck | Backend TypeScript compiler | `cd backend && npm run typecheck` | PASS | A11 |
| tc-frontend | current frontend typecheck | Frontend TypeScript compiler | `cd frontend && npm run typecheck` | FAIL | A12 |

## adversarialCases

| scenario id | criterion reference | adversarial class | expected behavior | verdict | artifactRefs |
| --- | --- | --- | --- | --- | --- |
| adv-invalid-test-command | evidence rigor | misleading success from wrong test script | Invalid `npm test` must not be counted as PASS | PASS | A13 |
| adv-http-no-env | fake external QA | missing external prerequisites | Real HTTP QA cannot pass without backend env/token and reachable server | PASS | A10 |
| adv-prior-blocked-qa | fake external QA | skipped/blocked evidence | Prior blocked HTTP QA must be treated as non-PASS | PASS | A4 |
| adv-artifact-nonempty | evidence rigor | empty artifact | PASS verdicts must cite non-empty artifacts | PASS | A14 |

## artifactRefs

| id | kind | description | path |
| --- | --- | --- | --- |
| A1 | transcript | Repo/evidence inventory | `.omo/evidence/fast-debugging-audit/repo_inventory.txt` |
| A2 | transcript | Current `npm run test:auth-onboarding` output | `.omo/evidence/fast-debugging-audit/backend_auth_onboarding_tests_actual.txt` |
| A3 | transcript | Current auth/onboarding implementation excerpts | `.omo/evidence/fast-debugging-audit/current_auth_onboarding_code.txt` |
| A4 | transcript | Prior external QA/manual QA evidence excerpts | `.omo/evidence/fast-debugging-audit/prior_external_qa_evidence.txt` |
| A5 | transcript | Docs response shape excerpts | `.omo/evidence/fast-debugging-audit/docs_response_excerpts.txt` |
| A6 | transcript | Response-shape grep across docs/controller/tests/frontend types | `.omo/evidence/fast-debugging-audit/response_shape_grep.txt` |
| A7 | transcript | Duplicate body-row proof grep | `.omo/evidence/fast-debugging-audit/body_rows_proof_grep.txt` |
| A8 | transcript | Current onboarding tests source excerpts | `.omo/evidence/fast-debugging-audit/current_onboarding_tests.txt` |
| A9 | transcript | Frontend optional required grep | `.omo/evidence/fast-debugging-audit/frontend_optional_required_check.txt` |
| A10 | transcript | HTTP prerequisite, `curl -i`, backend startup, and cleanup probe | `.omo/evidence/fast-debugging-audit/http_prereq_and_probe.txt` |
| A11 | transcript | Backend typecheck output | `.omo/evidence/fast-debugging-audit/backend_typecheck.txt` |
| A12 | transcript | Frontend typecheck output | `.omo/evidence/fast-debugging-audit/frontend_typecheck.txt` |
| A13 | transcript | Invalid initial test command transcript | `.omo/evidence/fast-debugging-audit/backend_auth_onboarding_tests.txt` |
| A14 | transcript | Final artifact inventory | `.omo/evidence/fast-debugging-audit/final_artifact_inventory.txt` |
