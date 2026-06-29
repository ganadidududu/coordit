import assert from "node:assert/strict";
import {
  applyFeedbackOffsetsToProfile,
  applyFeedbackWeightMultipliers,
  calculateDynamicWeightsByReferenceVariance,
  calculateFitScoreForReferenceProfile,
  calculateReferenceFitProfile,
  calculateStandardDeviation,
  getWeightsByCategory,
  recommendBestSizeWithReferences
} from "./fit-score.engine";
import type {
  ExternalProductSizeInput,
  FeedbackFitProfile,
  MeasurementWeights,
  ReferenceClothingInput
} from "./fit.types";

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
assert.equal(recommendation.weightingStrategy, "reference_profile_v1");
assert.ok(recommendation.referenceProfile);

const profile = calculateReferenceFitProfile(bottomReferences, recommendation.dynamicWeights);
assert.deepEqual(profile.measurements, {
  waist_width: 40.25,
  hip_width: 52.5,
  rise: 30,
  outseam: 100.5
});
assert.equal(profile.tolerances.waist_width, 0.5);
assert.equal(profile.tolerances.outseam, 1);

const outlierResistantProfile = calculateReferenceFitProfile(
  [
    { id: "stable-a", fitType: "regular", measurements: { waist_width: 40 } },
    { id: "stable-b", fitType: "regular", measurements: { waist_width: 40.2 } },
    { id: "outlier", fitType: "regular", measurements: { waist_width: 50 } }
  ],
  { waist_width: 1 }
);
assert.ok((outlierResistantProfile.measurements.waist_width ?? 0) < 41);
assert.equal(outlierResistantProfile.sampleCounts.waist_width, 3);

const virtualPerfectSize: ExternalProductSizeInput = {
  id: "size-virtual-perfect",
  sizeLabel: "Virtual perfect",
  fitType: "regular",
  measurements: profile.measurements
};
const virtualPerfectScore = calculateFitScoreForReferenceProfile(
  profile,
  virtualPerfectSize,
  "pants",
  recommendation.dynamicWeights
);
assert.equal(virtualPerfectScore.finalFitScore, 100);
assert.equal(virtualPerfectScore.weightedFitDistance, 0);

const feedbackProfile: FeedbackFitProfile = {
  category: "pants",
  sampleCount: 2,
  overallSampleCount: 1,
  partSampleCount: 1,
  measurementOffsets: { waist_width: 1, hip_width: 1 },
  weightMultipliers: { waist_width: 1.2 },
  partFeedbackCounts: { waist_width: { too_small: 1 } },
  strategy: "feedback_offset_weight_v1"
};
const feedbackAdjustedProfile = applyFeedbackOffsetsToProfile(profile, feedbackProfile);
assert.equal(feedbackAdjustedProfile.measurements.waist_width, 41.25);
assert.equal(feedbackAdjustedProfile.measurements.hip_width, 53.5);

const feedbackAdjustedWeights = applyFeedbackWeightMultipliers(recommendation.dynamicWeights, feedbackProfile);
assert.equal(sumWeights(feedbackAdjustedWeights), 1);
assert.ok((feedbackAdjustedWeights.waist_width ?? 0) > (recommendation.dynamicWeights.waist_width ?? 0));

const feedbackRecommendation = recommendBestSizeWithReferences(
  bottomReferences,
  [
    {
      id: "size-original",
      sizeLabel: "Original",
      fitType: "regular",
      measurements: profile.measurements
    },
    {
      id: "size-feedback-fit",
      sizeLabel: "Feedback fit",
      fitType: "regular",
      measurements: feedbackAdjustedProfile.measurements
    }
  ],
  "pants",
  feedbackProfile
);
assert.equal(feedbackRecommendation.recommended.sizeLabel, "Feedback fit");
assert.equal(feedbackRecommendation.weightingStrategy, "feedback_adjusted_profile_v1");
assert.equal(feedbackRecommendation.feedbackProfile?.sampleCount, 2);

console.log("fit-score.engine tests passed");
