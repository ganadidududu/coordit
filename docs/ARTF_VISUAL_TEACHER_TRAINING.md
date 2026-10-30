# aRTF visual-teacher continuation experiment

This Phase 2 experiment tests whether weak annotations from the current chat visual assistant improve the existing Coordit model. It is not a separately invoked or revision-pinned external API experiment. AI Hub photographs remain local. No Phase 3, application, backend, payment, deployment flag or production database changes are included.

## Frozen annotations and leakage protection

- Source: already-approved `artifacts/artf-landmarks-v1/records.jsonl`, SHA `156fac9f1c88d9136fd17dcc8c86e8cc412e6256c3f6bb24797f6424f06a2498`.
- Select 12 real T-shirts and 12 real shorts, sorted by SHA-256 of `20261029:<image SHA>`. Selection does not inspect difficulty, source coordinates or model errors. These are existing training photos, not 24 newly acquired photographs.
- Original 512×256 public PNGs T01–T24 were shown without labels or model overlays. No AI Hub pixels were viewed by the assistant or sent to external AI. The same assistant prepared annotations and ran scoring; this is a recorded label-free procedure, not independently monitored blinding. Prior public-model pretraining exposure is unknown.
- Frozen packet: `ml/reports/ARTF_TRAINING_TEACHER_PACKET.json`, SHA `2a46e007324f534db100bab1ce386c3346931a6ea8422ae3de2c6436de6dbd22`.
- Frozen proposals: `ml/reports/ARTF_TRAINING_TEACHER_PROPOSALS.json`, SHA `ca6d2e0cd7dd1036c9a859564c6aee6d2701ce4e0ef3dd76c4cf3fe8f808eb84`. Responses were frozen before inspecting per-photo publisher coordinates or eligibility outcomes. Exact provider revision is unavailable.
- The 561-photo development evaluation manifest is fixed at SHA `ae9806f8ad98e2ede7add42f7591ccb60b294de984ad632dcee75aea1d79fa00`. Its test-only source identity remains unregistered and rejected by normal training. The former eight-photo visual pilot is included only in evaluation, never teacher training.
- Preparation and training verify source grants, original train paths, image hashes/dimensions, source/garment groups, near duplicates and unchanged response/protocol/evaluation pins. Before scoring, every compared model's training manifests/history are checked against all evaluation photos. Physical garment/session independence across the publisher's captures is still unresolved.

## What enters learning

The frozen teacher response requests 156 points: eight targets per T-shirt and five per shorts photograph. It supplies 131 coordinates and abstains on 25. After filtering, **22 photos and 122 weak points** remain: 73 proposals for already-labeled targets and 49 new, unverified targets. Five conflicts with publisher coordinates and four publisher-occluded targets are excluded. New target counts are length_start 9, hem_center 11, sleeve_start 9, sleeve_end 9 and waist_center 11; sleeve_start aliases shoulder_right and is not another independent physical point. See `ml/reports/ARTF_TRAINING_TEACHER_ELIGIBILITY.json`.

Publisher points, masks and visibility labels remain byte-for-byte unchanged in the original manifests. Known occlusions cannot become visible targets. A teacher coordinate over 0.05 normalized-square diagonal from an existing visible publisher point is rejected. Filtering by agreement is not independent accuracy validation. New points have no equivalent publisher GT and must not be called verified seams.

Weak supervision is a separate coordinate/heatmap loss with global weight 0.25; uncertain proposals receive a further multiplier of 0.25. It creates no teacher visibility BCE, mask or cm target. The additional `length_start` means the left high-shoulder/neck junction; `sleeve_start/end` use the right shoulder and its cuff midpoint, following the existing procedural schema. These provisional semantics are not certified tailoring protocols. Inference support still depends on actual approved source labels; teacher-only points are not automatically exposed as supported production measurements. All model deployment approvals remain false.

AI Hub supplies local category/polygon-mask supervision only, with **zero verified seam points and no cm regression target**. Its native numerical measurement metadata is preserved but is not silently paired with guessed seam endpoints. The existing agreed local-use/territory restrictions still apply.

## Fixed training design

