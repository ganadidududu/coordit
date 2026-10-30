# Coordit garment perception (Phase 2, production disabled)

Actual code, data conversion, training and inference are implemented. This is a research system; real garment centimeter accuracy has not been established. See [the phase checkpoint](../docs/CARDLESS_PHASE_2_STATUS.md) for exact counts, results, constraints and device requirements. Phase 3 is deferred.

For the standalone iPhone field-test app, tape protocol, exact synthetic PCK/NME and local JSON evaluation, see [AR_FIELD_TEST_GUIDE](../docs/AR_FIELD_TEST_GUIDE.md). `uv run python -m coordit_ml field-report <export.json-or-directory> <new-output-directory>` separates automatic and corrected cm metrics, preserves failures, rejects simulator/non-independent/duplicate trials and never approves deployment.

[AI Hub 71501 and AR feedback](../docs/AIHUB_71501_AND_AR_FEEDBACK.md) records the explicitly accepted local-training agreement, actual downloads and camera fixes. Two real source/label archive pairs yielded **2,482 approved unworn coat/jacket images**, actually used for 5 Metal GPU epochs of mask/classification pretraining. Native numeric cm is preserved; **real seam and cm regression supervision remain zero**, and independent accuracy/deployment remain unapproved. `audit-aihub <private-source> <fresh-output>` inventories pairs without granting rights; `convert-aihub aihub-conversion.json` requires the pinned reviewed grant. Source photos/labels and private per-file measurements stay out of Git.

## Locked environment and data

Run from `ml/` with Python 3.12 and uv (tested with 0.10.9):

```sh
uv sync --locked
uv run python -m coordit_ml registry
uv run python -m coordit_ml download-artf artifacts/download-20261027
uv run python -m coordit_ml convert-artf artifacts/download-20261027/aRTFClothes-resized-paper-splits.zip artifacts/artf-v1.1
uv run python -m coordit_ml synthetic artifacts/synthetic-v2 --version v2 --per-category 120 --seed 257
uv run python -m coordit_ml validate artifacts/artf-v1.1/records.jsonl
uv run python -m coordit_ml validate artifacts/synthetic-v2/records.jsonl
uv run python -m coordit_ml audit-inventory reports/SOURCE_FILES.jsonl
```

These refuse to overwrite existing outputs. Data/weights live under ignored `artifacts/`, never regular Git. A fresh checkout can download the public archive without an account; inaccessible sources remain pending, not fabricated. The earlier approved real set contained 524 images: 210 T-shirts, 104 shorts, 210 auxiliary towels. All 980 publisher test-family images, including the old 16-image development fixtures, are excluded. Real source garment IDs are unavailable, so none of these real images is represented as independent validation/test. Original `artf:` keypoints are retained without pretending they label Coordit seams.

The v2 generator produces 1,320 new project-authored identities across 11 categories, with masks, semantic 2D/3D points, camera matrices, visibility, synthetic cm and construction details. It uses no third-party asset. These are flat procedural scenes with wrinkle shading, not physically simulated cloth. Train/validation/test split is 1,108/110/102. Their high scores do not validate real photographs.

`registry/DATASET_MANIFEST.json` is the approval authority. Image copyright, annotation license, source/terms evidence, scope and attribution are separate fields. `approve-dataset review.json` requires a complete typed review, reviewer, original evidence URLs and the exact registry hash. Pending, blocked, unknown or NC sources fail before training. Each loader audits actual SHA-256, perceptual hashes, image/mask geometry, semantic schemas and cross-corpus group/near-duplicate leakage. CI audits the tracked per-file source inventory and optionally a full curated corpus. Model loading checks the checkpoint hash, pinned manifests, current registry hash and current source approval; revocation fails closed.

## Additional original-author real photographs

[2026-10-27 acquisition and accuracy update](../docs/CARDLESS_ACCURACY_AND_REAL_DATA.md) records 14,101 additional training-only photos, the rights chain and exact class counts. These have **classification labels only**, no mask/seam/cm truth. Coat (9) and sweatshirt (4) labels are explicitly weak visual curation. The loader excludes their absent supervision from mask/landmark losses and their absent annotations from corresponding evaluation denominators. Publisher test (3,390) is excluded. Do not turn a photograph's image extent into garment-mask/bbox truth.

