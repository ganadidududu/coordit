import type { JsonObject, MeasurementKey } from "../../shared/types/database";
import { measurementKeys } from "../../shared/utils/measurements";
import type {
  FeedbackFitLabel,
  FeedbackReliabilityStatus,
  FitScoreContribution,
  FitScoreExplanation,
  FitScoreReasonCode,
  RecommendationConfidence,
  WeightingStrategy
} from "../fit/fit.types";
import {
  asNumber,
  pickNumericMap,
  pickWeightMap,
  type ConfidenceBreakdownInput,
  type ConfidenceFeedbackReliabilityInput,
  type ResultDetails
} from "./fit-report.result-details";

type FeedbackProfileInput = NonNullable<ResultDetails["feedbackProfile"]>;

const REASON_CODES: readonly FitScoreReasonCode[] = ["insufficient_comparable_measurements", "missing_measurements", "small_score_gap", "low_reference_sample_count", "feedback_profile_applied", "feedback_profile_unavailable", "data_quality_unverified_or_sparse", "low_measurement_extraction_confidence", "unverified_product_measurement_status", "mocked_product_measurements"] as const;
const CONTRIBUTION_STATUSES: readonly FitScoreContribution["status"][] = ["very_similar", "slightly_small", "slightly_large", "large_gap"] as const;
const CONFIDENCE_LABELS: readonly RecommendationConfidence[] = ["high", "medium", "low"] as const;
const FEEDBACK_FIT_LABELS: readonly FeedbackFitLabel[] = ["too_small", "slightly_small", "good", "slightly_large", "too_large"] as const;
const FEEDBACK_RELIABILITY_STATUSES = ["applied", "insufficient_signal", "conflicting_feedback", "no_directional_signal", "unavailable"] as const;
const WEIGHTING_STRATEGIES: readonly WeightingStrategy[] = ["base_static", "reference_variance_v1", "reference_profile_v1", "feedback_adjusted_profile_v1"] as const;
const DATA_QUALITY_SUMMARIES = ["complete", "sparse"] as const;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === "object" && !Array.isArray(value);

const isAllowedString = <T extends string>(value: string, allowedValues: readonly T[]): value is T =>
  allowedValues.some((allowedValue) => allowedValue === value);

const isMeasurementKey = (value: string): value is MeasurementKey =>
  isAllowedString(value, measurementKeys);

const isReasonCode = (value: string): value is FitScoreReasonCode =>
  isAllowedString(value, REASON_CODES);

const isContributionStatus = (value: string): value is FitScoreContribution["status"] =>
  isAllowedString(value, CONTRIBUTION_STATUSES);

const isConfidenceLabel = (value: string): value is RecommendationConfidence =>
  isAllowedString(value, CONFIDENCE_LABELS);

const isFeedbackFitLabel = (value: string): value is FeedbackFitLabel =>
  isAllowedString(value, FEEDBACK_FIT_LABELS);

const isFeedbackReliabilityStatus = (
  value: string
): value is FeedbackReliabilityStatus | "unavailable" =>
  isAllowedString(value, FEEDBACK_RELIABILITY_STATUSES);

const isWeightingStrategy = (value: string): value is WeightingStrategy =>
  isAllowedString(value, WEIGHTING_STRATEGIES);

const isDataQualitySummary = (value: string): value is typeof DATA_QUALITY_SUMMARIES[number] =>
  isAllowedString(value, DATA_QUALITY_SUMMARIES);

const hasKeys = (value: JsonObject | Partial<Record<MeasurementKey, number>>): boolean =>
  Object.keys(value).length > 0;

const measurementKeysOnly = (value: unknown): MeasurementKey[] =>
  Array.isArray(value)
    ? value.filter((item): item is MeasurementKey => typeof item === "string" && isMeasurementKey(item))
    : [];

const reasonCodesOnly = (value: unknown): FitScoreReasonCode[] =>
  Array.isArray(value)
    ? value.filter((item): item is FitScoreReasonCode => typeof item === "string" && isReasonCode(item))
    : [];

const numericJsonMap = (source: unknown): JsonObject | undefined => {
  const picked = pickWeightMap(source);
  if (!hasKeys(picked)) return undefined;
  return Object.entries(picked).reduce<JsonObject>((output, [key, value]) => {
    if (typeof value === "number") output[key] = value;
    return output;
  }, {});
};

