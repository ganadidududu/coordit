# Todo 4 Docs Code Review

Verdict: needs-fix
codeQualityStatus: BLOCK
recommendation: REQUEST_CHANGES

## Skill Perspective

- `omo:remove-ai-slops` was loaded and applied as a read-only review lens. No deletion-only tests, tautological tests, or production slop edits were introduced by Todo 4 docs. The docs evidence file was treated as untrusted and checked against source.
- `omo:programming` and its TypeScript reference were loaded before judging the TypeScript route/controller/service contract. No new TypeScript edits were made in this review.
- Codegraph was attempted first for source inspection, but this worktree has no `.codegraph/` index, so direct `rg` and numbered file reads were used.

## CRITICAL

None.

## HIGH

1. `docs/API_SPEC_MOBILE.md` documents the onboarding response as `consents`, but the implemented route returns `consentStatus`.
   - Docs: `docs/API_SPEC_MOBILE.md:90` lists `consents` as a major return value, and `docs/API_SPEC_MOBILE.md:178` starts the response example with `"consents"`.
   - Implementation: `backend/src/modules/auth/auth-onboarding.controller.ts:23` defines the response type with `consentStatus`; `backend/src/modules/auth/auth-onboarding.controller.ts:96` builds that response; `backend/src/modules/auth/auth-onboarding.controller.test.ts:204` asserts the returned JSON contains `consentStatus` with `savedConsentKeys`, `requiredAccepted`, and `optionalAccepted`.
   - Required change: replace response docs/example with the actual `consentStatus` shape:
     `{ "savedConsentKeys": ["terms_of_service", "privacy_policy"], "requiredAccepted": true, "optionalAccepted": [...] }`.

2. The docs do not explicitly state that local JWT fallback is rejected for `/auth/onboarding`.
   - Docs: `docs/API_SPEC_MOBILE.md:114` says the backend verifies the Supabase JWT/access token, but does not warn that legacy/local JWT fallback is not accepted for this endpoint.
   - Implementation: shared middleware can fall back to local JWT at `backend/src/middleware/auth.middleware.ts:32`, while onboarding revalidates with Supabase at `backend/src/modules/auth/auth-onboarding.controller.ts:47` and rejects non-Supabase bearer tokens at `backend/src/modules/auth/auth-onboarding.controller.ts:110`. The controller test locks this at `backend/src/modules/auth/auth-onboarding.controller.test.ts:161`.
   - Required change: add an explicit note near the authentication/Supabase validation section that `/auth/onboarding` requires a Supabase access token and rejects local JWT fallback with 401.

## MEDIUM

None.

## LOW

None.

## Confirmed Matches

- `POST /auth/onboarding` is documented at `docs/API_SPEC_MOBILE.md:86` and mounted after `authMiddleware` at `backend/src/routes.ts:65`.
- Supabase access-token bearer handoff is documented at `docs/API_SPEC_MOBILE.md:79` and `docs/API_SPEC_MOBILE.md:87`.
- Google now / Kakao later is documented at `docs/API_SPEC_MOBILE.md:95`.
- Required `terms_of_service` and `privacy_policy` are documented at `docs/API_SPEC_MOBILE.md:88` and `docs/API_SPEC_MOBILE.md:160`.
- Optional `fit_data_improvement` and `marketing` are documented at `docs/API_SPEC_MOBILE.md:89` and `docs/API_SPEC_MOBILE.md:161`.
- `birthYear`, `gender`, and `bodyMeasurements` are documented as optional at `docs/API_SPEC_MOBILE.md:89`; the service also treats them as optional at `backend/src/modules/auth/auth-onboarding.service.ts:114`, `backend/src/modules/auth/auth-onboarding.service.ts:120`, and `backend/src/modules/auth/auth-onboarding.service.ts:197`.
- `birthYear` rather than canonical `age` is documented at `docs/API_SPEC_MOBILE.md:162`.
- Body measurement skip behavior is documented at `docs/API_SPEC_MOBILE.md:163` and `docs/API_SPEC_MOBILE.md:205`, and implemented at `backend/src/modules/auth/auth-onboarding.service.ts:86` and `backend/src/modules/auth/auth-onboarding.service.ts:207`.
- Frontend implementation is not claimed shipped at `docs/API_SPEC_MOBILE.md:78`.
- `git diff --name-only -- frontend` and `git diff --cached --name-only -- frontend` both returned no paths.
- Targeted verification run: `cd backend && npm run test:auth-onboarding` passed all service/controller cases, including local JWT rejection and 200 response shape.

## Blockers

- Fix the documented response object from `consents` to `consentStatus`.
- Add the explicit local-JWT-fallback rejection note for `/auth/onboarding`.
