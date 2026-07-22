# gmarket-topbars-fit-detail-photo - Work Plan

## TL;DR (For humans)
**What you'll get:** Fit Lab과 Closet 계열 상단 타이틀은 Gmarket Sans Bold로 통일되고, 옷 추가 화면에서 빠진 옷 사진 기능은 Closet FIT DETAIL에서 추가·교체할 수 있게 됩니다.

**Why this approach:** 두 공용 타이틀 컴포넌트만 바꿔 불필요한 폰트 변경을 막고, 사진은 현재 표시 중인 옷의 ID를 기준으로 기존 인메모리 상태에 반영해 잘못된 항목이 갱신되는 비동기 문제를 예방합니다.

**What it will NOT do:** My Page, 로고, 탭, CTA, 점수/콘텐츠의 Climate Crisis는 유지합니다. 백엔드·영구 저장·라우트·Xcode 프로젝트 구성은 바꾸지 않으며, 사진 삭제 기능도 추가하지 않습니다.

**Effort:** Medium
**Risk:** Medium - 시스템 사진 선택기의 비동기 완료 순서와 세 화면이 공유하는 상세 상태를 함께 검증해야 합니다.
**Decisions to sanity-check:** 사진은 앱 실행 중 메모리에만 유지하고, FIT DETAIL에서는 추가·교체만 지원하며, 폰트 변경 범위는 승인된 두 공용 타이틀로 제한합니다.

Your next move: 실행 승인은 이미 완료되었습니다. 독립 계획 검토를 통과한 뒤 테스트 우선으로 바로 구현합니다. Full execution detail follows below.

---

> TL;DR (machine): Medium effort, medium risk; two shared Gmarket Sans title changes, add-flow garment-photo removal, and validated latest-wins FIT DETAIL photo add/replace with full UI evidence.