```sh
uv run python -m coordit_ml download-secondhand artifacts/secondhand-v3-source
uv run python -m coordit_ml convert-secondhand config-secondhand-conversion.json
uv run python -m coordit_ml validate artifacts/secondhand-v3-training/records.jsonl
uv run python -m coordit_ml audit-inventory reports/SOURCE_FILES.jsonl
# Actually executed: 2 CPU steps / 8 real photo exposures, operational check only.
uv run python -m coordit_ml train config-secondhand-smoke.json
```

The public source is pinned to the original author's revision and 14 reviewed LFS SHA-256 values; resume checks exact ranges, byte counts and checksums. Conversion refuses an unreviewed mirror, normalizes upright metadata-free pixels, preserves original photo SHA and expert/weak-label provenance, and rejects exact duplicates. Since conservative source-day/near-duplicate grouping connects this pool, it is explicitly training-only; no real holdout metric is reported. The optional `balance_real_categories` sampler balances exposures, not unique garments. Its default is false.

The dataset registry changed after the earlier MPS experiments. Their checkpoints remain historical artifacts and **fail the current registry identity check** until reviewed/retrained. Do not bypass this gate or overwrite their metadata. The new CPU smoke has current registry pins but is not a useful landmark checkpoint. No new full model training or real-photo accuracy claim is made.

## Training, resume and evaluation

```sh
# These two actual Metal runs completed 35 epochs each:
uv run python -m coordit_ml train config-spatial-v2-shared.json
uv run python -m coordit_ml train config-spatial-v2-category.json
uv run python -m coordit_ml evaluate artifacts/spatial-v2-shared artifacts/synthetic-v2/records.jsonl --split validation
uv run python -m coordit_ml evaluate artifacts/spatial-v2-category artifacts/synthetic-v2/records.jsonl --split validation
uv run python -m coordit_ml evaluate artifacts/spatial-v2-shared artifacts/synthetic-v2/records.jsonl --split test
# CPU smoke uses v1 for a cheap operational check:
uv run python -m coordit_ml train config-smoke.json
# CUDA alternative: copy a v2 config, change device to cuda and output to a fresh directory.
uv run python -m coordit_ml train config-gpu.json
uv run pytest
uv run ruff check coordit_ml tests
uv run basedpyright
```

To run again, copy a config and select a new output directory; do not overwrite evidence. To resume, set `resume: true` and a larger absolute epoch count. Registry/data/architecture/training source/seed/batch/lr/sampling fingerprints must match; legitimate code or registry changes require a new run. Atomic checkpoints include model, AdamW and RNG state at epoch boundaries. Logs record actual seen IDs, category exposures and source mix. A CPU smoke is not a complete training run; a missing GPU or empty corpus fails honestly.

The project-owned randomly initialized spatial v2 model has a convolutional encoder, spatial category head, skip mask decoder, Gaussian landmark heatmaps, visibility and optional category heads. Input is upright RGB 128×128; output points are top-left normalized, with 64×64 heatmaps. BCE/Dice balances segmentation; visibility/coordinate losses use only known visible semantic labels. Real aRTF data supervises classification and segmentation, not fabricated seam points. The older 64×64 v1 remains a versioned comparison.

Both v2 runs saw 1,632 distinct train images across 35 epochs, 55,370 sample exposures each. Shared heads won synthetic validation (macro-F1 .8891, mIoU .9709), versus per-category .8237/.9630. The selected shared candidate's held-out **synthetic** test is .8920/.9767. Full per-category PCK/NME/missing/condition/latency/parameter metrics are tracked in `reports/`. Real holdout and centimeter performance remain unverified for every category. Do not use synthetic cm as real accuracy evidence.

`evaluate-cm measurements.csv` requires columns `garment_id,category,method,dimension,ground_truth_cm,predicted_cm,independent,synthetic`. An empty prediction records failure. It emits all 43 category/part groups for each supplied card/lidar/arPlane method; missing groups fail. Each needs 20 successful independent real garments, MAE ≤1 cm, P95 ≤2 cm, and the conservative project policy of ≥95% success. Skirt rise/outseam, non-independent or synthetic rows are refused. There is no passing real cm report yet.

## Independent service and authenticated mobile integration

```sh
# Set these in the research host's protected environment, never an app or Git:
# COORDIT_ML_DEVELOPMENT=true
# COORDIT_ML_API_TOKEN=<random-secret-at-least-32-characters>
# COORDIT_ML_MODEL_DIRECTORY=<absolute-path-to-ignored-model-directory>
uv run python -m uvicorn coordit_ml.service:app --host 127.0.0.1 --port 8100
uv run python -m coordit_ml infer artifacts/spatial-v2-shared <upright-photo-path>
```

