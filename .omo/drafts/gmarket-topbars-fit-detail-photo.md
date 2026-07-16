---
slug: gmarket-topbars-fit-detail-photo
status: completed
intent: clear
review_required: true
pending-action: none
approach: exact shared-title scope plus displayed-item-ID image mutation, RED-to-GREEN UI contracts, and fresh simulator visual QA
---

# Draft: gmarket-topbars-fit-detail-photo

## Components (topology ledger)
<!-- Lock the SHAPE before depth. One row per top-level component that can succeed or fail independently. -->
<!-- id | outcome (one line) | status: active|deferred | evidence path -->
- `topbar-typography` | two approved shared title components use Gmarket Sans Bold | completed | `coordit/coordit/CoorditFitLabComponents.swift`, `coordit/coordit/CoorditClosetComponents.swift`
- `add-flow-photo-removal` | photo/manual add flows no longer show or require garment photos | completed | `coordit/coordit/CoorditClosetAddFlow.swift`
- `fit-detail-photo` | top, bottom, and add-result detail add/replace the displayed item's in-memory image | completed | `coordit/coordit/CoorditClosetScreens.swift`, `coordit/coordit/CoorditClosetDetailScreen.swift`, `coordit/coordit/CoorditRootView.swift`
- `verification` | focused RED→GREEN, regression, actual picker, typography, adversarial, and visual evidence pass | completed | `coordit/coorditUITests/`, `.omo/evidence/gmarket-topbars-fit-detail-photo/`

## Open assumptions (announced defaults)
<!-- Record any default you adopt instead of asking, so the user can veto it at the gate. -->
<!-- assumption | adopted default | rationale | reversible? -->
- “Fit Detail” means the Closet detail shared by top/bottom/add-result | grounded in the add-photo relocation request and current navigation | yes
- image lifetime remains in-memory | matches the current prototype model and avoids unauthorized backend/storage scope | yes
- detail supports add/replace, not delete | directly satisfies the request without inventing a removal behavior | yes

## Findings (cited - path:lines)
- Fit Lab title uses Climate at `coordit/coordit/CoorditFitLabComponents.swift:24`; its CTA Climate call is unrelated and must remain.
- Closet shared title uses Climate at `coordit/coordit/CoorditClosetComponents.swift:27`; it covers Closet/add/detail/link/photo/manual/fit-check titles.
- `CoorditTypography.gmarketBold` and bundled font registration already exist in `CoorditTypography.swift:37`, `CoorditFontRegistration.swift:9`, and `coorditApp.swift:8`.
- Photo readiness currently depends on name + size chart + garment, while manual readiness depends on name + garment + four measurements in `CoorditClosetAddFlow.swift:267-326`.
- Closet detail top/bottom/add-result share one detail screen, but `CoorditClosetItem.imageData` is immutable and the artwork has no picker in `CoorditClosetScreens.swift:16-24,60-95,204-213` and `CoorditClosetDetailScreen.swift:5-20`.
- Existing UI coverage positively expects soon-to-be-removed garment controls in `coordit/coorditUITests/CoorditFeatureFlowsUITests.swift:57-74`, so it must be characterized then inverted before production edits.

## Decisions (with rationale)
- Change exactly `CoorditFitLabTitleCard` and `CoorditClosetTitleBar`; My Page is explicitly out of scope.
- Use `CoorditTypography.gmarketBold` at the existing 22pt/headline metrics; preserve layout unless fresh screenshots show clipping.
- Keep `garmentImageData` in the draft so actual add-result detail can own its image after form removal.
- Resolve the displayed item ID at async commit time, validate `UIImage(data:)`, and use a monotonically increasing selection generation so stale completions cannot overwrite the latest image.
- Fall back to `closet-draft-preview` only when no closet array item matches; otherwise an unknown ID is a no-op.
- Use static + runtime availability + visual typography proof because XCUI cannot inspect the SwiftUI font family.

## Scope IN
- The two shared iOS page-title font call sites.
- Photo/manual add-flow copy, controls, and readiness predicates.
- Shared Closet FIT DETAIL photo add/replace and current in-memory state wiring.
- Existing UI-test target updates, DEBUG-only deterministic failure/race seam, fresh simulator QA, and `.omo` evidence/state.

## Scope OUT (Must NOT have)
- My Page/settings, logo, splash, tabs, CTAs, scores, content headings, Fit Lab history detail ownership, routes, PBX, signing, backend, schema, networking, persistence, photo deletion, compression, or validation redesign.
- Stale duplicate trees, unrelated tracked/untracked files, commits, staging, stash/reset/clean, or user-owned simulator resources.

## Open questions
- None. Discovery resolved the state owner, exact typography boundary, readiness rules, and verification surface.

## Approval gate
status: completed
approved-by: user invocation of `$omo:start-work gmarket-topbars-fit-detail-photo.md ulw`
plan: `.omo/plans/gmarket-topbars-fit-detail-photo.md`