## Scope
### Must have
- In the authoritative outer repository `/Users/jinu/Documents/coordit`, replace Climate Crisis with bundled Gmarket Sans Bold in exactly two shared iOS page-title components: `CoorditFitLabTitleCard` and `CoorditClosetTitleBar`.
- Keep all existing title text, size, `relativeTo`, tracking, card geometry, navigation, and accessibility labels unchanged unless visual QA proves clipping; any geometry adjustment must be the smallest title-only fix and be re-reviewed.
- In Closet “사진으로 첨부하기”, keep the size-chart picker and remove only the garment-photo picker/copy/readiness dependency; readiness becomes trimmed name + a selected size-chart image. Actual-picker QA proves that a decodable library image can be selected; do not invent new add-flow validation.
- In Closet “직접 입력하기”, remove the garment-photo card/copy/readiness dependency; readiness becomes trimmed name + all four existing category-specific measurement strings.
- In the Closet `FIT DETAIL` shared by top, bottom, and add-result, provide a `PhotosPicker` control with stable identifier `closet-detail-garment-photo`, empty/selected accessibility value, “옷 사진 추가하기” empty state, and “변경하기” populated state.
- Persist detail photo changes in the existing in-memory root state: update the exact displayed item by `item.id`; if no array item matches and the displayed ID is `closet-draft-preview`, update `draft.garmentImageData`; otherwise no-op.
- Preserve the prior image on picker cancel, transfer failure, corrupt/non-decodable data, or stale async completion; latest selection wins.
- Add failing-first XCUITest and DEBUG-only deterministic seams only as needed to prove add-flow readiness, exact-item mutation, corrupt preservation, and delayed-A/fast-B ordering without a new test target or PBX edit. The add-flow seam exposes only a known-valid size-chart fixture behind both UI-testing and task-specific launch flags.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- Do not edit `CoorditSettingsHeaderCard` or any My Page screen; the approved brief explicitly excludes unrelated My Page headers.
- Do not replace Climate Crisis in the COORDIT/splash brand, bottom navigation, primary CTA buttons, score headings, home cards, Closet score content, or any non-page-title content.
- Do not add/remove/rename routes, edit `CoorditFrameRoute.swift`, `project.pbxproj`, signing settings, backend, frontend, Supabase schema/storage, network clients, or persistence.
- Do not delete `CoorditClosetDraft.garmentImageData`; it remains the detail/add-result image state.
- Do not add numeric/range validation to manual measurements, image compression/resizing, delete-photo behavior, error banners, or unrelated redesign/refactor work.
- Do not edit quarantined duplicate trees under `coordit/{backend,frontend,docs,supabase}` or use nested Git discovery.
- Do not reset, checkout, stash, clean, erase shared simulators, shut down all simulators, broadly kill processes, remove unrelated untracked files, create a commit, or modify user-owned Xcode data.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: failing-first XCUITest for add-flow/detail behavior; static RED→GREEN plus runtime font-availability and real Simulator visual QA for typography because XCUI cannot inspect SwiftUI font family.
- Test target: existing `coorditUITests` only; new Swift/test source files are allowed by filesystem-synchronized groups, but `project.pbxproj` must remain byte-identical.
- Baseline characterization: before changing product code, run the current `CoorditFeatureFlowsUITests/testClosetAddMethodShowsRequiredPhotoInputs` on a fresh run-scoped simulator/result bundle and require it to pass the old behavior; capture source hashes and outer-root status.
- RED validity: each new test selector must compile, launch the intended screen, and fail on the intended assertion. CoreSimulator failure, timeout, compile failure, wrong selector, or missing test execution is not RED.
- GREEN validity: use new DerivedData and `.xcresult` paths per run, parse `xcrun xcresulttool get test-results summary --path <fresh.xcresult> --compact`, and require the named selector with zero failures; console banners alone are insufficient.
- Typography evidence layers: (STATIC) the two shared title `Text(title)` calls use `CoorditTypography.gmarketBold` and no `climate*`; (RUNTIME) `UIFont(name: "GmarketSansBold", size: 22) != nil` through a DEBUG-only diagnostic; (VISUAL) fresh screenshots show full unclipped/legible titles. Do not claim XCUI inspected the font family.
- Detail-photo real-surface proof: seed two visually distinct images into a run-created disposable iPhone 17 Pro simulator; add image A, navigate back/reopen the same item, replace with B, and prove the selected state/image changed. Cancel and invalid/stale test seams must preserve the prior image.
- Final regression uses the user-specified shared iPhone 17 Pro `404A9515-2B9F-42BF-A488-D3BC037002AF`: Debug build, focused selectors once, `CoorditFeatureFlowsUITests`, and `CoorditFinalRouteCoverageUITests`. Do not expand to Tab/full-target reruns unless a failure requires diagnosis.
- Adversarial classes are recorded with the smallest existing proof: malformed input (corrupt data rejected), cancel/resume (picker cancel or route reopen), stale state (unique hashes/paths/mtimes), dirty worktree (baseline/final allowlist), hung/long commands (bounded xcodebuild/bootstatus), flaky tests (fresh focused GREEN after prior failures), misleading success output (parsed named xcresult), and repeated interruptions (already-recorded task-owned interruptions); prompt injection is N/A.
- Evidence root: `.omo/evidence/gmarket-topbars-fit-detail-photo/<run-id>/` with `baseline/`, `red/`, `green/`, `visual/`, `adversarial/`, `cleanup/`, and `final/`; every artifact records command, UTC start/end, exit, HEAD, scoped source-manifest hash, simulator UDID/runtime, binary observable, and verdict.

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means you under-split.
- Wave 0 (serial): Todo 1 establishes immutable baseline, honest RED proofs, run-scoped evidence directories, and disposable simulator state.
- Wave 1 (maximum safe parallelism after Todo 1): Todos 2, 3, 4, and 5 run concurrently because they use separate product files/test files. Each lane creates and owns a unique disposable simulator plus unique DerivedData/xcresult paths, uses its own named test/static selector, and cleans only its resources. A lane enforces byte identity only for globally forbidden files; sibling changes to another lane's planned file are expected shared-worktree drift and are neither reverted nor claimed by that lane.
- Wave 2 (serial integration): Todo 6 resolves same-repo integration, runs the user-specified focused/regression set once on shared simulator `404A...`, the eight-route screenshot matrix, real picker add/replace, and cleanup. No Wave 1 checkbox is complete until an independent verifier confirms its DoneClaim.
- Final wave: F1–F4 run in parallel and all must approve; review-work and debugging gates follow before completion.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
- 1 Baseline + RED contract | none | 2, 3, 4, 5 | none |
- 2 Fit Lab title | 1 | 6 | 3, 4, 5 |
- 3 Closet title | 1 | 6 | 2, 4, 5 |
- 4 Add-flow inputs/readiness | 1 | 6 | 2, 3, 5 |
- 5 Detail photo state/picker | 1 | 6 | 2, 3, 4 |
- 6 Integrated GREEN + real-surface QA | 2, 3, 4, 5 | Final wave | none |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [x] 1. Freeze the outer-root baseline and capture faithful failing-first proofs
  What to do / Must NOT do: Run only from `/Users/jinu/Documents/coordit`. Record HEAD, Xcode version, `git status --porcelain=v2 --branch --untracked-files=all`, scoped SHA-256s, `project.pbxproj`/`CoorditFrameRoute.swift` hashes, and fresh simulator inventory. Create a unique run ID, disposable iPhone 17 Pro simulator, unique DerivedData/result paths, and evidence manifest. First run the unchanged old-behavior Closet add-input test GREEN as characterization. Then edit tests only: invert/remove the old garment-picker expectations, add readiness assertions, add detail control/state/persistence selectors, and add a static typography contract. Run each new selector before product edits and capture intended assertion RED. Must not accept compile/launch/CoreSimulator/timeout/wrong-selector failures; must not reuse result paths or edit production.
  Parallelization: Wave 0 serial | Blocked by: none | Blocks: 2, 3, 4, 5
  References (executor has NO interview context - be exhaustive): `AGENTS.md:11-20`; `coordit/AGENTS.md:3-9,34-58`; `coordit/coorditUITests/CoorditFeatureFlowsUITests.swift:45-117`; `coordit/coorditUITests/CoorditFinalRouteCoverageUITests.swift:5-83`; `coordit/coorditUITests/CoorditTabUITests.swift:9-77`; `coordit/coordit.xcodeproj/project.pbxproj:24-35,75-120`; `.omo/drafts/gmarket-topbars-fit-detail-photo-brief.md`.
  Acceptance criteria (agent-executable): baseline old test exits 0; each new focused selector appears in parsed fresh `.xcresult` and fails only the named new-behavior assertion; static typography contract is RED because both shared title structs still call Climate; no product/PBX/route file hash changes; test-only diff allowlist is exact.
  QA scenarios (exact tools + invocation): happy—`xcodebuild ... -only-testing:coorditUITests/CoorditFeatureFlowsUITests/testClosetAddInputsMatchRelocatedPhotoRequirements -resultBundlePath <run>/red-add.xcresult test`, then `xcrun xcresulttool get test-results summary --path ... --compact`; failure—launch/test infrastructure failure is recorded `BLOCKED` and rejected as RED. Evidence `.omo/evidence/gmarket-topbars-fit-detail-photo/<run-id>/baseline/` and `red/`.
  Commit: N | Draft message only: `test(ios): pin closet photo relocation behavior`

