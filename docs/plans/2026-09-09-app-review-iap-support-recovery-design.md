# App Review IAP and support recovery design

Date: 2026-09-09

## Context

App Review rejected version 1.0 build 7 under Guideline 2.1(b) because every in-app purchase control on the thread charge screen was visibly disabled. The submitted support URL also returned no usable support page. App Store Connect already contains three consumable products in a ready-for-review state:

- `com.inseong.coordit.thread.5`
- `com.inseong.coordit.thread.10`
- `com.inseong.coordit.thread.20`

The fix must make the advertised purchase flow real, preserve the server as the authority for thread balances, and give reviewers a public support destination.

## Purchase architecture

The iOS app loads the three consumables with StoreKit 2 and renders Apple's localized `displayPrice`, rather than hard-coded prices. Selecting an available product starts `Product.purchase()`. User cancellation remains silent, pending approval gets an explanatory status, and verification or settlement failures leave the transaction unfinished so the app can retry safely.

For a verified StoreKit transaction, the app sends the signed transaction JWS to the authenticated backend. The backend validates the signed transaction against Apple's production trust chain, retries verification against the sandbox environment when Apple reports a sandbox transaction, and accepts only the Coordit bundle identifier and the three known consumable product identifiers.

The backend extracts the Apple transaction identifier and performs one atomic database operation that:

1. records the Apple transaction identifier uniquely;
2. credits the product's configured thread amount to the authenticated user's wallet;
3. writes an `iap_purchase` ledger entry; and
4. returns the resulting balance.

Repeated delivery of the same transaction returns the existing settled balance without issuing threads again. Only after the backend acknowledges settlement does the app call `transaction.finish()` and update the visible balance. On app launch or screen entry, unfinished verified transactions are retried to cover crashes and temporary network failures.

## User interface

The charge screen has explicit loading, purchasing, pending, success, and failure states. Purchase rows are enabled only when their matching StoreKit product was loaded and no purchase is being settled. If products cannot be loaded, the screen explains the temporary issue and offers retry instead of showing unexplained gray controls.

The unreleased rewarded-ad option is removed from the submitted UI. It can return only when ad delivery and server-side reward settlement are implemented.

## Public support page

The backend serves `GET /support` before authentication middleware. It returns a small mobile-friendly HTML page containing the Coordit service name, support contact path, expected response window, account-deletion guidance, and links to the published privacy policy and terms. `GET /health` remains unchanged.

## Security and operations

- The client never chooses the credited amount; the backend maps a verified product identifier to a fixed amount.
- The database unique constraint on Apple transaction identifiers is the idempotency boundary.
- Authentication is required for settlement, including durable guest accounts.
- Verification failures are returned without revealing JWS or certificate contents.
- App Store review notes must describe only behavior that exists in the submitted build.

## Verification plan

1. Add failing backend tests for public support HTML, unknown products, bundle mismatch, and duplicate settlement.
2. Replace the UI test that expects disabled controls with tests for loaded products, retry/error presentation, and a successful StoreKit test purchase.
3. Run backend typecheck and full backend tests.
4. Prepare the iOS simulator with SimSlim, including the required doctor capabilities, then run the iOS build and UI suites.
5. Exercise guest, Google, and Apple entry points; persisted session and balance; FIT LAB URL import; photo import; analysis consumption; purchase crediting; app relaunch; and reinstall recovery.
6. Verify the deployed `/support` page in a real browser and the three App Store Connect product states before creating build 8.
