# Cardless measurement: Phase 0–2 checkpoint (2026-10-27)

Subsequent update: [AR accuracy fixes and original-author real-photo acquisition](CARDLESS_ACCURACY_AND_REAL_DATA.md). That update supersedes the real-photo counts and test totals below, records the registry change that invalidates historical checkpoints, and keeps mathematical tests separate from real sensor accuracy. The following remains the historical training/integration checkpoint.

Work stays on `codex/camera-auto-guides`. The audited remote starting revision is `cad9318ae0c6f54f84cea4665390f3fe2c01e863`. No production migration, deployment, push or feature activation was performed. Phase 3 source changes are parked outside the tracked implementation in `.omo/deferred-phase3/2026-10-27/`; single-photo metric-depth work is deferred at the user's request.

## Status and architecture

| Phase | Implemented and executed | Still not proven |
|---|---|---|
| 0 Audit | Existing iOS/Android/backend analysis, rights registries, baseline tests, file/risk plan (`CARDLESS_MEASUREMENT_AUDIT.md`) | Pending original-image rights cannot be inferred from a platform badge |
| 1 Cardless AR | iOS non-LiDAR horizontal planes, frozen camera intrinsics/pose/image/orientation/plane; quality rejection; heuristic/manual/drag endpoints; legacy LiDAR/card preserved. Android optional ARCore session + live camera + same-frame frozen geometry + review/apply to existing closet form | Real sensor accuracy, interruptions and recovery across phones, MAE/P95 against independent tape measurements |
| 2 AI | Actual approved data download/conversion, provenance and leakage checks, two architecture/head comparisons, real CPU/MPS training, evaluation, checkpoint/resume, ONNX export/check, isolated authenticated Python inference, authenticated backend gateway and explicitly consented mobile proposal requests; failures preserve existing measurements | Real semantic landmark labels/photos for nine categories; real holdout accuracy for all categories; real-phone end-to-end AR+AI validation and commercial release approval |
| 3 Single RGB | Deferred. Reserved additive method value and false flag remain from schema preparation | No metric-depth model or validated absolute-scale estimator is deployed |

The executable path is mobile frozen capture → explicit per-photo processing consent → existing user bearer authentication at `/garment-landmarks` → bounded independent Python `/v1/landmarks` → normalized semantic proposals → local frozen AR/card geometry → mandatory user review/drag correction → existing closet/FitLab save and analysis. The app never receives the Python service secret. On-device inference can replace the provider through the inference interface.

The backend gateway is research-only and refuses `NODE_ENV=production`; its flag defaults false. Both app AI flags and their separate development-proposal flags default false. Release builds cannot accept development proposals. Every model response still says `deployment_approved: false`; it never supplies centimeters. A proposal's visibility/classification score is uncalibrated and is not an error interval. Invalid mask coverage, collapsed segments, unsupported auxiliary categories, occluded/low-score points or points outside the mask produce a refusal. Mobile consumers also reject category/coordinate/schema mismatches and invalid physical geometry. An AI failure does not delete previous measurements.

Photo processing uses HTTPS on mobile, rejects redirects, re-encodes upright bounded JPEG pixels without GPS metadata, authenticates each request, has bounded bodies/timeouts/concurrency, and uses no photo persistence or training collection. Loopback HTTP is permitted only for the server's local research upstream. The UI's consent applies only to this photo's inference; it is never permission for training. There is no third-party hosted AI API. Deployment behind HTTPS, access policy and a real processing-location/privacy notice must be reviewed before activation.

## Rights and actual data

See `ml/registry/DATASET_MANIFEST.json`, `ml/registry/MODEL_MANIFEST.json`, `DATASET_LICENSES.md`, `MODEL_LICENSES.md`, and `THIRD_PARTY_NOTICES.md` for separate original-image, annotation, code, weight and terms records. The loader, CI inventory and inference artifact loader fail closed. Model loading verifies checkpoint SHA, training manifest pins, current registry identity and current source approval. A registry change invalidates existing artifacts until reviewed/retrained.