- [x] 2. Change the Fit Lab shared page-title font only
  What to do / Must NOT do: In `CoorditFitLabTitleCard`, replace only the title `climate2019` call with `CoorditTypography.gmarketBold`, preserving 22pt metric, `.headline`, tracking, colors, geometry, button behavior, and accessibility. Do not touch `CoorditFitLabPrimaryButton`, score headings, Fit Lab content, routes, font assets, or registration.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 6 | Parallel with: 3, 4, 5
  References: `coordit/coordit/CoorditFitLabComponents.swift:12-67`; `coordit/coordit/CoorditFitLabScreens.swift:8-43`; `coordit/coordit/CoorditTypography.swift:5-39`; `coordit/coordit/CoorditFontRegistration.swift:5-20`; `coordit/coordit/coorditApp.swift:8-10`; `coordit/coordit/CoorditFitLabScoreComponents.swift:12-15`.
  Acceptance criteria: the Fit-Lab-only static selector flips RED→GREEN at the exact `Text(title)` call independently of the Closet selector; `UIFont(name: "GmarketSansBold", size: 22)` diagnostic succeeds in DEBUG; route coverage retains the Fit Lab title consumers and `fitlab-input` provides the required final screenshot; globally forbidden Climate call sites remain byte-identical.
  QA scenarios: happy—build/install/launch `fitlab-input` and `fitlab-history-detail`, capture fresh PNGs and verify complete `FIT LAB`/`FIT DETAIL` text; failure—runtime diagnostic false, ellipsis, clipping, fallback/CJK baseline anomaly, or any forbidden hash change blocks completion. Evidence `<run>/green/task-2-*` and `<run>/visual/fitlab-*.png`.
  Commit: N | Draft message: `style(ios): use gmarket sans for fit lab title bar`