Both runs start from the preserved latest `seam-resolution-256-pairs-v1` checkpoint, SHA `f998fa346139cfc9876816fea1ed72ad234e9b8656e76868e7d330c6faa420fd`.

| Setting | Both runs |
|---|---|
| Architecture | Existing `coordit-spatial-multitask-v4-256-context`, 256 RGB |
| Device | Actual local Metal/MPS GPU |
| Epochs / batch / learning rate / seed | 12 / 4 / 0.0001 / 42 |
| Exposure budget | 512 per epoch, 6,144 per run; 1,536 optimizer steps |
| Exact source exposures per epoch | AI Hub 51, aRTF 435, GCD 26 |
| Total source exposures per run | AI Hub 612, aRTF 5,220, GCD 312 |
| Approved corpus pool | 2,482 AI Hub + 524 aRTF + 48 GCD = 3,054 images |
| Augmentation | Brightness 0.7–1.3 only, identical deterministic sampling |
| Existing projected-pair loss weight | 2; projected 2D geometry, not cm |
| Sole treatment difference | Optional pinned weak teacher objective |

The source quotas are a controlled research setting, not a proven optimal mix. Each completed run actually exposes **1,114 unique images: AI Hub 542, aRTF 524 (314 garments + 210 auxiliary towels), GCD 48 synthetic views**. Each has 6,144 total exposures, including 312 synthetic exposures. The teacher-bearing 22 photos appear 222 times in the candidate run; repeats are not new photos. The 24 teacher photos are a subset of the existing aRTF corpus and do not add 24 to corpus size. Source snapshots and pre-training fingerprints are preserved in each run's ignored `training-source/` directory; both pre-training/current/executed fingerprints match. Original checkpoints are not overwritten. Final epochs were fixed before evaluation; there is no test-driven checkpoint or parameter selection.

## Evaluation

Both final checkpoints completed all 12 epochs on Metal. Exact hashes, source pins, actual exposures and checks are in `ml/reports/ARTF_VISUAL_TEACHER_RUNS.json`; final metrics are in `ml/reports/ARTF_VISUAL_TEACHER_COMPARISON.json`, assembled from two hash-pinned scoring reports without altering scores. Primary PCK@0.05/NME use the four unique common targets per category, omitting the shorts `side_waist` alias. Legacy full-mapped metrics retain the alias and are separately labeled so they can be compared to earlier reports. Every visible GT point is counted regardless of predicted confidence.

| Metric, fixed 561 photos / 2,200 unique visible GT targets | Preserved parent | Equal-budget control | Visual-teacher candidate |
|---|---:|---:|---:|
| Overall PCK@0.05 | 23.14% | 22.55% | 22.86% |
| Overall NME, lower is better | 0.13851 | 0.14370 | 0.14327 |
| T-shirt PCK, 389 photos / 1,536 targets | 22.20% | 21.68% | 22.01% |
| T-shirt NME | 0.14051 | 0.14649 | 0.14583 |
| Shorts PCK, 172 photos / 664 unique targets | 25.30% | 24.55% | 24.85% |
| Shorts NME | 0.13388 | 0.13724 | 0.13736 |
| Macro mask IoU, two present categories | 0.66354 | 0.62084 | 0.61856 |

The shorts legacy alias-inclusive PCK values are 24.52%, 23.92%, 24.28% respectively. This denominator explains the difference from the unique-target row; no ground truth was changed. The teacher candidate gains only 0.32 percentage points over the equal-budget control and trails the original parent by 0.27 points overall. This single-seed experiment does not establish a statistically reliable teacher benefit. **No model is promoted; the existing parent is preserved.** The experiment does not establish that a deployable landmark model is impossible, only that this small weak-label continuation did not improve this existing model.

| Mean projected segment relative error | Parent | Control | Teacher |
|---|---:|---:|---:|
| Shoulder, same 382 eligible pairs | 37.17% | 37.69% | 36.75% |
| Underarm, same 376 eligible pairs | 33.01% | 36.24% | 35.58% |
| Waistband, same 163 eligible pairs | 29.40% | 30.77% | 30.40% |

