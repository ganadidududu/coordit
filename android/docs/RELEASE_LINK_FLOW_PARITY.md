# iOS / Android release flow parity — 2026-10-30

Branch: `codex/release-link-first-fitlab`. Reference iOS commits: `32221c7` (guided link-first FitLab), `52f80b4` (Home editorial). The original Android parity work used those iOS references. The 2026-10-30 guidance update changes both native clients; backend behavior remains unchanged.

## Implemented

- Home uses the original editorial artwork and three iOS magazine issues. The main action opens FitLab; reference garments precede the latest two actual saved reports. Saved reports open their real history details.
- FitLab starts with link or size-chart import. Paste, automatic garment classification, an explicit category override, import recovery, and editable measurements lead to the free product overview. Valid complete link imports open the overview directly; incomplete imports remain editable.
- Shared vector glyphs, summary section outlines, shared solid content-action buttons, and circled picker close/check indicators follow the Swift reference while preserving semantic labels and selection state.
- Free reading mirrors the iOS width/length interpretation, largest adjacent size change, approximate circumference difference, category-specific wearing context, missing values, and expandable measurement table. Skirts use waist/hip/length rather than requiring a rise.
- The comparison action scrolls directly below product-information edit at the end of the overview. The oversized navy headline card and comparison teaser heading are removed on both platforms. Comparison offers owned-clothing link registration, a camera availability notice, and a wardrobe picker. Selection stays local until done; closing or system Back discards temporary changes.
- Comparison explains both choosing an already saved owned garment and registering a previously unregistered owned garment. Registering its actual owned size automatically saves it to Closet for future comparisons; it does not require paid analysis. Camera measurement remains unavailable, and the link/size-chart alternatives are explained.
- Practice starts with no reference garment. Users follow link registration → select owned size → return to FitLab → select the new example reference → compare. Examples do not call creation, recommendation or report APIs, save history, or consume threads.
- Compact step hints scroll in the content body. The free-report comparison CTA also scrolls below product-information edit and contains no tutorial card.
- Only explicit paid submission creates products/sizes and requests recommendation/report. Existing checkpoints and idempotency keys survive retries and process restoration. Unknown wallet balance is distinguished from a confirmed zero; shared imports and reference entry refresh the balance.
- Registering a reference from FitLab preserves the product draft, saves the garment, registers its reference without deactivating unrelated references, and returns to the comparison. A retry keeps the same clothing save key, including across example practice.
- First visits are tracked independently per account and feature (v2). Login/Home presents no guide. Opening FitLab or Closet for the first time starts the local interactive example directly; completing one never opens the other automatically. The long expandable FAQ opens only from Help. Completing/skipping restores the original feature state and pending save context. Help-started replay uses the same app-owned practice session, including nested reference registration.
- Android's text share sheet accepts product URLs and defers consumption through authentication or active practice. Background analysis can continue across tabs and exposes a return notice.
- Category changes and destructive actions retain confirmation/cancellation; destructive confirmation uses the shared danger token. Navigation labels stay legible at accessibility text sizes. Home scrolls in a viewport below the fixed header so large-text content cannot cover its logo and controls.

## Popup and sheet coverage

| Surface | Confirmed behavior |
| --- | --- |
| Guest login notice | Explains member welcome threads versus guest balance; cancel retains providers; confirm alone starts guest authentication. |
| Onboarding legal sheets | Terms/privacy content remains reachable and dismissible; existing consent tests retained. |
| First feature visit | No login-time sheet; FitLab and Closet each start their own interactive example on entry. Skip confirms intent and restores that feature without chaining another guide. |
| Help topics | Expandable iOS copy for FitLab, comparison, and Closet; comparison help returns to the current comparison, while other guides offer local practice with a free/no-save note. |
| Practice exit | Continue preserves example; skip restores the previous draft and feature context. |
| Example product discard | Restores real input and ends the current practice without starting another feature guide. |
| Category change | Cancel preserves product/rows/references; confirm clears incompatible measurements and references. |
| Reference picker | Empty/loading/error/ready/selected states; close and Back cancel; done commits valid compatible references. |
| Reference reload | Network failure remains inside the popup with retry and registration recovery. |
| Camera availability | Both Closet and FitLab retain an enabled explanation action; no release measurement route is opened. |
| Insufficient threads | Cancel preserves the comparison; recharge opens the charge destination and returns to the same product. Server 402 also presents recovery without clearing checkpoints. |
| New product confirmation | Continue preserves input; explicit destructive confirmation clears the unsaved product while retaining saved history. |
| Closet rename/delete | Blank rename is disabled; cancel preserves the garment; delete is explicit and destructive. |
| Ad privacy/notifications/settings | Existing native permission and preference flows remain covered by their device tests. |