- aRTF: original Ghent/publisher evidence and CC BY 4.0 recorded. The actual resized archive was downloaded (309 MB), publisher MD5 verified, SHA-256 `2f9ad46db331f533d71b0867304deb0d66f8599d7e143006e5212aeac4ff04aa`. The loader accepts 524 images from the publisher train/validation pool: 210 T-shirts, 104 shorts, 210 auxiliary towels. All 980 publisher test images are excluded, including the existing 16 development fixtures and associated test family. Per-garment IDs are unavailable in the remaining pool, so all real records are training-only. No real holdout result is claimed. aRTF's original keypoint namespace is retained and is not relabeled as seam ground truth.
- Procedural v1: 330 actual images, 30/category. Procedural v2: 1,320 actual new identities, 120/category; construction cues, collars/buttons/zippers/hoods/knit/denim/skirt pleats, masks, explicit semantic 2D/3D points, camera matrices and known synthetic cm. Only authored geometry/colors/lines, no external asset. Wrinkles are shading, not cloth physics; these are limited domain simulations.
- Open Images V7 and Fashionpedia: pending original-image rights, despite reusable annotations. All seven requested Roboflow candidates remain pending original sources/uploader authority/platform rights; the 17,000-image candidate is not approved. DeepFashion/DeepFashion2/ModaNet remain blocked without commercial rights. Additional GarmentCode/ETH access and GarmageSet restrictions remain documented. None entered training.
- No third-party pretrained weights were downloaded or embedded. MMPose/SAM2/RF-DETR code/weights/data are separately reviewed candidates, not implicit approvals. Depth Anything remains pending and Phase 3 is deferred. App/server deployed-weight lists remain empty in `ml/registry/MODEL_ARTIFACTS.json`.

| Category | Approved real photos | Procedural v1 / v2 | Independent real cm evaluation |
|---|---:|---:|---:|
| T-shirt | 210 | 30 / 120 | 0 |
| Shirt | 0 | 30 / 120 | 0 |
| Sweatshirt | 0 | 30 / 120 | 0 |
| Hoodie | 0 | 30 / 120 | 0 |
| Knit | 0 | 30 / 120 | 0 |
| Jacket | 0 | 30 / 120 | 0 |
| Coat | 0 | 30 / 120 | 0 |
| Pants | 0 | 30 / 120 | 0 |
| Jeans | 0 | 30 / 120 | 0 |
| Shorts | 104 | 30 / 120 | 0 |
| Skirt | 0 | 30 / 120 | 0 |

Additionally 210 real auxiliary towels; boxer shorts are a separate schema class but absent from the downloaded resized archive. The tracked file inventory has 2,174 distinct accepted records across these three corpora; augmentation copies are not counted as independent garments. V2 splits are 1,108 train / 110 validation / 102 test. Hashes, source groups and files are recorded in `ml/reports/SOURCE_FILES.jsonl`.

## Actual training and results

The earlier 64×64 pooled/regression v1 baseline trained on CPU and Metal but performed poorly; its reports are retained rather than presented as a finished model. V2 uses a project-owned randomly initialized convolutional spatial encoder, skip segmentation decoder, 64×64 semantic heatmaps, visibility head and a category classifier. It balances mask BCE/Dice, Gaussian heatmap supervision and visible-only coordinate loss. No aRTF seam labels are fabricated.

Both V2 shared and per-category heads actually trained on Apple Metal for **35 epochs each**, batch 12, learning rate .001, seed 42, requested synthetic fraction .7. The train pool was **1,632 distinct images** (524 real + 1,108 synthetic); all were seen across the run. Balanced epoch sampling used 1,582 exposures/epoch, **55,370 exposures per run**; exposures are not independent image counts. CPU forward/backward and learnability/resume tests also actually ran.

| Model / evaluation | Macro-F1, present classes | Segmentation mIoU | Interpretation |
|---|---:|---:|---|
| V2 shared, synthetic validation (110) | 0.8891 | 0.9709 | Selected development candidate by validation |
| V2 category heads, synthetic validation (110) | 0.8237 | 0.9630 | Comparison; not selected |
| V2 shared, held-out synthetic test (102) | 0.8920 | 0.9767 | Synthetic domain only; not real/cm accuracy |

