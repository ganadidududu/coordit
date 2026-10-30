# Product first-report rules

`narrative-rules.v1.json` is the canonical, versioned knowledge and wording used by both native apps. `backend/scripts/generate-narrative-rules.ts` emits typed Swift/Kotlin constants and identical native test resources. It is a development-time generator; it adds no backend endpoint, AI request, model download or runtime network dependency. Draft edits recompute the analysis on-device.

This is a curated rule system, not a trained or statistically calibrated model. There is no labeled fit dataset, accuracy claim, confidence probability or collection of user data for training. Any later empirical calibration needs a separately reviewed, appropriately licensed dataset with garment category, measurement definitions, composition and labeled cut/fit, plus held-out validation.

## Knowledge basis

- [Coats, Know About Textile Fibres](https://www.coats.com/en-us/info-hub/know-about-textile-fibres/): cotton/linen/rayon absorbency, linen creasing, nylon abrasion resistance, polyester low moisture absorption and elastane recovery. Wording here is a short original paraphrase of fiber properties, not a copy of supplier descriptions.
- [Woolmark, Wool is naturally breathable](https://www.woolmark.com/industry/research/factsheets/wool-is-naturally-breathable/): fiber crimp and insulation.

Finished fabric behavior also depends on yarn, knit/weave, density and finishing. The report labels these as tendencies, does not infer exact stretch, warmth, breathability, thickness, season or washing instructions, and preserves original seller information in the always-visible seller evidence. Seller stretch facts take priority over a blend-based stretch tendency. Ambiguous polyurethane/PU is not automatically labeled elastane: it can be a coating.

## Decisions and limits

- Parse named fibers and percentages in either order; normalize aliases, full-width text and decimal percentages. Unsupported fibers, duplicate aliases, totals outside98–102%, approximation/ranges, negative ratios and mixed outer/lining/filling scopes produce no composition inference.
- Only fibers at least20% contribute up to two general traits; equal traits are grouped to avoid repetition. Explicit elastane at least1% may support a conditional recovery observation, never a degree of finished-fabric stretch. Implausible elastane above25% is omitted conservatively.
- Boxy is a garment proportion observation, not body-relative ease or a personal recommendation. For supported non-knit tops, every size row must contain plausible chest flat width30–90cm and total length40–100cm, and at least two rows must exist. The chest-width/length ratio must meet the category threshold on every row. Thresholds (shirt .80, t-shirt .82, sweatshirt/hoodie .90) are transparent initial product heuristics, not a validated industry fit standard.
- Crossing that threshold between size rows yields a mixed-proportion observation. Missing dimensions, unsupported categories and a single size do not receive an inferred boxy cut. Absolute chest width alone never produces a loose/oversized fit label. Seller-provided loose/oversized fit remains attributed to the seller.
- A positive slim/tight seller label conflicting with boxy proportions triggers a check-design observation. Negated labels such as “슬림핏 아님” are not treated as positive slim labels.
- Source facts must still match the draft's product name, URL and input source. A title/URL/source edit drops the old material/fit analysis; a measurement edit immediately recomputes the table interpretation.

## Regeneration and verification

From `backend/`:

```sh
npx tsx scripts/generate-narrative-rules.ts
npx tsx scripts/generate-narrative-rules.ts --check
npx tsc --noEmit --strict --esModuleInterop --skipLibCheck --module CommonJS --target ES2022 scripts/generate-narrative-rules.ts
```

The29 independent vectors in `narrative-cases.v1.json` run through both real native engines. Tests assert parsed fiber IDs, selected trait IDs, silhouette classification and conflict decisions. Each platform exports its actual rendered paragraphs; the QA comparison requires identical paragraph output for all cases without pinning prose to a snapshot. This lets shared wording evolve while detecting a divergent implementation.
