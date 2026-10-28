# Public aRTF hosted vision API benchmark

The user's locally stored credential belongs to OpenRouter. Initial authentication against OpenAI returned HTTP 401; no photograph or inference request was sent to that endpoint. Authentication against OpenRouter returned HTTP 200. The existing ignored `ml/.env` variable `OPENAI_API_KEY` is accepted as a legacy local key name; `OPENROUTER_API_KEY` takes precedence when set. Neither value is printed, included in model prompts, or committed.

## Fixed scope and inputs

- Same original public aRTF 512×256 PNGs P01–P08 from the earlier visual-assistant pilot: four T-shirts and four shorts. Packet SHA `67e41b8192e00bfbf6dc08c1d26e65b285026117d7499d3e8bd01169a62d8e08`.
- Source photographs and publisher-test identity/license are audited before outbound requests; AI Hub and every private source are rejected. This test does not transmit any AI Hub pixels. Original filenames, normalized source bytes, crop/orientation and dimensions must match the frozen packet.
- Four unique targets per photo, matching the earlier pilot: shoulder_left/right and armpit_left/right for T-shirts; waist_left/right, crotch and side_hem for shorts. No duplicate side_waist point. Original source labels provide 30 visible targets across the eight images; all remain in the PCK denominator.
- Label-free prompt is frozen in `ml/protocols/artf-api-comparison-v1.md`. The source's whole-garment left/right convention, normalized top-left frame, uncertain proposals and null-coordinate abstention are explicit. No publisher coordinates, previous assistant responses, baseline model outputs or accuracy scores enter the API payload. The same category-specific instructions and original image bytes are used for every model.
- Explicit actual catalog IDs: `openai/gpt-5.4-mini`, `openai/gpt-5.4`, `openai/gpt-6-astra`, `google/gemini-3.8-flash`, `anthropic/claude-sonnet-4.6`. Catalog metadata/prices are captured before calls and pinned by hash. These IDs may be aliases; returned model/provider identities are retained rather than claiming an unavailable immutable model revision.

## Inference and accounting

One request per photo/model, 40 total scheduled attempts, in deterministic shuffled order (seed 20261028). Calls are serial, use persistent HTTP/2 connections, high image detail, low reasoning effort, maximum 4,096 completion tokens including reasoning, and a strict JSON output schema. Provider fallback is disabled; no alternate model or favorable sample is silently substituted. There are no inference retries. Transport retries apply only to connection establishment. Reasoning text is excluded from responses and the allowlisted persisted response schema.

OpenRouter routing uses `require_parameters: true`, `data_collection: deny` and `zdr: true`. An incompatible endpoint must fail rather than silently drop these controls. These controls are the provider's advertised policy, not an independent legal certification. Only authorized public aRTF photographs are in scope. See [provider routing](https://openrouter.ai/docs/guides/routing/provider-selection) and [structured output documentation](https://openrouter.ai/docs/guides/features/structured-outputs).

A conservative catalog-price reservation for 8,192 input tokens and 4,096 output tokens per call totals $4.0230912, below the configured $5 pilot limit. This is an experiment guard, not a guarantee of an account-level billing hard cap. **Actual comparison costs come from each response's `usage.cost`, not from this reservation or a guessed image-token estimate.** Missing cost remains unknown; it is not filled with zero. Token counts retain native provider accounting, and reasoning is already included in completion tokens. See [usage accounting](https://openrouter.ai/docs/cookbook/administration/usage-accounting).

The recorded elapsed time starts immediately before the HTTP POST and ends when its complete response body is received. It includes this Mac's network path, OpenRouter routing and model processing, while excluding local packet validation/base64 preparation, phone upload, AR scanning and mobile result rendering. Report mean, median, descriptive sample P95 and maximum over all eight attempts. This is not a mobile latency or production SLA benchmark; low effort does not imply equal compute across model families.

Each start receipt is written before outbound egress, and its sanitized result is saved immediately after completion, including failures. Request/response hashes, actual generation IDs, selected provider, usage, parsed JSON and elapsed seconds are retained. Authentication/funding/permission failures or uncertain transport billing stop the experiment. Existing outputs cannot be overwritten; an interrupted request must not be blindly resubmitted.

## Accuracy and limitations

All **40 actual inference requests completed**, with eight parseable JSON annotation responses per model. This denotes response-format success, not complete landmark coverage or successful cm measurement. Total observed charge was **$0.373349**. Every response cost matched its separate OpenRouter generation ledger entry; all 40 were non-BYOK. Ledger validation submitted zero new inference requests. Reports: `ml/reports/ARTF_OPENROUTER_MODEL_COMPARISON.json`, `ARTF_OPENROUTER_ATTEMPTS.json`, `ARTF_OPENROUTER_SELECTED_MODELS.json` and `ARTF_OPENROUTER_BILLING_AUDIT.json`.