## Original Android parity verification (2026-10-29)

Tests run against real Compose screens and navigation with isolated API fixtures; no real account purchase or wallet consumption is required. Unit coverage includes data interpretation, URL parsing, compatible-reference filtering, automatic-category requests, and pending-key restoration across examples. The device matrix includes normal phone layout and a smaller phone in dark system appearance, plus a 1.7× text-size Home case.

Reference screenshots were generated from the current iOS source after SimSlim profile apply, verify, and required-feature doctor. All five `CoorditReleaseLinkFlowUITests` passed. Android screenshots and run logs are local under `.omo/evidence/android-release-parity/`; review records are under `.omo/evidence/`.

| Check | Result |
| --- | --- |
| Android build, instrumentation APK build, unit tests, lint | `:app:assembleDebug :app:assembleDebugAndroidTest :app:testDebugUnitTest :app:lintDebug` passed; 88 unit tests, zero failures/errors/skips. |
| Broad Android device regression | 33/33 passed. This run preceded the last lower-length normalization regression and Home viewport refinement; the final affected paths were rerun below. |
| Final release matrix, normal phone | 13/13 passed; API 36, 1080×2400, density 420 (about 411 dp). |
| Final release matrix, compact/dark | 13/13 passed; same API/pixels, density 480 (360 dp), dark system appearance. |
| iOS reference UI suite | 5/5 passed with the current iOS source. |
| Visual evidence | 38 current-build captures per Android configuration, including expanded tables, end-of-scroll, nested confirmation, help, picker selection/failures, and 1.7× Home text. |
| Independent review | Functional source review APPROVE; final visual review PASS; final design-system fidelity review APPROVE. No blocking findings remain in the reviewed scope. |
| Source whitespace check | `git diff --check` passed. |

Final Android APK SHA-256: `311244c7a539c5b282c4bb9fac8a4c58dd6c7c01dbeb52c62a1094ee156315de`.

Evidence paths (local, ignored):

- `.omo/evidence/android-release-parity/capture-metadata.json`: exact build and capture hashes for both configurations.
- `.omo/evidence/android-release-parity/{final-normal,final-compact-dark}/release-parity/`: full-resolution final images.
- `.omo/evidence/android-release-parity/{build-and-unit-tests,final-device-tests,final-release-tests,final-compact-dark-tests}.log`: command results.
- `.omo/evidence/android-release-parity/ios/`: exported iOS reference captures and manifest.
- `.omo/evidence/android-release-final-integrity.md`: independent functional/source review.
- `.omo/evidence/android-release-visual-review.md` and `.omo/evidence/android-release-design-final.md`: final independent visual and design-system reviews.

An additional normal-phone rerun of the picker/summary scenario passed (1/1) to capture selected and unselected icons from the final build; its log is `selected-picker-tests.log`.

The final focused instrumentation classes are `FitLabReleaseFlowTest`, `ReleaseGuidanceTest`, and `HomeEditorialTest`. Their assertions cover API call counts (free/examples do not charge), local selection cancellation, restoration after guide/practice flows, reference-registration return, balance loading, charge/back navigation, lower measurement aliases, and fixed-header clearance. Runtime delivery of an external app's share Intent was source-reviewed and its URL/queued-state handling was tested separately; an actual third-party share-sheet handoff was not exercised.

## Remaining platform differences

- Apple web OAuth and Google Play Billing were pre-existing integration gaps. This change does not claim either is implemented or validated with real purchases.
- Native pickers, keyboard/permission surfaces, system Back, font rasterization, and Apple Liquid Glass rendering differ by OS. Shared vector silhouettes approximate SF Symbols; exact symbol artwork is not reused. Shared layouts, content, actions, and state transitions are matched; pixel-identical platform rendering is not claimed.
- Camera measurement remains unavailable in both current release entry flows. Existing experimental camera code is not presented as a shipping feature.
- No physical Android/iOS device pairing, real store transaction, or exhaustive backend outage test was performed. Network/retry assertions use deterministic fixtures.

## Feature-entry guidance validation milestone (2026-10-30)

The new acceptance matrix covers login with no guide, Closet-first and FitLab-first visits, account-scoped once-only completion, skip/continue, on-demand FAQ, a free report whose compact hint scrolls away, reference-empty/camera-unavailable states, local owned-garment registration/return/selection/comparison, Help replay over an existing report, pending shared links, and preservation of an existing Closet photo draft.

The iOS coordinator snapshots its draft, reference selection, analysis/report and retry checkpoint before practice, resetting only in-memory display state. Practice completion restores the snapshot without deleting a real submission's persisted idempotency key. Android retains its model snapshots and excludes example Detail from draft-photo transfer/removal. Both apps keep nested reference practice in the same root-owned session so it cannot start a second automatic Closet guide.

