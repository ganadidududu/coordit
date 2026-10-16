import assert from "node:assert/strict";
import test from "node:test";
import {
  calculateFitScoreForSize,
  recommendBestSizeWithReferences
} from "./fit-score.engine";
import type {
  Category,
  ExternalProductSizeInput,
  FitType,
  MeasurementMap,
  ReferenceClothingInput
} from "./fit.types";

const reference = (
  measurements: MeasurementMap,
  fitType: FitType = "regular"
): ReferenceClothingInput => ({
  id: "owned-reference",
  fitType,
  measurements
});

const candidate = (
  sizeLabel: string,
  measurements: MeasurementMap,
  fitType: FitType = "regular"
): ExternalProductSizeInput => ({
  id: `candidate-${sizeLabel}`,
  sizeLabel,
  fitType,
  measurements
});

const score = (
  category: Category,
  owned: ReferenceClothingInput,
  product: ExternalProductSizeInput
) => calculateFitScoreForSize(owned, product, category);

test("jacket M versus L exposes a deterministic two-sided size tradeoff", () => {
  const owned = reference({
    shoulder_width: 47,
    chest_width: 57,
    sleeve_length: 62,
    total_length: 68
  });
  const sizes = [
    candidate("M", { shoulder_width: 47.5, chest_width: 54, sleeve_length: 62, total_length: 68.5 }),
    candidate("L", { shoulder_width: 49, chest_width: 58, sleeve_length: 64, total_length: 71 })
  ];

  const first = recommendBestSizeWithReferences([owned], sizes, "jacket");
  const second = recommendBestSizeWithReferences([owned], sizes, "jacket");

  assert.deepEqual(second, first);
  assert.equal(first.recommended.sizeLabel, "M");
  assert.equal(first.sizeTradeoff?.alternative, "L");
  assert.equal(
    first.sizeTradeoff?.tradeoffs.find(({ measurement }) => measurement === "chest_width")?.preferred,
    "alternative"
  );
  assert.equal(
    first.sizeTradeoff?.tradeoffs.find(({ measurement }) => measurement === "total_length")?.preferred,
    "recommended"
  );
});

test("oversized tshirt intent increases tolerance without inventing material facts", () => {
  const owned = reference({
    shoulder_width: 50,
    chest_width: 58,
    total_length: 72,
    sleeve_length: 24
  });
  const measurements = { shoulder_width: 54, chest_width: 60, total_length: 73, sleeve_length: 25 };

  const regular = score("tshirt", owned, candidate("regular", measurements));
  const oversized = score("tshirt", owned, candidate("oversized", measurements, "oversized"));

  assert.ok(oversized.finalFitScore > regular.finalFitScore);
  assert.ok(oversized.semanticFacts.some(({ semanticEffects }) =>
    semanticEffects.includes("shoulder_drop_increased")
  ));
  assert.equal(JSON.stringify(oversized).includes("stretch"), false);
  assert.equal(JSON.stringify(oversized).includes("material"), false);
});

test("shirt shoulder and chest imbalance is reported as a mixed interaction", () => {
  const result = score(
    "shirt",
    reference({ shoulder_width: 47, chest_width: 57, sleeve_length: 62, total_length: 70 }),
    candidate("M", { shoulder_width: 44, chest_width: 61, sleeve_length: 62, total_length: 70 })
  );
  const interaction = result.interactions.find(({ id }) => id === "upper_body_balance");

  assert.equal(interaction?.direction, "mixed");
  assert.ok((interaction?.scorePenalty ?? 0) > 0);
  assert.equal(result.semanticFacts.find(({ measurement }) => measurement === "shoulder_width")?.direction, "smaller");
  assert.equal(result.semanticFacts.find(({ measurement }) => measurement === "chest_width")?.direction, "larger");
});

test("pants waist and hip conflict is surfaced separately from the bounded score penalty", () => {
  const result = score(
    "pants",
    reference({ waist_width: 40, hip_width: 52, rise: 30, outseam: 100 }),
    candidate("M", { waist_width: 36, hip_width: 54, rise: 30, outseam: 100 })
  );
  const interaction = result.interactions.find(({ id }) => id === "waist_hip_balance");

  assert.equal(interaction?.direction, "mixed");
  assert.ok(result.penalty > 0 && result.penalty <= 2);
  assert.equal(result.semanticFacts.find(({ measurement }) => measurement === "waist_width")?.direction, "smaller");
  assert.equal(result.semanticFacts.find(({ measurement }) => measurement === "hip_width")?.direction, "larger");
});

test("skirt ranking and facts exclude rise and outseam even when supplied", () => {
  const owned = reference({ waist_width: 35, hip_width: 48, total_length: 82, rise: 30, outseam: 100 });
  const recommendation = recommendBestSizeWithReferences(
    [owned],
    [
      candidate("M", { waist_width: 35, hip_width: 48, total_length: 82, rise: 5, outseam: 150 }),
      candidate("L", { waist_width: 38, hip_width: 51, total_length: 87, rise: 30, outseam: 100 })
    ],
    "skirt"
  );

  assert.equal(recommendation.recommended.sizeLabel, "M");
  assert.equal(recommendation.recommended.finalFitScore, 100);
  assert.deepEqual(
    [...recommendation.recommended.comparedMeasurements].sort(),
    ["hip_width", "total_length", "waist_width"]
  );
  assert.equal(recommendation.recommended.semanticFacts.some(({ measurement }) => measurement === "rise"), false);
  assert.equal(recommendation.recommended.semanticFacts.some(({ measurement }) => measurement === "outseam"), false);
});