const sanitizePartFeedbackCounts = (source: unknown): JsonObject | undefined => {
  if (!isRecord(source)) return undefined;
  const output = measurementKeys.reduce<JsonObject>((countsByPart, key) => {
    const labelCounts = source[key];
    if (!isRecord(labelCounts)) return countsByPart;
    const pickedCounts = Object.entries(labelCounts).reduce<JsonObject>((counts, [label, value]) => {
      const count = asNumber(value);
      if (isFeedbackFitLabel(label) && count !== null) counts[label] = count;
      return counts;
    }, {});
    if (hasKeys(pickedCounts)) countsByPart[key] = pickedCounts;
    return countsByPart;
  }, {});
  return hasKeys(output) ? output : undefined;
};

const sanitizeTopContributingParts = (source: unknown): FitScoreContribution[] =>
  Array.isArray(source)
    ? source.flatMap((item): FitScoreContribution[] => {
      if (!isRecord(item) || typeof item.key !== "string" || !isMeasurementKey(item.key)) return [];
      const diff = asNumber(item.diff);
      const weightedImpact = asNumber(item.weightedImpact);
      if (
        diff === null ||
        weightedImpact === null ||
        typeof item.status !== "string" ||
        !isContributionStatus(item.status)
      ) return [];
      return [{ key: item.key, diff, weightedImpact, status: item.status }];
    })
    : [];

const sanitizeScoreExplanation = (source: unknown): FitScoreExplanation | undefined => {
  if (!isRecord(source)) return undefined;
  const comparedMeasurementCount = asNumber(source.comparedMeasurementCount);
  const scoreGapToNextCandidate = source.scoreGapToNextCandidate === null
    ? null
    : asNumber(source.scoreGapToNextCandidate);
  const normalizedDistance = asNumber(source.normalizedDistance);
  const penalty = asNumber(source.penalty);
  if (
    comparedMeasurementCount === null ||
    scoreGapToNextCandidate === null && source.scoreGapToNextCandidate !== null ||
    normalizedDistance === null ||
    penalty === null
  ) return undefined;

  return {
    comparedMeasurementCount,
    comparedMeasurements: measurementKeysOnly(source.comparedMeasurements),
    missingMeasurementKeys: measurementKeysOnly(source.missingMeasurementKeys),
    scoreGapToNextCandidate,
    normalizedDistance,
    penalty,
    referenceSampleCounts: pickWeightMap(source.referenceSampleCounts),
    topContributingParts: sanitizeTopContributingParts(source.topContributingParts),
    reasonCodes: reasonCodesOnly(source.reasonCodes)
  };
};

const sanitizeFeedbackReliability = (
  source: unknown
): ConfidenceFeedbackReliabilityInput | undefined => {
  if (!isRecord(source)) return undefined;
  const sampleCount = asNumber(source.sampleCount);
  const overallSampleCount = asNumber(source.overallSampleCount);
  const partSampleCount = asNumber(source.partSampleCount);
  const weightedSampleCount = asNumber(source.weightedSampleCount);
  const output: ConfidenceFeedbackReliabilityInput = {
    ...(typeof source.applied === "boolean" ? { applied: source.applied } : {}),
    ...(sampleCount !== null ? { sampleCount } : {}),
    ...(overallSampleCount !== null ? { overallSampleCount } : {}),
    ...(partSampleCount !== null ? { partSampleCount } : {}),
    ...(weightedSampleCount !== null ? { weightedSampleCount } : {}),
    ...(typeof source.status === "string" && isFeedbackReliabilityStatus(source.status)
      ? { status: source.status }
      : {}),
    ...(typeof source.summary === "string" && isFeedbackReliabilityStatus(source.summary)
      ? { summary: source.summary }
      : {})
  };
  return Object.keys(output).length > 0 ? output : undefined;
};

const sanitizeDataQuality = (source: unknown): ConfidenceBreakdownInput["dataQuality"] | undefined => {
  if (!isRecord(source)) return undefined;
  const comparedMeasurementRatio = asNumber(source.comparedMeasurementRatio);
  const missingMeasurementKeys = measurementKeysOnly(source.missingMeasurementKeys);
  const summary = typeof source.summary === "string" && isDataQualitySummary(source.summary)
    ? source.summary
    : undefined;
  const output: ConfidenceBreakdownInput["dataQuality"] = {
    ...(comparedMeasurementRatio !== null ? { comparedMeasurementRatio } : {}),
    ...(missingMeasurementKeys.length > 0 ? { missingMeasurementKeys } : {}),
    ...(summary ? { summary } : {})
  };
  return Object.keys(output).length > 0 ? output : undefined;
};