| Model | PCK@0.05, all 30 visible GT | Native supplied-only NME | Supplied visible targets | Mean / median / sample P95 seconds | Mean actual USD / photo |
|---|---:|---:|---:|---:|---:|
| GPT-6 Astra | 86.67% (26/30) | 0.03011 | 30/30 | 13.838 / 12.825 / 22.018 | $0.02617125 |
| Gemini 3.8 Flash | 76.67% (23/30) | 0.04260 | 30/30 | 7.259 / 6.574 / 13.340 | $0.0034513125 |
| GPT-5.4 | 26.67% (8/30) | 0.10108 | 30/30 | 8.398 / 7.706 / 11.495 | $0.00842875 |
| GPT-5.4 Mini | 23.33% (7/30) | 0.11831 | 26/30 | 6.027 / 6.319 / 7.563 | $0.0023143125 |
| Claude Sonnet 4.6 | 16.67% (5/30) | 0.13748 | 26/30 | 8.864 / 4.796 / 20.145 | $0.006303 |

All mini/Claude abstentions remain PCK failures. Their penalty-inclusive NME values are respectively 0.23587 and 0.25248; do not present supplied-only NME without its coverage. Actual routing was Azure for the three OpenAI models, Google for Gemini, and Amazon Bedrock for Claude. The returned model IDs matched the requested catalog aliases. Exact underlying snapshots are not asserted.

Category split (15 visible points each): Astra T-shirt PCK 93.33%, shorts 80.00%; Gemini T-shirt 60.00%, shorts 93.33%. This suggests category-dependent behavior to investigate, **not** a validated routing policy or a 93% overall system. Selecting the better model per category after seeing these eight photos would be post-hoc tuning on development data. Mini/GPT-5.4/Claude results are observations for this exact prompt/settings, not a universal ranking of their vision capability.

| Relative projected-segment error, same supplied pairs across all five models | Shoulder (2 pairs) | Underarm (3 pairs) | Waistband (4 pairs) |
|---|---:|---:|---:|
| Astra | 5.06% | 9.42% | 8.93% |
| Gemini | 25.36% | 9.56% | 2.88% |
| GPT-5.4 | 66.99% | 44.18% | 15.69% |
| Mini | 20.26% | 19.53% | 22.73% |
| Claude | 43.35% | 18.70% | 53.56% |

These pair counts are very small. Full per-model eligible/supplied/failed-pair counts and native pixel errors remain in the JSON, so the secondary common subset cannot erase failures. The previous direct chat assistant's 83.33% PCK was a separate interactive pilot, not this API run or a latency/cost benchmark. No result is used to replace local weights or activate an app feature.

PCK@0.05 and NME use the same normalized square-input diagonal as earlier reports. All visible publisher GT points count regardless of predicted confidence. Abstentions, invalid JSON, refusals and failed calls remain missing predictions: PCK failures, coverage counts, conditional supplied-point NME and a separate explicit missing-point NME penalty of 1 are reported. That penalty is not standard coordinate NME or a statistical uncertainty interval.

Projected shoulder/underarm/waistband segment errors use the original image's width and height, with both per-model failure counts and a secondary comparison restricted to the same pairs supplied by every model. They are pixel distances and relative projected-length errors, **not centimeters**. No AI Hub seam accuracy, garment cm MAE/P95 or Phase 3 single-image scale inference is measured here.

The eight photographs have been reused during development; they are not a new independent garment/device study. Public-model pretraining exposure and physical garment/session independence remain unknown. Publisher anatomical annotations are not certified tailoring-seam truth. No test image or API response enters training, and no feature flag or app/server model deployment approval is changed. Existing local checkpoints are preserved.

## Reproduction

From `ml/` with the ignored `.env` saved locally:

```sh
uv sync --locked
uv run --env-file .env python -m coordit_ml.vision_api_cli run benchmark-artf-openrouter.json
uv run python -m coordit_ml.vision_api_cli score benchmark-artf-openrouter.json
uv run --env-file .env python -m coordit_ml.vision_api_cli billing benchmark-artf-openrouter.json --output reports/ARTF_OPENROUTER_BILLING_AUDIT.json
uv run pytest -q
uv run ruff check coordit_ml tests
uv run basedpyright
```

The paid `run` command refuses an existing output directory; use a separately reviewed new output for another experiment, not a blind rerun. The offline `score` command makes no API calls and requires the exact frozen model/photo grid and original request hashes. Use a new report path to replay without overwriting the original. Original PNGs, raw model catalog and per-attempt local files are under `ml/artifacts/artf-api-model-benchmark-v1/`; large data and credentials remain outside Git.

Verification: 100 ML tests passed in 3.85 s; Ruff passed. New benchmark runtime/test modules typecheck with zero errors/warnings; full basedpyright has zero errors and 28 existing Torch/ONNX warnings, so its warning exit is not advertised as a clean full typecheck. All seven changed Python files pass source-size/no-excuse checks and remain below 250 pure lines. The modules separately own API boundary types, licensed pixel/request preparation, paid execution receipts, offline metrics, read-only billing audit and CLI dispatch. No untyped escape, invented coordinate correction, hidden inference retry or centroid-filled abstention is introduced. Offline score replay is byte-for-byte identical. The prior local checkpoint remains unchanged. No iOS/Android build, app integration, AR sensor trial or deployment occurred in this benchmark.

aRTF Clothes — Thomas Lips, Victor-Louis De Gusseme and Francis wyffels, Ghent University, CC BY 4.0, [original deposit](https://zenodo.org/records/14501499). These API outputs are unverified proposals, not publisher endorsement or new source annotations. No hosted model weights are downloaded or redistributed. Model APIs remain subject to their service conditions, separately from the photograph license.
