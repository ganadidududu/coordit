# Social first-login thread balance refresh

## Problem

The server correctly creates a three-thread wallet for new Google and Apple
members, but the iOS client can keep displaying its initial zero balance after
the member finishes onboarding.

The root task starts when the authenticated user ID changes. For a first-time
social member it stops before loading product data because onboarding is not yet
complete. Finishing onboarding changes `onboardingComplete`, not the user ID, so
that task does not run again and the initial zero remains visible.

## Design

After onboarding completes successfully, fetch the authoritative thread balance
from the backend before entering the main product route. If the fetch succeeds,
replace the local balance. If it fails, keep the existing value and preserve the
session; the existing session store already exposes the warning and supports a
later refresh.

This keeps the change at the lifecycle boundary that currently misses the
refresh. It avoids moving wallet ownership into the session store or rerunning
the full bootstrap and closet synchronization pipeline.

## Verification

- Add a regression test that models the onboarding completion transition and
  proves the displayed balance is refreshed from zero to the server value.
- Run the focused UI test twice: once without the fix to capture the failure and
  once with the fix to prove the causal toggle.
- Run the affected iOS test suite and build after the focused test passes.
