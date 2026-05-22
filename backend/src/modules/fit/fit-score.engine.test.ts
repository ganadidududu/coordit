import assert from "node:assert/strict";
import {
  calculateDynamicWeightsByReferenceVariance,
  calculateStandardDeviation,
  getWeightsByCategory,
  recommendBestSizeWithReferences
} from "./fit-score.engine";
import type { ExternalProductSizeInput, MeasurementWeights, ReferenceClothingInput } from "./fit.types";

const sumWeights = (weights: MeasurementWeights): number =>
  Number(Object.values(weights).reduce((sum, weight) => sum + (weight ?? 0), 0).toFixed(4));

const references: ReferenceClothingInput[] = [
  {
    id: "ref-a",
    fitType: "regular",
    preferenceScore: 100,
    measurements: {
      shoulder_width: 56,
      chest_width: 60,
      total_length: 70,
      sleeve_length: 61
    }
  },
  {
    id: "ref-b",
    fitType: "regular",
    preferenceScore: 100,
    measurements: {
      shoulder_width: 56.5,
      chest_width: 62,
      total_length: 70.5,
      sleeve_length: 66
    }
  },
  {
    id: "ref-c",
    fitType: "regular",
    preferenceScore: 100,
    measurements: {
      shoulder_width: 56,
      chest_width: 59,
      total_length: 71
    }
  }
];

const baseTopWeights = getWeightsByCategory("hoodie");

assert.equal(calculateStandardDeviation([56, 56.5, 56]), 0.236);

const singleReferenceWeights = calculateDynamicWeightsByReferenceVariance(baseTopWeights, [references[0]]);
assert.deepEqual(singleReferenceWeights.dynamicWeights, baseTopWeights);
assert.equal(singleReferenceWeights.weightingStrategy, "base_static");

const dynamicResult = calculateDynamicWeightsByReferenceVariance(baseTopWeights, references);
assert.equal(dynamicResult.weightingStrategy, "reference_variance_v1");
assert.equal(sumWeights(dynamicResult.dynamicWeights), 1);
assert.ok((dynamicResult.dynamicWeights.shoulder_width ?? 0) > (baseTopWeights.shoulder_width ?? 0));
assert.ok((dynamicResult.dynamicWeights.sleeve_length ?? 0) < (baseTopWeights.sleeve_length ?? 0));
assert.equal(dynamicResult.referenceVariance.sleeve_length?.sampleCount, 2);

const missingValueReferences: ReferenceClothingInput[] = [
  { id: "ref-a", fitType: "regular", measurements: { shoulder_width: 56, chest_width: 60 } },
  { id: "ref-b", fitType: "regular", measurements: { shoulder_width: 56.5 } },
  { id: "ref-c", fitType: "regular", measurements: { shoulder_width: 56 } }
];
const missingResult = calculateDynamicWeightsByReferenceVariance(baseTopWeights, missingValueReferences);
assert.equal(missingResult.referenceVariance.shoulder_width?.sampleCount, 3);
assert.equal(missingResult.referenceVariance.chest_width, undefined);

const bottomWeights = getWeightsByCategory("pants");
assert.equal(bottomWeights.outseam, 0.25);
assert.equal(Object.prototype.hasOwnProperty.call(bottomWeights, "inseam"), false);

const bottomReferences: ReferenceClothingInput[] = [
  {
    id: "pants-ref-a",
    fitType: "regular",
    measurements: { waist_width: 40, hip_width: 52, rise: 30, outseam: 100 }
  },
  {
    id: "pants-ref-b",
    fitType: "regular",
    measurements: { waist_width: 40.5, hip_width: 53, rise: 30, outseam: 101 }
  }
];

const externalSizes: ExternalProductSizeInput[] = [
  {
    id: "size-m",
    sizeLabel: "M",
    fitType: "regular",
    measurements: { waist_width: 40, hip_width: 52, rise: 30, outseam: 100 }
  },
  {
    id: "size-l",
    sizeLabel: "L",
    fitType: "regular",
    measurements: { waist_width: 44, hip_width: 56, rise: 32, outseam: 106 }
  }
];

const recommendation = recommendBestSizeWithReferences(bottomReferences, externalSizes, "pants");
assert.equal(recommendation.recommended.sizeLabel, "M");
assert.ok(typeof recommendation.recommended.diffs.outseam === "number");
assert.equal(recommendation.weightingStrategy, "reference_variance_v1");

console.log("fit-score.engine tests passed");