- [x] 3. Change the Closet shared page-title font only
  What to do / Must NOT do: In `CoorditClosetTitleBar`, replace only the title `climate2019` call with `CoorditTypography.gmarketBold`, preserving 22pt metric, tracking, geometry, back action, and accessibility label. Do not touch `CoorditClosetPrimaryButton`, score headings, logo/tab typography, `CoorditSettingsHeaderCard`, or My Page files.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 6 | Parallel with: 2, 4, 5
  References: `coordit/coordit/CoorditClosetComponents.swift:16-40,96-124`; `coordit/coordit/CoorditClosetScreens.swift:60-117`; `coordit/coordit/CoorditClosetDetailScreen.swift:5-84`; `coordit/coordit/CoorditClosetAddFlow.swift:145-410`; `coordit/coordit/CoorditSettingsComponents.swift:14-50`; `coordit/coordit/Main01DesignTokens.swift:126-134`; `coordit/coordit/Main01Header.swift:53-100`.
  Acceptance criteria: the Closet-only static selector flips RED→GREEN independently of the Fit Lab selector; existing title consumers render `CLOSET`, `FIT DETAIL`, `ADD CLOTHES`, `LINK INPUT`, `PHOTO INPUT`, `MANUAL INPUT`, and `FIT CHECK`; globally forbidden title/content hashes remain unchanged. This lane uses its own disposable simulator and run-scoped paths.
  QA scenarios: happy—final QA launches the seven user-specified Closet routes (`closet-overview`, add method/link/photo/manual/loading, detail top), asserts each identifier, and captures fresh screenshots; failure—any title clipping/overlap/truncation, changed CTA/score/logo/tab/My Page source, or stale screenshot manifest blocks completion.
  Commit: N | Draft message: `style(ios): use gmarket sans for closet title bars`

- [x] 4. Remove garment-photo inputs from photo/manual add flows and update readiness
  What to do / Must NOT do: Update `CoorditClosetAddMethod` descriptions to size-chart-only/photo-free manual copy. Photo route keeps a full-width size-chart picker and requires trimmed name + selected size-chart only; remove `closet-garment-photo`. Manual route removes the garment-photo form card/identifier and requires trimmed name + all four existing category-specific strings. Preserve `garmentImageData`, link flow, measurement labels/semantics, CTAs, score logic, routes, and no numeric/image validation redesign. Use the tests written in Todo 1; place any additional add-flow tests in an add-flow-specific UI test file to avoid Wave 1 conflicts. If automated readiness needs injection, add only a DEBUG build + `--coordit-ui-testing` + `--coordit-test-valid-size-chart` gated fixture seam, observable through `closet-size-chart-photo` becoming selected; it must be absent/inert otherwise.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 6 | Parallel with: 2, 3, 5
  References: `coordit/coordit/CoorditClosetAddFlow.swift:4-75,97-139,145-390,490-569`; `coordit/coorditUITests/CoorditFeatureFlowsUITests.swift:57-106`; `coordit/AGENTS.md:42-58`.
  Acceptance criteria: photo screen contains `closet-size-chart-photo` and no `closet-garment-photo`; name-only is disabled, known-valid fixture+name enables submit; manual contains measurement IDs 0...3 and no manual garment picker, remains disabled through three fields, enables after four+name; Link Input tests remain green; picker cancel leaves state unchanged. No corrupt-size-chart contract is claimed because add-flow validation is outside scope.
  QA scenarios: happy—focused XCUITest drives overview→add method, uses the dual-gated known-valid size-chart seam, verifies the slot's selected observable and photo submit transition, then manual 0→4 fields; failure—missing name, no selection, or only 0–3 measurements must keep submit disabled. Integration QA separately selects a real seeded library image and cancels the picker. Parse named test summaries from fresh `.xcresult`. This lane owns a unique disposable simulator and run paths. Evidence `<run>/green/task-4-add-flow.*` and screenshots for photo/manual.
  Commit: N | Draft message: `feat(ios): move garment photo out of closet add forms`