Synthetic validation landmark PCK@0.05 image diagonal is 1.0 across present categories; per-category NME and missing/condition/latency/memory metrics are in `ml/reports/spatial-v2-*-validation.json` and `spatial-v2-shared-test.json`. The synthetic shapes and labeled conventions are intentionally simple; this high PCK does not establish real seam detection. All real category holdout scores are explicitly `unverified`. No MAE/P95 in centimeters can be reported without independent real tape measurements.

Local ignored checkpoints are `ml/artifacts/spatial-v2-shared/checkpoint.pt` and `ml/artifacts/spatial-v2-category/checkpoint.pt`; artifact metadata, hashes, optimizer/RNG states, logs and seen identities live beside them. The selected model has 1,637,312 parameter bytes (~1.56 MiB). V2 ONNX export and `onnx.checker` actually passed (`ml/artifacts/spatial-v2-shared/model.onnx`); Core ML and ONNX Runtime device inference remain untested. Reports/version hashes are tracked; model/data binaries are ignored.

## Regression results and limits

Evidence root: `/tmp/coordit-cardless-evidence/`. SimSlim list/profile/verify and doctor for push/StoreKit/links/keychain/photos were performed. Sensor tests are not substituted by simulator fixtures.

- iOS full unit suite: **54/54 passed** in `phase2-final-privacy-fixed-ios.xcresult`, including authenticated upload/GPS stripping and research-only proposal opt-in. Final acceptance rerun after gateway lifecycle wiring is recorded in `phase2-acceptance-ios.xcresult`. Camera UI: **8/8 passed**, covering card measurement, one-thread charge, same report/retry, zero-balance rejection, photo-to-closet, OCR/manual fallback and accessibility text. An unsigned build had baseline keychain failures; signed simulator tests resolved them. Three baseline UI failures were traced to a DEBUG UI-test balance fixture being zeroed before its bypass guard; moving only that test-route guard preserves production logout balance reset and the real zero-balance test now still passes.
- Android: **70/70 unit tests** and **2/2 instrumentation capture/drag/confirmation/apply/cancel tests** passed on API 36 emulator (`phase2-final-all-android-retry.log`). These use explicit frozen geometry fixtures, not real ARCore sensor evidence. Initial instrumentation attempt had no connected device; the actual retry passed after starting the emulator.
- ML: **17/17 tests** passed; Ruff passed; basedpyright has **0 errors, 26 dependency-stub warnings**. CPU spatial learnability, checkpoint resume/tampering, rights denial, grouped leakage, full category/skirt schema, refusal of synthetic/non-independent cm release data and incomplete coverage were exercised. Tracked inventory audit accepted 2,174 records.
- Backend: typecheck plus existing camera comparison/report/fit/thread-wallet suites passed; new authenticated gateway tests **5/5 passed**. Existing local transactional one-debit/idempotency/rollback tests passed without accessing production SQL. A real loopback Python server using the V2 checkpoint returned HTTP 200 with 8 semantic points and no cm, rejected missing auth with 401 and missing consent with 403 (`phase2-spatial-service-smoke.json`). Invalid deployment approval from an upstream is rejected by the gateway.
- Compatibility fixes: restore now passes optional AR evidence when validating saved AR results; malformed evidence is refused; skirt camera registration carries waist/hip/total length and clears trouser-only fields; retake resumes the AR session; method switching remounts the AR view. Legacy `lidar`/`card` raw values and existing API fields/billing paths remain intact.

## Reproduction and release requirements

See `ml/README.md` for locked environment, training, resume/evaluation and server commands. App build/test commands and exact flags are below. Never put a shared ML token in an app or Git. The listed commands do not deploy or activate features.

