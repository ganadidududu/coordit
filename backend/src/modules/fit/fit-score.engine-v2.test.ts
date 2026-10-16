import assert from "node:assert/strict";
import test from "node:test";
import {
  calculateFitScoreForSize,
  getFitLabel,
  recommendBestSizeWithReferences
} from "./fit-score.engine";
import type { ExternalProductSizeInput, FeedbackFitProfile, ReferenceClothingInput } from "./fit.types";

const upperReference = (measurements: ReferenceClothingInput["measurements"], fitType: ReferenceClothingInput["fitType"] = "regular"): ReferenceClothingInput => ({
  id: "reference",
  fitType,
  measurements
});

const size = (id: string, measurements: ExternalProductSizeInput["measurements"], fitType: ExternalProductSizeInput["fitType"] = "regular"): ExternalProductSizeInput => ({
  id,
  sizeLabel: id,
  fitType,
  measurements
});

test("jacket chest smaller and larger gaps use directional tolerance", () => {
  const reference = upperReference({ shoulder_width: 47, chest_width: 57, sleeve_length: 62, total_length: 68 });
  const smaller = calculateFitScoreForSize(reference, size("smaller", { shoulder_width: 47, chest_width: 54, sleeve_length: 62, total_length: 68 }), "jacket");
  const larger = calculateFitScoreForSize(reference, size("larger", { shoulder_width: 47, chest_width: 60, sleeve_length: 62, total_length: 68 }), "jacket");
  assert.ok(smaller.finalFitScore < larger.finalFitScore);
  assert.ok((smaller.measurementSubscores.chest_width ?? 100) < (larger.measurementSubscores.chest_width ?? 0));
});

test("oversized tshirt tolerates a larger shoulder more than regular", () => {
  const reference = upperReference({ shoulder_width: 50, chest_width: 58, total_length: 72, sleeve_length: 24 });
  const regular = calculateFitScoreForSize(reference, size("regular", { shoulder_width: 54, chest_width: 58, total_length: 72, sleeve_length: 24 }, "regular"), "tshirt");
  const oversized = calculateFitScoreForSize(reference, size("oversized", { shoulder_width: 54, chest_width: 58, total_length: 72, sleeve_length: 24 }, "oversized"), "tshirt");
  assert.ok(oversized.finalFitScore > regular.finalFitScore);
});

test("the same chest gap has category-specific weight and tolerance", () => {
  const reference = upperReference({ shoulder_width: 47, chest_width: 57, sleeve_length: 62, total_length: 68 });
  const candidate = size("candidate", { shoulder_width: 47, chest_width: 54, sleeve_length: 62, total_length: 68 });
  const tshirt = calculateFitScoreForSize(reference, candidate, "tshirt");
  const jacket = calculateFitScoreForSize(reference, candidate, "jacket");
  assert.notEqual(tshirt.finalFitScore, jacket.finalFitScore);
  assert.notEqual(tshirt.measurementSubscores.chest_width, jacket.measurementSubscores.chest_width);
});

test("slim fit penalizes excess chest room more than regular", () => {
  const reference = upperReference({ shoulder_width: 47, chest_width: 57, sleeve_length: 62, total_length: 68 });
  const measurements = { shoulder_width: 47, chest_width: 61, sleeve_length: 62, total_length: 68 };
  const regular = calculateFitScoreForSize(reference, size("regular", measurements, "regular"), "jacket");
  const slim = calculateFitScoreForSize(reference, size("slim", measurements, "slim"), "jacket");
  assert.ok(slim.finalFitScore < regular.finalFitScore);
});

test("lower-body imbalance is reported with a bounded interaction adjustment", () => {
  const reference = upperReference({ waist_width: 40, hip_width: 52, rise: 30, outseam: 100 });
  const result = calculateFitScoreForSize(reference, size("M", { waist_width: 36, hip_width: 54, rise: 30, outseam: 100 }), "pants");
  assert.ok(result.interactions.some((interaction) => interaction.id === "waist_hip_balance"));
  assert.ok(result.penalty > 0 && result.penalty <= 2);
  assert.ok(result.fitScore - result.finalFitScore <= 2.01);
});