The previous eight-photo subset has PCK 13.33% / 6.67% / 3.33% (parent/control/candidate), with NME 0.13689 / 0.14500 / 0.14544. The assistant's earlier **direct** predictions on these eight photos scored 83.33% with abstentions counted as failures; those direct assistant results are not the small CNN's performance and were not used as training targets. Good direct proposals on eight photos did not transfer into a comparably accurate small model in this 24-photo experiment. No root cause or optimal next architecture is proven by this comparison.

Projected length errors are calculated in original 512×256 pixel geometry for shoulder width, underarm width and shorts waistband width, with common eligible pairs across models. They are **not centimeter errors**. New teacher-only endpoints cannot receive a PCK/NME claim until independent truth exists. mIoU evaluates source masks independently of landmark error. AI Hub seam accuracy and actual AR cm MAE/P95 remain unverified.

The 561-photo pool has been reused in development and is photo-unseen by recorded training, not a new independent garment/device study. No gain in this pool alone establishes production accuracy or the 1 cm / 2 cm release targets. The old eight-photo subset is secondary and too small for model promotion.

## Commands and local paths

Run from the repository's `ml/` directory with the locked environment:

```sh
uv sync --locked
uv run python -m coordit_ml.teacher_cli prepare artf-training-teacher.json
# Preparation refuses an existing output. Recover existing frozen files rather than overwrite them.
# Interactive vision produces proposals; no provider API, API key or private-photo upload is hidden in this command.
uv run python -m coordit_ml train config-seam-teacher-control.json
uv run python -m coordit_ml train config-seam-visual-teacher.json
uv run python -m coordit_ml.teacher_cli evaluate evaluate-artf-teacher-control.json
uv run python -m coordit_ml.teacher_cli evaluate evaluate-artf-visual-teacher.json
uv run pytest -q
uv run ruff check coordit_ml tests
uv run basedpyright
```

Actual local outputs: `ml/artifacts/artf-training-teacher-v1/`, `ml/artifacts/seam-teacher-control-v1/` and `ml/artifacts/seam-artf-visual-teacher-v1/`. Candidate checkpoint SHA `5038e2660a02334e49344eaae401404c2b4750e223d90d28a7c9d9872f6bd087`; control SHA `61576f4c77c4af3c57e842c4e0d6529cc58d3eb2fe0da87940d8b8ce6786c006`. To reproduce training, use a new output directory or the recorded source snapshot with compatible resume configuration. Existing output guards intentionally prevent silently overwriting checkpoints or reports. The proposal file and packet are committed without pixels; large weights and private data stay outside Git.

Verification: 95 ML tests passed in 4.41 s; Ruff passed. Full basedpyright reports zero errors and 28 Torch/ONNX typing warnings (one new autograd warning in the gradient test); its warning exit is not labeled a clean full typecheck. New runtime modules typecheck with zero errors/warnings. Source-size/no-excuse checks passed. `training.py` is 247 nonblank/noncomment lines, in the warning band; extract its config/fingerprint responsibility before adding more logic. Each new teacher module owns a separate packet boundary, weak objective, evaluation or CLI dispatch; typed Pydantic boundaries retain proposal status and source pins without untyped escapes. Existing parent and AI Hub checkpoints were rehashed unchanged. No mobile build, device/sensor test, Core ML/ONNX conversion or deployment was performed for this experiment.

## Rights and category coverage

aRTF Clothes: Thomas Lips, Victor-Louis De Gusseme and Francis wyffels, Ghent University, [original Zenodo deposit](https://zenodo.org/records/14501499), CC BY 4.0. Additional assistant proposals are Coordit modifications, not publisher endorsement or a new rights certification. Existing GarmentCodeData v2 attribution and geometry-only scope continue to apply. AI Hub attribution and local-use limits are unchanged; no new model is approved for app/server deployment.

aRTF directly supports this pilot's T-shirts and shorts. AI Hub contributes coats and jackets for masks/categories, not seam GT. Existing body-free GCD renders contribute shirts, pants and skirts. The existing Second-Hand Fashion pool contains all 11 categories but currently provides category labels only; it is not used as invented seam truth in this controlled comparison. Other garment categories still require rights-cleared real seam annotation and category-specific untouched evaluation, rather than inferring that T-shirt/shorts results cover all 11 categories.