- [x] 5. Add a validated latest-wins garment photo control to Closet Fit Detail
  What to do / Must NOT do: Make only `CoorditClosetItem.imageData` mutable (or replace array elements immutably), pass the actual displayed item ID through the shared detail API, and commit by ID lookup at async completion. If no array match and ID is `closet-draft-preview`, update `draft.garmentImageData`; otherwise no-op. Add a detail-specific `PhotosPicker` on the 168×158 artwork with identifier `closet-detail-garment-photo`, accessibility value `empty|selected`, add/replace copy, and decode validation. Own the monotonically increasing per-item selection generation above the transient detail view in `CoorditClosetFamilyView`; increment it for every selection and invalidate it when that displayed detail disappears. Commit only when both the item ID and generation still match at async completion, so a reconstructed detail view cannot revive stale work. Cancel, transfer failure, corrupt bytes, and stale A preserve the previous/latest valid image. Provide a DEBUG-only deterministic UI-test seam gated by `--coordit-ui-testing` and a task-specific launch flag to inject corrupt and delayed-A/fast-B results; it must be absent/inert in non-DEBUG builds. Do not capture array indices, use detail-local authoritative image state/generation, delete photos, alter routes, persist to disk/network, or edit PBX.
  Parallelization: Wave 1 | Blocked by: 1 | Blocks: 6 | Parallel with: 2, 3, 4
  References: `coordit/coordit/CoorditRootView.swift:4-62`; `coordit/coordit/CoorditClosetScreens.swift:16-29,33-95,175-213`; `coordit/coordit/CoorditClosetDetailScreen.swift:5-66`; `coordit/coordit/CoorditClosetComponents.swift:127-199`; `coordit/coordit/CoorditClosetAddFlow.swift:45-75,121-139,490-554`; `coordit/coorditUITests/CoorditFeatureFlowsUITests.swift:45-106`.
  Acceptance criteria: focused RED→GREEN proves control/state on top, bottom, and actual add-result; valid A changes only displayed item image and grid/detail recompute; reopening same item remains selected; valid B replaces A; corrupt/cancel/failed/stale A never replaces B; delayed A followed by route-away/reopen and fast B still ends at B; direct top/bottom fallback updates matching seed ID; direct add-result preview updates draft; item count/order/non-image fields/selection/category unchanged; `project.pbxproj`, route, backend/schema hashes unchanged.
  QA scenarios: happy—on its own disposable simulator seeded with distinct A/B, navigate overview→detail, select A, back/reopen, select B, and capture state/image screenshots; separately navigate link add→actual add-result and add an image. Failure—DEBUG seam sends corrupt data, then delayed A, navigates away/reopens, and sends fast B; final accessibility value/hash must remain selected/B. The lane owns unique DerivedData/xcresult paths and cleans only its simulator. Evidence `<run>/green/task-5-detail.*`, `<run>/visual/detail-*`, `<run>/adversarial/detail-*`.
  Commit: N | Draft message: `feat(ios): add garment photo editing to closet fit detail`