The default service returns 503 until explicitly configured; health does not claim approval. POST `/v1/landmarks` uses a private bearer token, `image_base64`, `processing_consent: true`, `training_consent: false`. It never returns cm, saves photos or collects training examples. Mask/landmark geometry and raw visibility scores can reject proposals. `status: needs_calibration` still requires a known AR/card scale; `failed` means use manual/local detection. Confidence is uncalibrated, not an error bound.

The existing Express backend mounts `/garment-landmarks` with the existing user authentication before its scoped image parser. Protected server variables are `COORDIT_LANDMARKS_RESEARCH_ENABLED=true`, `COORDIT_ML_URL=https://<private-service>/v1/landmarks`, and the same private service token. Only local upstream loopback may use HTTP. The gateway is hard-blocked in `NODE_ENV=production`, bounds concurrency, payload, response, timeout and redirect handling, returns no-store, and never forwards a user's bearer token upstream. No wallet/report/SQL operation is part of inference.

Mobile AI buttons are hidden by default. Deliberate research builds need both the AI flag and the **separate DEBUG-only development-proposal opt-in** (`CoorditAILandmarksEnabled` / `CoorditAILandmarksDevelopmentEnabled`, Android `AI_LANDMARKS_ENABLED` / `AI_LANDMARKS_DEVELOPMENT_ENABLED`) plus a reachable HTTPS Coordit backend and a user session. The photo-specific consent dialog explains purpose, temporary independent-server processing, metadata removal, no retention and no training. Each upload is re-encoded upright JPEG; no EXIF location is sent. Replies must match the selected category, semantic endpoints and coordinate contract; valid frozen AR/card geometry is applied only after user review. Failure keeps the old measurements/manual path. Release builds cannot accept development weights. No flag is enabled by these instructions or this commit.

## Export and release

```sh
uv sync --group export
uv run python -m coordit_ml export-onnx artifacts/spatial-v2-shared artifacts/spatial-v2-shared/model.onnx
uv run python -c 'import onnx; onnx.checker.check_model("artifacts/spatial-v2-shared/model.onnx")'
```

V2 export and checker actually passed. Core ML conversion and ONNX Runtime device execution remain untested. All checkpoints and ONNX inherit data attribution and remain unapproved research artifacts; `registry/MODEL_ARTIFACTS.json` has empty app/server deployment lists. No external pretrained weight is bundled.

Production requires original rights/terms clearance, lawful real seam labels across all categories, independent real evaluation, device/sensor reliability and the cm gate. Keep flags off until evidence exists. See `../DATASET_LICENSES.md`, `../MODEL_LICENSES.md`, `../THIRD_PARTY_NOTICES.md` and the checkpoint document.

## Real anatomical labels and topology-based seam fine tuning

See `../docs/SEAM_TRAINING_INTEGRATION.md` for actual counts, limitations, checkpoint hashes and results. The historical 35-epoch results above used aRTF for masks only. The new immutable `artf-landmarks-v1` corpus maps only reviewed publisher points; 314 real photos have partial anatomical supervision. GarmentCodeData contributes 48 synthetic views from six official-training designs, with source UV panel junctions, camera parameters and ray-tested visibility. Neither source supplies independent tape-measured cm accuracy.

```sh
# Run from ml. Large images/weights stay in ignored artifacts/.
uv run python -m coordit_ml prepare-artf-landmarks artifacts/artf-v1.1/records.jsonl artifacts/artf-landmarks-v1
uv run python -m coordit_ml download-garmentcode-sample artifacts/garmentcodedata-v2
uv run python -m coordit_ml render-garmentcode garmentcode-pilot.json
uv run python -m coordit_ml train config-seam-pilot.json
uv run python -m coordit_ml train config-seam-finetune.json
uv run python -m coordit_ml compare-seams compare-seam-finetune.json
uv run python -m coordit_ml import-seam-reviews <local-review-config.json>
```

Use fresh output directories for reproduction; existing source/model files are never overwritten. Model and comparison configs pin their exact parent checkpoint/metadata hashes. Fine tuning uses fresh optimizer state; resuming the same fine-tune run restores its own optimizer/RNG/epoch. Source sampling is explicit and logs repeated exposures separately from unique photos. Current ratios are development choices, not independently optimized estimates. AI Hub pending/model-generated seam suggestions are ineligible; verified review import additionally requires source hash, semantic rights scope, reviewer, protocol and pixel evidence. No AI Hub photo was sent to external AI for annotation. Phase 3 and mobile feature flags are unchanged.
