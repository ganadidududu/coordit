# Thread wallet hardening

The `codex/guest-wallet-hardening` change preserves an iOS guest's server account
and remaining balance through logout and reinstall on the same device when its
device-only Keychain recovery credential is retained. The balance is never
locally reset to three. Missing credentials cannot identify an old anonymous
account from DeviceCheck alone.

## Deployment

Apply the existing migrations, then these distinct versions in order:

1. `20261026090000_harden_guest_merge.sql`
2. `20261026090100_harden_guest_welcome.sql`
3. `20261026090200_harden_thread_settlement.sql`
4. `20261026090300_require_member_thread_purchases.sql`

Pause wallet mutations during application of the four migrations, then deploy
the matching backend before the iOS build. The welcome RPC signatures and AdMob
signed-user argument change together with the server. Do not deploy only the
client, or run the old wallet-schema reconciliation migration after this upgrade.
This change does not apply SQL to a hosted database or deploy either application.

Existing balances are preserved, including already-spent balances. Legacy guests
without a completed claim enter `legacy`: their next welcome request marks Apple
DeviceCheck as used and returns their current balance without adding credit.
All new accounts, including email and social accounts, start at zero; automatic
per-account welcome seeding is removed to prevent account creation farms.

Only a verified, previously unclaimed iOS device can receive the three-thread
welcome. Android currently has no corresponding device attestation implementation
and cannot receive this iOS DeviceCheck award.

Production rejects Sandbox purchases. A separate development/test backend may set
`APPLE_IAP_ALLOW_SANDBOX=true` only with an explicitly configured
`NODE_ENV=development` or `NODE_ENV=test`. Production App Review and TestFlight
purchases therefore need a separate test backend; they do not fund the production
wallet through Sandbox receipts.

## Protected paths

| Path | Protection |
| --- | --- |
| Logout / reinstall | Separate guest Keychain archive; refresh same UUID; read server balance |
| Corrupt, revoked, mismatched recovery | Stop recovery; never replace an existing archive with a new guest |
| Repeated/concurrent welcome requests | Global database lease, expiry fencing, atomic ledger-before-credit |
| Interrupted eligible attempt | Query Apple again; never trust stale eligibility |
| Legacy device | Mark used without granting more threads |
| Profile/result REST manipulation | Client profile updates and result mutations revoked; server owns writes |
| Analysis/report charge | Atomic balance checks; report key bound to its original analysis |
| Apple purchase | Signed account/product/environment verification; durable transaction deduplication |
| Paid purchase membership | Verified bearer rejects guests; service preflight and DB member check also guard webhook credits |
| Refund / revocation | One clawback; spent credit becomes debt repaid by subsequent credits |
| Guest merge | Transfer balance and debt, purchases, original ad identity and pending callbacks; durable identity alias |
| Account deletion | Keep provider transaction identifiers to block replay |

## Account connection before a paid purchase

Guests see an account connection action on the charge screen. StoreKit is not
activated for guests. The purchase connection sheet offers Apple and Google;
guest continuation and email login are omitted because only the social path
currently carries the guest credentials into the server merge transaction.
Cancellation leaves the guest and balance unchanged. After a successful connection,
the charge screen refreshes the server balance and purchase readiness. If the member
has not finished onboarding, the existing onboarding gate still applies.

The server returns 403 for an anonymous or unclassified authenticated purchase,
even if the request body claims membership. The database checks both the profile
flag and authoritative Supabase Auth identity before any Apple credit, including
server notifications. Already paid historical guest transactions can settle after
their owner connects a member account. Refund handling is independent of membership.

Server merging retains closet items and analysis identifiers. iOS also queues a
guest-to-member transfer of its local analysis snapshots before publishing the
member session. History loading finishes that transfer, combines both histories,
and deduplicates by analysis ID. The destination is written before the source is
removed; a persisted queue permits retry after an interrupted transfer.
Combined histories are not truncated to the old 50-entry limit. Corrupt source
files remain quarantined across retries; a failed recovery never deletes them.

Refund debt belongs to the wallet and is not a hardware identity. Deleting an
account removes its wallet debt; the same provider transaction remains unusable.
This does not guarantee collection of already-consumed services across unrelated
new accounts.

Apple DeviceCheck's bit update and the wallet transaction cannot commit atomically.
If the server fails after setting Apple's bit but before the database credit,
the safe result is no additional grant. Support must investigate that interrupted
first grant; the server never blindly tops up a balance. A global welcome check
in progress returns a retryable 503 to another new claim rather than running two
Apple query/update pairs concurrently.

Historical grants whose device bit was never written cannot be retrospectively
mapped to hardware unless the old account returns with a valid token. No code can
recover a deleted Keychain identity from two DeviceCheck bits, or guarantee a
lifetime cap after Apple resets its own device state. The application does not
reset Apple's used bit.

## Verification

From `backend`, run `npm run typecheck`, `npm run test:wallet-hardening`, and
`npm test`. The new tests cover zero unverified seed, current balance replay,
concurrent and stale leases, legacy balance preservation, purchase/reward merge,
callback identity, report key mismatch, refunds/debt, and deletion tombstones.

Run the `coordit` scheme's `coorditTests` for guest recovery, token rotation,
logout races, damaged credentials, account deletion and upgrades. For the explicit
uninstall/reinstall probe, use `CoorditGuestReinstallProbe` with
`TEST_RUNNER_COORDIT_GUEST_REINSTALL_PHASE=seed`, uninstall only that test app,
then run with `TEST_RUNNER_COORDIT_GUEST_REINSTALL_PHASE=recover`. The probe checks
that sandbox data disappeared while the same guest UUID and balance two recover
from Keychain. Use the repository's SimSlim preparation and doctor steps first.

Simulator tests mock backend balances and cannot generate real DeviceCheck tokens.
Release verification still requires a physical device and the deployed database:
receive three once, spend one, logout/reenter, uninstall/reinstall, and verify two
remains while a new guest on the same device receives no new award.