```sh
# From repo root; prepare simulator with SimSlim first.
simslim list --json
simslim on <UDID> --profile config/simslim/coordit-dev.json
simslim verify <UDID> --profile config/simslim/coordit-dev.json
simslim doctor <UDID> --requires push,storekit,universal-links,keychain-sync,photos
xcodebuild test -project coordit/coordit.xcodeproj -scheme coordit -destination 'platform=iOS Simulator,id=<UDID>' -only-testing:coorditTests -only-testing:coorditUITests/CoorditCameraComparisonUITests CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ANDROID_HOME="$HOME/Library/Android/sdk" ./android/gradlew -p android testDebugUnitTest assembleDebug
npm --prefix backend run typecheck
npm --prefix backend run test:garment-landmarks
```

To close Phase 2's commercial acceptance, independently source/label lawful real garment photographs for all 11 categories, hold out real garments/scenes/devices, obtain at least 20 tape-measured independent garments per category/part, and run repeated real-phone AR+AI measurements. The cm evaluator emits all 43 required category/part groups per supplied method, including missing groups as failures; at least 20 **successful** garments, MAE ≤1 cm, P95 ≤2 cm and project-policy ≥95% success are required for each. It refuses synthetic/non-independent data and skirt rise/outseam labels. Legal review must close every source/weight/terms obligation; privacy/HTTPS access control and device interruptions must be verified. Until those external evidence gaps close, **Phase 2 is an implemented and tested development system, not a fully validated commercial measurement system**, and production flags/weight lists remain disabled. Phase 3 must wait.

Final tree verification: `phase2-acceptance-ios.xcresult` passed **54/54** unit tests. The separately completed camera UI suite passed 8/8, Android 70 unit + 2 instrumentation, ML 17 tests/Ruff/0 type errors, and gateway 5 tests/backend regression suites as above. An additional inference check confirms the response model version includes the exact checkpoint SHA, with `deployment_approved: false` and no cm. Full changed-file inventory since the audited base is [CARDLESS_CHANGED_FILES.txt](CARDLESS_CHANGED_FILES.txt). The main session inspected the actual exported iOS camera-review screenshot and Android skirt-confirmation screenshot; they preserve the established controls/readability and show explicit measurement review. Research AI consent UI has source/contract coverage but has not been exercised against a real authenticated staging account/device. This is an outstanding integration validation, not a production pass.

## 2026-10-28 hosted AR field integration

Astra/Gemini의 정규화 봉제점과 촬영 시점 AR 평면으로 계산하는 Debug 전용 화면·독립 인증 게이트웨이를 구현했다. 생산 플래그/모델 승인/Phase 3는 변경하지 않았다. [실행·개인정보·실제 시험·검증 기록](HOSTED_AR_FIELD_TEST.md)을 따른다. 공개 aRTF 1장/모델별 실제 요청 성공은 연결 검증이며 이 경로의 cm 정확도 검증이 아니다.

## 2026-10-29 공개 사진 추론 재검토

[확대 재검토 실험](ARTF_VISION_REFINEMENT.md)은 개발 8장과 추가 장소 사진 16장을 사용했다. Astra 9장/Gemini 13장의 전후 비교만 완료했으며 추가 유료 API는 예산 지시로 중단했다. Astra 일부 개선과 Gemini 악화를 모두 기록했다. 이 결과로 새 체크포인트나 운영 승인을 만들지 않았고 앱의 추가 호출도 활성화하지 않았다. 실제 봉제선/cm 정확도, 미확보 카테고리의 정답과 실기기 검증은 여전히 미완료다. AI Hub 외부 전송과 Phase 3 변경은 없다.

이후 사용자 요청에 따라 [시험 화면](HOSTED_AR_FIELD_TEST.md)에 초안 우선 흐름을 추가했다. 불확실한 좌표도 주황색 점/초안 cm로 표시하고, 사용자가 점을 확인하거나 옮길 수 있다. 누락/평면 밖/비현실적 치수는 계속 거절한다. 수정/확인에는 API를 호출하지 않으며 추론 성능 향상이나 cm 정확도 검증을 뜻하지 않는다. 시뮬레이터 단위 75개와 UI 4개 시나리오(라이트·다크)를 검증했다. 2026-10-29 goofy 재설치에 성공했고 자동 실행은 폰 잠금으로 거부됐다. 잠금 해제 후 새 빌드 화면 진입과 실제 cm 검증은 아직 미확인이다.
