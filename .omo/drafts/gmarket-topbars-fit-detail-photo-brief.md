# gmarket-topbars-fit-detail-photo approved brief

- status: awaiting-approval
- intent: clear
- review_required: false
- pending_action: write `.omo/plans/gmarket-topbars-fit-detail-photo.md`
- test_strategy: tests-after plus agent-executed simulator visual QA

## Components ledger

1. `topbar-typography` — All iOS page-title bars used by Fit Lab and Closet/add/detail routes use bundled Gmarket Sans Bold instead of Climate Crisis. Status: grounded. Evidence: `coordit/coordit/CoorditFitLabComponents.swift`, `coordit/coordit/CoorditClosetComponents.swift`, `coordit/coordit/CoorditTypography.swift`, `coordit/coordit/CoorditFontRegistration.swift`.
2. `add-flow-photo-removal` — Photo input keeps only the size-chart photo; manual input keeps only measurements; copy and submit readiness match the new requirements. Status: grounded. Evidence: `coordit/coordit/CoorditClosetAddFlow.swift`.
3. `closet-fit-detail-photo` — Closet Fit Detail lets users add or replace the garment photo and updates the selected in-memory closet item. Status: grounded. Evidence: `coordit/coordit/CoorditClosetScreens.swift`, `coordit/coordit/CoorditClosetDetailScreen.swift`, `coordit/coordit/CoorditRootView.swift`.
4. `regression-qa` — UI tests assert the removed controls, retained size-chart/measurement controls, and new detail photo control; build and screenshots run on iPhone 17 Pro. Status: grounded. Evidence: `coordit/coorditUITests/CoorditFeatureFlowsUITests.swift`, `coordit/coorditUITests/CoorditTabUITests.swift`.

## Decisions

- Target the authoritative outer repository `/Users/jinu/Documents/coordit`; do not touch the stale nested web/backend/docs copies.
- Interpret “Fit Detail” as the Closet detail shared by `closetDetailTop`, `closetDetailBottom`, and `closetAddResult`, not Fit Lab history detail.
- Use `CoorditTypography.gmarketBold` for page-title emphasis; do not replace Climate Crisis in the logo, bottom navigation, CTA buttons, scores, or content headings.
- Change the two shared title components, which covers `FIT LAB`, Closet `FIT DETAIL`, `CLOSET`, `ADD CLOTHES`, `LINK INPUT`, `PHOTO INPUT`, `MANUAL INPUT`, and `FIT CHECK`.
- Keep the prototype’s existing in-memory `Data?` model; no backend, Supabase Storage, schema, or persistence work.
- In photo input, keep size-chart photo required and remove garment photo. In manual input, require name plus all four measurements and remove garment photo UI.
- Fit Detail supports add and replace, not delete. Preserve the existing placeholder when no image exists.
- Keep route vocabulary and Xcode project file unchanged.
- Preserve unrelated untracked files in the dirty worktree.

## Planned approach

1. Update shared iOS title components to Gmarket Sans Bold while retaining existing sizing/layout unless simulator QA finds clipping.
2. Remove garment-photo copy/UI/readiness dependencies from photo/manual add flows; keep draft compatibility for the detail result.
3. Make closet item image state mutable, add a selected-item image update seam, and wrap the existing Fit Detail artwork with a detail-specific `PhotosPicker` control.
4. Update XCUITests for control relocation, run the focused flow tests and full route coverage, and capture simulator screenshots for all affected title/detail routes.

## Scope guardrails

- Must not edit product code before plan approval/execution.
- Must not migrate or persist closet photos outside current app memory.
- Must not change the COORDIT logo, tab-bar typography, CTA typography, scoring behavior, routes, or unrelated My Page screens.
- Must not edit duplicate `coordit/{backend,frontend,docs,supabase}` trees.

## Baseline

- `xcodebuild` Debug build succeeded on iPhone 17 Pro simulator `404A9515-2B9F-42BF-A488-D3BC037002AF` before changes.