const sanitizeConfidenceBreakdown = (source: unknown): ConfidenceBreakdownInput | undefined => {
  if (!isRecord(source)) return undefined;
  const score = asNumber(source.score);
  const comparedMeasurementCount = asNumber(source.comparedMeasurementCount);
  const scoreGapToNextCandidate = source.scoreGapToNextCandidate === null
    ? null
    : asNumber(source.scoreGapToNextCandidate);
  const normalizedDistance = asNumber(source.normalizedDistance);
  const penalty = asNumber(source.penalty);
  const feedbackReliability = sanitizeFeedbackReliability(source.feedbackReliability);
  const dataQuality = sanitizeDataQuality(source.dataQuality);
  const reasonCodes = reasonCodesOnly(source.reasonCodes);
  const referenceSampleCounts = pickWeightMap(source.referenceSampleCounts);
  const output: ConfidenceBreakdownInput = {
    ...(typeof source.label === "string" && isConfidenceLabel(source.label) ? { label: source.label } : {}),
    ...(score !== null ? { score } : {}),
    ...(comparedMeasurementCount !== null ? { comparedMeasurementCount } : {}),
    ...(scoreGapToNextCandidate !== null || source.scoreGapToNextCandidate === null ? { scoreGapToNextCandidate } : {}),
    ...(normalizedDistance !== null ? { normalizedDistance } : {}),
    ...(penalty !== null ? { penalty } : {}),
    ...(reasonCodes.length > 0 ? { reasonCodes } : {}),
    ...(hasKeys(referenceSampleCounts) ? { referenceSampleCounts } : {}),
    ...(feedbackReliability ? { feedbackReliability } : {}),
    ...(dataQuality ? { dataQuality } : {})
  };
  return Object.keys(output).length > 0 ? output : undefined;
};

const sanitizeReferenceIds = (source: unknown): readonly string[] | undefined =>
  Array.isArray(source) ? source.filter((id): id is string => typeof id === "string") : undefined;

const sanitizeFeedbackProfile = (source: unknown): ResultDetails["feedbackProfile"] | undefined => {
  if (!isRecord(source)) return undefined;
  const sampleCount = asNumber(source.sampleCount);
  const overallSampleCount = asNumber(source.overallSampleCount);
  const partSampleCount = asNumber(source.partSampleCount);
  const measurementOffsets = numericJsonMap(source.measurementOffsets);
  const weightMultipliers = numericJsonMap(source.weightMultipliers);
  const partFeedbackCounts = sanitizePartFeedbackCounts(source.partFeedbackCounts);
  const reliability = sanitizeFeedbackReliability(source.reliability);
  const output: FeedbackProfileInput = {
    ...(sampleCount !== null ? { sampleCount } : {}),
    ...(overallSampleCount !== null ? { overallSampleCount } : {}),
    ...(partSampleCount !== null ? { partSampleCount } : {}),
    ...(measurementOffsets ? { measurementOffsets } : {}),
    ...(weightMultipliers ? { weightMultipliers } : {}),
    ...(partFeedbackCounts ? { partFeedbackCounts } : {}),
    ...(reliability ? { reliability } : {})
  };
  return Object.keys(output).length > 0 ? output : undefined;
};

export const parseResultDetails = (source: unknown): ResultDetails => {
  if (!isRecord(source)) return {};
  const referenceProfile = isRecord(source.referenceProfile) ? source.referenceProfile : null;
  const referenceMeasurements = pickNumericMap(referenceProfile?.measurements);
  const referenceTolerances = pickWeightMap(referenceProfile?.tolerances);
  const parsedReferenceProfile = hasKeys(referenceMeasurements) || hasKeys(referenceTolerances)
    ? {
      ...(hasKeys(referenceMeasurements) ? { measurements: referenceMeasurements } : {}),
      ...(hasKeys(referenceTolerances) ? { tolerances: referenceTolerances } : {})
    }
    : undefined;
  const feedbackProfile = sanitizeFeedbackProfile(source.feedbackProfile);
  const dynamicWeights = pickWeightMap(source.dynamicWeights);
  const scoreExplanation = sanitizeScoreExplanation(source.scoreExplanation);
  const confidenceBreakdown = sanitizeConfidenceBreakdown(source.confidenceBreakdown);
  const referenceClothingIds = sanitizeReferenceIds(source.referenceClothingIds);

  return {
    ...(parsedReferenceProfile ? { referenceProfile: parsedReferenceProfile } : {}),
    ...(feedbackProfile ? { feedbackProfile } : {}),
    ...(hasKeys(dynamicWeights) ? { dynamicWeights } : {}),
    ...(typeof source.weightingStrategy === "string" && isWeightingStrategy(source.weightingStrategy)
      ? { weightingStrategy: source.weightingStrategy }
      : {}),
    ...(scoreExplanation ? { scoreExplanation } : {}),
    ...(confidenceBreakdown ? { confidenceBreakdown } : {}),
    ...(referenceClothingIds && referenceClothingIds.length > 0 ? { referenceClothingIds } : {}),
    ...(Array.isArray(source.allSizeScores) ? { allSizeScores: source.allSizeScores } : {})
  };
};
