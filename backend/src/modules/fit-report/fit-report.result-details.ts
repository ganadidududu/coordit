import type { JsonObject, MeasurementKey, MeasurementMap } from "../../shared/types/database";
import { measurementKeys } from "../../shared/utils/measurements";
import type {
  FeedbackReliabilityStatus,
  FitScoreExplanation,
  FitScoreReasonCode,
  RecommendationConfidence,
  WeightingStrategy
} from "../fit/fit.types";

export type FeedbackReliabilityInput = {
  readonly applied?: boolean;
  readonly sampleCount?: number;
  readonly overallSampleCount?: number;
  readonly partSampleCount?: number;
  readonly status?: FeedbackReliabilityStatus | "unavailable";
  readonly weightedSampleCount?: number;
  readonly summary?: FeedbackReliabilityStatus | "unavailable";
};

export type ConfidenceFeedbackReliabilityInput = Omit<FeedbackReliabilityInput, "status" | "summary"> & {
  readonly status?: FeedbackReliabilityStatus | "unavailable";
  readonly summary?: FeedbackReliabilityStatus | "unavailable";
};

export type ConfidenceBreakdownInput = {
  readonly label?: RecommendationConfidence;
  readonly score?: number;
  readonly comparedMeasurementCount?: number;
  readonly scoreGapToNextCandidate?: number | null;
  readonly normalizedDistance?: number;
  readonly penalty?: number;
  readonly reasonCodes?: readonly FitScoreReasonCode[];
  readonly referenceSampleCounts?: Partial<Record<MeasurementKey, number>>;
  readonly feedbackReliability?: ConfidenceFeedbackReliabilityInput;
  readonly dataQuality?: {
    readonly comparedMeasurementRatio?: number;
    readonly missingMeasurementKeys?: readonly MeasurementKey[];
    readonly summary?: "complete" | "sparse";
  };
};

export type ResultDetails = JsonObject & {
  readonly referenceProfile?: {
    readonly measurements?: MeasurementMap;
    readonly tolerances?: Partial<Record<MeasurementKey, number>>;
  };
  readonly feedbackProfile?: {
    readonly sampleCount?: number;
    readonly overallSampleCount?: number;
    readonly partSampleCount?: number;
    readonly measurementOffsets?: JsonObject;
    readonly weightMultipliers?: JsonObject;
    readonly partFeedbackCounts?: JsonObject;
    readonly reliability?: FeedbackReliabilityInput;
  };
  readonly dynamicWeights?: Partial<Record<MeasurementKey, number>>;
  readonly weightingStrategy?: WeightingStrategy;
  readonly scoreExplanation?: FitScoreExplanation;
  readonly confidenceBreakdown?: ConfidenceBreakdownInput;
  readonly referenceClothingIds?: readonly string[];
  readonly allSizeScores?: readonly unknown[];
  readonly partStatuses?: Partial<Record<MeasurementKey, string>>;
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === "object" && !Array.isArray(value);

export const asNumber = (value: unknown): number | null => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
};

export const pickNumericMap = (source: unknown): MeasurementMap => {
  if (!isRecord(source)) return {};
  return measurementKeys.reduce<MeasurementMap>((picked, key) => {
    const value = asNumber(source[key]);
    if (value !== null) picked[key] = value;
    return picked;
  }, {});
};

export const pickWeightMap = (source: unknown): Partial<Record<MeasurementKey, number>> => {
  if (!isRecord(source)) return {};
  return measurementKeys.reduce<Partial<Record<MeasurementKey, number>>>((picked, key) => {
    const value = asNumber(source[key]);
    if (value !== null) picked[key] = value;
    return picked;
  }, {});
};

export const round = (value: number, digits = 3): number => Number(value.toFixed(digits));

export const getFeedbackApplied = (details: ResultDetails): boolean => {
  const confidenceApplied = details.confidenceBreakdown?.feedbackReliability?.applied;
  if (typeof confidenceApplied === "boolean") return confidenceApplied;

  const profileApplied = details.feedbackProfile?.reliability?.applied;
  if (typeof profileApplied === "boolean") return profileApplied;

  return (asNumber(details.feedbackProfile?.sampleCount) ?? 0) > 0;
};
