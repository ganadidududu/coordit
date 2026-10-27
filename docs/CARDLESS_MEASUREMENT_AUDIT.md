# Cardless garment measurement audit

Audit date: 2026-10-27 (Asia/Seoul). Remote fetched before changes.
Base: origin/codex/camera-auto-guides = cad9318ae0c6f54f84cea4665390f3fe2c01e863.
Working branch: codex/camera-auto-guides (user explicitly requested continuing here after initial isolation). No push or production migration authorized/performed.

## Current behavior and compatibility boundaries

- `CoorditGarmentCaptureController.swift`: LiDAR or card; `setImage` selects card, renders upright bitmap at <=2400px. Async Vision proposals use a revision token. AR uses horizontal plane raycasts plus medium depth confidence; `attach` unconditionally requests sceneDepth. Live snapshot proposals are discarded on pose movement, but do not retain a calibrated capture frame. Card handles already support dragging.
- `CoorditGarmentCaptureGuide.swift`: all 11 categories; skirt uses waist/hip/total_length, no rise/outseam. CoreMotion posture guidance; camera picker is separate from ARSCNView.
- `CoorditGarmentOutlineDetector.swift`: Vision contours/foreground mask and heuristic `landmarks`; boundary extrema are proposals, not learned seam locations. Keep as offline fallback.
- `CoorditGarmentMeasurementGeometry.swift`: card homography in meters; distances in cm; method raw values `lidar`, `card`; optional category preserves older records. Finite/range checks in initializer. Existing Codable decoding bypasses initializer validation, so new inference boundaries must validate independently.
- `CoorditGarmentCategorySelector.swift`, `CoorditFitLabModels.swift`: existing category selection/model remains authoritative (tshirt, shirt, sweatshirt, hoodie, knit, jacket, coat, pants, jeans, shorts, skirt).
- `CoorditFitLabCameraComparison.swift`: category, live/photo canvas, editable handles, same-analysis retry; keep report and analysis orchestration unchanged.
- `CoorditCameraReference.swift`: POST with measurement UUID idempotency, PATCH on remeasurement, existing measurement keys. Add distinct method source strings only; no required API fields.
- `CoorditGarmentPhotoStore.swift`: local per-account/item JPEG storage. No upload or consent to train implied by capture/correction.
- Android `ui/fitlab` / `data/fitlab`: manual/OCR/URL product sizes, no garment AR capture parity. Add optional AR module incrementally; never reinterpret OCR as camera measurement.
- Backend is **Express + TypeScript**, not NestJS. Existing modules include fit, fit-report, thread-wallet and clothing CRUD. Do not replace framework or change billing, RPC, RLS or operating schema.
- `coorditTests/CameraDataset`: 16 aRTF development evaluation images, not an independent test set, no cm ground truth. Exclude all publisher test partition (garments/scenes distinct from publisher train) from training/validation; keep file hashes and source paths in permanent denylist.
- `Info.plist`: production camera comparison flag false (DEBUG currently exposes legacy camera). New flags must remain false in DEBUG too unless explicitly configured.

## File plan and risks (recorded before implementation)

| Area/files | Change | Risk/control |
| --- | --- | --- |
| New `CoorditARPlaneMeasurement.swift`, capture controller | frozen frame intrinsics/pose/display mapping, stable plane gate, same-plane ray/3D distances | reject tracking interruption, changed orientation, grazing ray, stale scale/plane; hardware validation still required |
| Measurement geometry, CameraReference | additive methods/status/evidence | preserve old raw values, optional metadata, test old payload decode; never save uncalibrated RGB |
| Camera comparison + Info.plist | opt-in AR path and frozen-frame correction using existing design controls | false flags preserve existing flow; camera/photo permissions unchanged |
| New Android AR adapter and optional capture surface | ARCore runtime availability, horizontal hits, pose/quality evidence | optional ARCore manifest, no mandatory AR hardware; manual input fallback |
| New `ml/` package + registry + CI | fail-closed provenance, approved loaders, conversion/dedup/group splits, procedural data, from-scratch baseline, independent inference service | no unknown rights, no pretrained downloads, no empty success, no deployment approval implied |
| New RGB calibration module | measured/estimated/needs_calibration/failed outcomes | no cm from focal length alone; metric weights quarantined pending training-rights review |
| Tests/docs/notices | reproducible commands, per-category counts and evidence | sensor accuracy and legal uncertainty explicitly unverified |

## Baseline

Backend `npm run typecheck`, `test:camera-comparison`, `test:report`, `test:fit`: passed on unmodified base (including local fixture DB billing/ACL/rollback checks).
iOS full unit baseline: 42 executed, 27 passed, 15 existing GuestSessionRecovery failures (`unavailable` at line 267), recorded in `/tmp/coordit-cardless-evidence/baseline.xcresult`; final outcome recorded in implementation report.
SimSlim list/on/verify and doctor push,storekit,universal-links,keychain-sync,photos completed for iPhone 17e `5223FFAB-50AF-4410-926A-5C4506E34937`, iOS 26.5; 96 services matched, 5/5 capabilities passed. Xcode 26.6. Simulator cannot validate camera, physical scale or depth.
Android SDK 35/36 available, host Java 25; Gradle/JDK compatibility must be checked before claiming build success.

## Phase 1 implementation evidence

- iOS non-LiDAR AR uses horizontal plane geometry without sceneDepth. A captured sensor bitmap, intrinsics, camera/plane poses, orientation and plane polygon are immutable during Vision/manual editing. Rays intersect that captured plane; points outside its polygon or behind/grazing the camera are rejected. Live plane history requires >1s, >3cm camera motion, then >0.3s stillness. These are engineering rejection gates, **not** validated accuracy statistics.
- Existing card/LiDAR values and optional Codable metadata retained. `ar_plane` is distinct from `card_camera`/`lidar_ar`. RGB estimates are prohibited from the measured initializer. New flags all false, including DEBUG.
- iOS targeted unit run: 27/27 passed in `/tmp/coordit-cardless-evidence/phase1.xcresult` (5 new plane tests, 17 garment tests, 5 camera analysis tests). Full base had 15 existing guest recovery failures; these were not rewritten.
- Android: optional ARCore 1.57.0 dependency; runtime session factory and same-frame endpoint hit-test adapter with plane/tracking/scale rejection, complete 11-category dimension policy. `testDebugUnitTest assembleDebug` passed with Android Studio bundled JDK. Subsequent implementation added an OpenGL AR camera surface, same-frame YUV bitmap/pose/intrinsics freeze, orientation-aware planar rays, manual draggable points and confirmation, and handoff into the existing closet form/photo/save path. The existing FitLab consumes that wardrobe garment. No card workflow was invented for Android (none existed); unsupported AR uses existing manual input. Android skirt manual/save schema now correctly uses waist, hip and total length. Hardware AR accuracy remains unverified.
- Hardware tests still required: real world scale, temporal scale drift, all phone orientations, plane reacquisition, physical measurement vs tape, glass/textured/occluded surfaces and thin garment offset from table.