The earlier verification section records the preceding Android-only parity milestone and its original APK. The latest guidance build was validated as follows:

| Check | Final result |
| --- | --- |
| Android build, test APK, unit tests, lint | Passed; 88 unit tests, zero failures/errors/skips. |
| Android focused device matrix | 18/18 passed at density 420; 18/18 passed at density 480 with dark system appearance. Both runs include the original-photo-draft preservation regression. |
| Android registration end-of-scroll capture | One additional focused scenario passed in each configuration against the same production APK. |
| iOS normal appearance | 16/16 unit tests and 5/5 first-use UI scenarios passed. |
| iOS dark system appearance | 5/5 first-use UI scenarios passed against the same production debug dylib. |
| Final native captures | 48 Android originals per configuration and 21 iOS originals per appearance: 138 PNGs with dimensions, test provenance and SHA-256 manifests. |
| Independent source review | APPROVE, including the late tutorial-stage and nested-exit changes. |
| Independent final visual review | PASS / APPROVE; all 138 final original screenshots inspected, no blocking findings. |

Guidance-milestone Android APK SHA-256: `3c8035f7b96ff121df9527f3514e8f4291419f2c6cd0f7ccc1ce7eeadcf0e595`.
Guidance-milestone iOS debug dylib SHA-256: `63368f0220daa9f29b13193e5ed98070c06ce44d70153c513f763b78e965b2ae`.

Guidance-milestone evidence (local, ignored):

- `.omo/evidence/feature-entry-guidance/qa-ledger.md`: acceptance criteria, run results and limitations.
- `.omo/evidence/feature-entry-guidance/build-capture-metadata.json`: exact build and screenshot hashes.
- `.omo/evidence/feature-entry-guidance/final-android-{normal,compact-dark}/release-parity/`: current Android originals.
- `.omo/evidence/feature-entry-guidance/final-ios-verified-{normal,dark}/`: current iOS originals and test attachment manifests.
- `.omo/evidence/feature-entry-guidance/{android-normal-tests,android-compact-dark-tests,ios-normal-tests,ios-dark-tests}.log`: final focused runs.
- `.omo/evidence/feature-entry-guidance-gate-review.md` and `.omo/evidence/feature-entry-guidance-final-visual-review.md`: independent reviews.

The guidance fixtures exercise native screens with local examples and isolated API gateways. They confirm that example practice does not save, charge, or write history; they are not real store/account transactions. Both native clients retain the established light brand content under dark system settings; the matrix checks compatibility, not a new dark palette. Current iOS Help replay emits one unlocated SwiftUI `Invalid frame dimension (negative or non-finite)` runtime warning per run, without a failed scenario or a settled guide-layout defect. Very large iOS text still shortens surrounding bottom-navigation brand wordmarks while retaining icons and accessibility labels; whole-app accessibility is not certified here.


## Free-summary layout simplification (2026-10-30)

Both native clients omit the oversized navy headline/detail card. The regular size summary, adjacent-size differences, wearing context and expandable measurements remain. Product-information edit is followed immediately by the comparison button in the same report scroller; no comparison footer stays fixed over the report. Both buttons use the existing content-action button family with equal dimensions, type and corners. Comparison uses solid primary ink, with no gradient, shadow, icon or arrow. Its only caption is `실타래 1개가 소모됩니다.`.

This layout supersedes the earlier persistent-action design. The previous guidance milestone's evidence is historical; final evidence for this follow-up is `.omo/evidence/fitlab-summary-inline/`.

Final follow-up validation: Android build/lint and 15/15 device scenarios passed in each normal and compact/dark configuration; four normal capture scenarios additionally passed against the same APK after Gradle removed their earlier output. iOS ordinary/guided/large-text scenarios passed 3/3 per normal/dark appearance. The final matrix has 36 native originals (Android10×2, iOS8×2), 20 preserved baseline originals, 16 before/after pairs, test logs and SHA-256 manifests. No product source changed after these final captures.

Latest Android APK SHA-256: `d444b39ff27a8f34f304b2b338a0646680549fbc95693faebcc72566c348eb20`.
Latest iOS debug dylib SHA-256: `5968607bbd5ef736767453269a029b535959cd402ece7bf5583dbca74f3d0eff`.

Independent integrity and visual reviews both returned PASS / APPROVE with no blocking findings in this follow-up. Reports and baseline accessibility limitations are recorded in `.omo/evidence/fitlab-summary-inline/{review-a,review-b,qa-ledger}.md`. Source whitespace check passed.