test("interaction facts and deterministic size tradeoff are returned", () => {
  const reference = upperReference({ shoulder_width: 47, chest_width: 57, sleeve_length: 62, total_length: 68 });
  const recommendation = recommendBestSizeWithReferences(
    [reference],
    [
      size("M", { shoulder_width: 47.5, chest_width: 54, sleeve_length: 62, total_length: 68.5 }),
      size("L", { shoulder_width: 49, chest_width: 58, sleeve_length: 64, total_length: 71 })
    ],
    "jacket"
  );
  assert.ok(recommendation.allSizeScores.some((candidate) => candidate.interactions.length > 0));
  assert.equal(recommendation.recommended.sizeLabel, "M");
  assert.equal(recommendation.sizeTradeoff?.recommended, "M");
  assert.equal(recommendation.sizeTradeoff?.alternative, "L");
  assert.equal(recommendation.sizeTradeoff?.tradeoffs.find((item) => item.measurement === "chest_width")?.preferred, "alternative");
  assert.equal(recommendation.sizeTradeoff?.tradeoffs.find((item) => item.measurement === "total_length")?.preferred, "recommended");
  assert.ok((recommendation.sizeTradeoff?.tradeoffs.length ?? 0) > 0);
  assert.ok(recommendation.recommended.semanticFacts.some((fact) =>
    fact.measurement === "chest_width" && fact.semanticEffects.includes("layering_room_reduced")
  ));
});

test("score invariants hold with missing and extreme measurements", () => {
  const reference = upperReference({ shoulder_width: 47, chest_width: 57, sleeve_length: 62, total_length: 68 });
  const perfect = calculateFitScoreForSize(reference, size("perfect", reference.measurements), "jacket");
  const missing = calculateFitScoreForSize(reference, size("missing", { chest_width: 57 }), "jacket");
  const extreme = calculateFitScoreForSize(reference, size("extreme", { shoulder_width: 80, chest_width: 90, sleeve_length: 90, total_length: 110 }), "jacket");
  assert.equal(perfect.finalFitScore, 100);
  assert.equal(missing.finalFitScore, 100);
  assert.ok(Number.isFinite(extreme.finalFitScore));
  assert.ok(extreme.finalFitScore >= 0 && extreme.finalFitScore <= 100);
  assert.ok(extreme.finalFitScore < 10);
  const overflow = calculateFitScoreForSize(reference, size("overflow", { shoulder_width: 1e308, chest_width: 1e308, sleeve_length: 1e308, total_length: 1e308 }), "jacket");
  assert.ok(Number.isFinite(overflow.finalFitScore));
  assert.ok(Number.isFinite(overflow.weightedFitDistance));
  assert.deepEqual(
    calculateFitScoreForSize(reference, size("extreme", { shoulder_width: 80, chest_width: 90, sleeve_length: 90, total_length: 110 }), "jacket"),
    extreme
  );
});

test("skirt semantics never introduce rise facts", () => {
  const reference = upperReference({ waist_width: 35, hip_width: 48, total_length: 82 });
  const result = calculateFitScoreForSize(reference, size("M", { waist_width: 34, hip_width: 47, total_length: 80 }), "skirt");
  assert.equal(result.semanticFacts.some((fact) => fact.measurement === "rise"), false);
  assert.equal(Object.prototype.hasOwnProperty.call(result.measurementSubscores, "rise"), false);
});

test("skirt fit label ignores unsupported rise and outseam differences", () => {
  const label = getFitLabel(45, {
    waist_width: 3,
    hip_width: 3,
    total_length: 2,
    rise: -50,
    outseam: -50
  }, "skirt");
  assert.equal(label, "too_large");
});

test("only calibration-ready feedback applies bounded personalization", () => {
  const references = [upperReference({ waist_width: 40, hip_width: 52, rise: 30, outseam: 100 })];
  const sizes = [
    size("base", { waist_width: 40, hip_width: 52, rise: 30, outseam: 100 }),
    size("personalized", { waist_width: 41, hip_width: 53, rise: 30, outseam: 100 })
  ];
  const feedback: FeedbackFitProfile = {
    category: "pants",
    sampleCount: 6,
    overallSampleCount: 3,
    partSampleCount: 3,
    measurementOffsets: { waist_width: 1, hip_width: 1 },
    weightMultipliers: { waist_width: 1.1 },
    partFeedbackCounts: { waist_width: { too_small: 3 } },
    reliability: {
      applied: true,
      status: "applied",
      categoryUsableRows: 6,
      categoryMinUsableRows: 5,
      partMinUsableRows: 3,
      weightedSampleCount: 6,
      partUsableRows: { waist_width: 3 },
      corroboratedRows: 3
    },
    strategy: "feedback_offset_weight_v1"
  };

  const personalized = recommendBestSizeWithReferences(references, sizes, "pants", feedback);
  const base = recommendBestSizeWithReferences(references, sizes, "pants");
  assert.equal(base.recommended.sizeLabel, "base");
  assert.equal(personalized.recommended.sizeLabel, "personalized");
  assert.equal(personalized.weightingStrategy, "feedback_adjusted_profile_v1");
});