- [x] 6. Integrate, prove GREEN repeatedly, run real-surface QA, and clean task-owned resources
  What to do / Must NOT do: Re-read final diff and plan. Resolve only integration issues within allowed files. On shared simulator `404A...`, run focused selectors once, `CoorditFeatureFlowsUITests`, `CoorditFinalRouteCoverageUITests`, Debug build, typography runtime/static checks, exactly the eight user-specified route screenshots, real PhotosPicker add then replace with before/after state evidence, and final source/dirty allowlist. Reuse existing malformed/cancel/stale/interruption evidence instead of rerunning it. Create `manualQa.md`, parsed summaries, artifact manifest, and cleanup receipt. Terminate the app and close the Computer Use session; do not delete or change the ownership/boot state of shared simulator `404A...`. Remove only run-ID temp paths after copying evidence and verify no QA process remains.
  Parallelization: Wave 2 serial integration | Blocked by: 2, 3, 4, 5 | Blocks: F1–F4
  References: all references above; `coordit/coorditUITests/CoorditFeatureFlowsUITests.swift`; `coordit/coorditUITests/CoorditFinalRouteCoverageUITests.swift`; `.omo/start-work/ledger.jsonl` evidence schema.
  Acceptance criteria: named focused tests/zero failures parsed once from fresh xcresults; Debug build, `CoorditFeatureFlowsUITests`, and `CoorditFinalRouteCoverageUITests` exit 0 on `404A...`; the eight specified screenshots are fresh and reviewed; actual PhotosPicker before/add/replace evidence passes; static/runtime/visual typography agrees; final diff is restricted to planned iOS/test/.omo files; forbidden hashes unchanged; no QA process/temp resource remains.
  QA scenarios: exact `xcodebuild -project ... -destination 'platform=iOS Simulator,id=404A9515-2B9F-42BF-A488-D3BC037002AF' ...`; direct route launch/screenshot for the eight listed routes; Computer Use drives actual PhotosPicker add and replace. Evidence `<run>/final/`, `<run>/manualQa.md`, `<run>/cleanup/receipt.md`.
  Commit: N | Draft final atomic messages only; do not stage or commit without user authorization.

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE; the already-authorized start-work execution completes automatically once every delegated and global gate passes.
- [x] F1. Plan compliance audit — independent reviewer maps final diff/evidence to every Must have/Must NOT have and each Todo acceptance criterion; reject self-report, stale manifests, or missing parsed tests.
- [x] F2. Code quality/security review — independent reviewer checks Swift value semantics, displayed-ID update, latest-wins async behavior, corrupt preservation, accessibility, release gating of DEBUG seams, memory/safety, and no hidden persistence/permission changes.
- [x] F3. Real manual QA — independent QA executor reviews the eight specified fresh screenshots and actual PhotosPicker before→add→replace flow on shared simulator `404A...`; verifies app/process cleanup without deleting the shared device and returns an unconditional verdict.
- [x] F4. Scope fidelity/context audit — independent reviewer refreshes outer Git state, approved brief, repository rules, forbidden hashes, and validates no My Page/logo/tab/CTA/score/backend/schema/route/PBX/unrelated file drift.

## Commit strategy
- No commit, staging, PR, merge, worktree creation, or branch rewrite is authorized by this request.
- Preserve changes unstaged. Provide suggested Conventional Commit messages only if handoff is requested later.
- If the user later authorizes commits, keep typography, add-flow, and detail-photo behavior atomic; every commit must build/test green and include `Plan: .omo/plans/gmarket-topbars-fit-detail-photo.md`.

## Success criteria
- Both approved shared page-title components use bundled Gmarket Sans Bold; the eight user-specified route screenshots render complete unclipped titles and route coverage protects the remaining consumers; all explicitly out-of-scope Climate Crisis sites remain unchanged.
- Photo input no longer displays/requires a garment photo and becomes ready with name + selected size chart; manual input no longer displays/requires a garment photo and becomes ready with name + four existing fields; Link Input and category semantics regressions are absent.
- Closet Fit Detail on top, bottom, and actual add-result supports validated add/replace; image changes update the exact displayed in-memory item/draft, survive route away/reopen, and reject corrupt/cancelled/stale results without altering unrelated item state.
- Debug build, focused tests once, FeatureFlows and FinalRouteCoverage suites on `404A...`, static/runtime/eight-route visual typography checks, actual picker add/replace QA, recorded adversarial evidence, dirty allowlist, and cleanup pass with fresh evidence.
- F1–F4 and the mandatory `review-work` five-lane global gate approve; the debugging audit names and rules out/confirms at least three plausible runtime hypotheses with actual artifacts; Boulder and ledger are complete and no QA resource remains.
