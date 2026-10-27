# Coordit garment research (disabled for production)

This is executable research infrastructure, not a released 11-category measurement model. New app flags and server deployment approval remain false. Real centimeter accuracy has **not** been measured. Production backend, wallet, SQL/RLS and report routes are unchanged.

## Reproduce

Run commands from `ml/`. Python 3.12 and uv 0.10.9 were used; `uv.lock` pins dependencies.

```sh
uv sync --locked
uv run python -m coordit_ml registry
uv run python -m coordit_ml download-artf artifacts/download-20261027
uv run python -m coordit_ml convert-artf artifacts/download-20261027/aRTFClothes-resized-paper-splits.zip artifacts/artf-v1.1
uv run python -m coordit_ml synthetic artifacts/synthetic-v1.1 --per-category 30
uv run python -m coordit_ml validate artifacts/artf-v1.1/records.jsonl
uv run python -m coordit_ml validate artifacts/synthetic-v1.1/records.jsonl
uv run python -m coordit_ml train config-smoke.json
# Apple Metal GPU (actually run, 20 epochs each):
uv run python -m coordit_ml train config-mps-shared.json
uv run python -m coordit_ml train config-mps-category.json
# CUDA GPU command provided; CUDA was unavailable on this host:
uv run python -m coordit_ml train config-gpu.json
uv run python -m coordit_ml evaluate artifacts/tiny-shared-mps-final-data artifacts/synthetic-v1.1/records.jsonl --split validation
uv run pytest
uv run ruff check coordit_ml tests
uv run basedpyright
```

Commands refuse to overwrite corpora/checkpoints. On this workspace the outputs already exist: choose a new output directory in a copied config, or set `resume: true` and a larger absolute epoch count. Resume requires identical data, registry, network/training source, seed and hyperparameters. Checkpoints are saved atomically at epoch boundaries (not mid-batch). JSONL training logs and `artifact.json` retain hashes, actual seen image IDs/counts and category exposure. Keep model files and datasets outside regular Git; `artifacts/` is ignored.

## Rights, normalization and leakage

- Dataset approval authority: `registry/DATASET_MANIFEST.json`. `approve-dataset review.json` requires a complete typed `Approval` record, reviewer, original HTTPS rights evidence and the exact registry SHA. It cannot auto-approve NC/unknown rights or silently override a blocked record. Approval does not constitute legal advice.
- The loader **always** audits every source, original image rights, hash, file dimensions, mask, category, COCO polygon/bbox, semantic schema, exact duplicates and cross-corpus group/near-duplicate leakage before tensor construction. Unknown/pending/blocked data fails training and CI. `reports/SOURCE_FILES.jsonl` inventories accepted files without distributing pixels.
- aRTF original source keypoints retain the `artf:` namespace. They are **not** supervised as Coordit shoulder seams. Real images train classification/segmentation; only authored synthetic semantics supervise the current landmark head.
- All 980 publisher test images in this resized archive are excluded, including the existing 16-image development evaluation set and associated garments/scenes. Publisher train/validation pools are combined into **training only** because per-garment identities are unavailable. No real holdout accuracy is claimed.
- COCO boxes are normalized to cover their polygons; original boxes are retained as `source_bbox`. No original masks or images are changed by that normalization. The resized archive contains 104 training-pool shorts, versus 112 in the full dataset's publication table; missing files are not fabricated.
- Procedural assets use only project-authored polygons, camera math, colors and lines. Masks, visibility, 2D/3D landmarks, camera matrices and synthetic cm are emitted. Occlusion and wrinkle **shading** are simulated. There is no Blender cloth simulation, physical wrinkle displacement, third-party mesh or texture asset. This limits realism and classification coverage; it is not evidence of real garment performance.

## Training and evaluation

`GarmentNet` is randomly initialized: category classifier, mask branch, shared or per-category landmark branch, visibility branch. There are 13 internal classes (11 product categories plus auxiliary towel/boxers). Resizing is upright RGB 64x64 with normalized top-left landmarks. Auxiliary classes are not converted to ordinary garments. No pretrained weights are downloaded.

`synthetic_fraction` controls each epoch's mixed-domain sampling without duplicating images. Both Metal runs actually used all 799 unique training images (524 real + 275 synthetic), 20 epochs × 550 exposures/epoch. Synthetic validation/test remain separate. The current measured scores are poor; neither head is adopted for deployment. See `reports/` for exact metrics. All 11 categories' **real seam and centimeter accuracy remain unverified**; nine categories have zero accepted real training photos.

Metrics include per-category classification accuracy, macro-F1, mask IoU/mIoU, landmark PCK@0.05 of image diagonal, NME using the same normalization, omission rate, background/occlusion/wrinkle groupings, inference time and parameter bytes. Parameter storage is not peak process memory. Evaluating with `--split train` is explicitly training-set diagnostics, never an independent accuracy claim.

`evaluate-cm tape.csv` expects columns:
`garment_id,category,method,dimension,ground_truth_cm,predicted_cm,independent,synthetic`.
Blank predictions count as failed/recapture attempts. Synthetic/nonindependent rows are rejected. Each reported category/method/dimension needs >=20 independent real garments, MAE <=1cm and P95 <=2cm for the accuracy target. This is a necessary accuracy gate, not automatic legal/production authorization; omitted categories, success-rate requirements and calibrated error analyses must also be reviewed. No such real dataset was available here.

## Isolated inference

```sh
# Closed by default: /health works, /v1/landmarks returns 503.
uv run python -m uvicorn coordit_ml.service:app --host 127.0.0.1 --port 8001
# For local research only: set COORDIT_ML_DEVELOPMENT=true,
# COORDIT_ML_MODEL_DIRECTORY=<absolute local artifact directory>, and a fresh
# COORDIT_ML_API_TOKEN of at least 32 random characters via your secret manager.
uv run python -m coordit_ml infer artifacts/tiny-shared-mps-final-data artifacts/synthetic-v1.1/images/<image-id>.png
```

`POST /v1/landmarks`: bearer authentication, explicit `processing_consent`, bounded base64 image, upright coordinates, model version, uncalibrated confidence, actual predicted mask PNG, landmarks, and **empty cm values**. Training consent is refused: this service retains no images and collects no training data. Inference is serialized to protect resource usage. The service is independent of Express and cannot debit credits. It has not been deployed. The development switch cannot assert production model approval.

Mobile adapters reject unapproved models, bad/missing/duplicate/occluded points, mismatched category/coordinates, HTTP, missing consent, timeouts and outages. iOS uses the existing Vision contour detector on fallback. Android keeps its manual captured-plane points. No remote endpoint, shared API key, photo upload consent screen or production identity gateway is configured. Those are release blockers; never embed the development service token in an app.

## Export

```sh
uv sync --group export
uv run python -m coordit_ml export-onnx artifacts/tiny-shared-mps-final-data artifacts/tiny-shared-mps-final-data/model.onnx
```

A CPU smoke ONNX export and `onnx.checker` were actually run successfully. Core ML conversion and ONNX Runtime device inference have not been performed. An export is still an unapproved development artifact and inherits source-data attribution. No weights are in the app bundle or deployed server list.
