import type {
  Category,
  FeedbackFitLabel,
  FeedbackReliabilityStatus,
  FitLabel,
  FitScoreContribution,
  FitScoreReasonCode,
  FitType,
  MeasurementKey,
  RecommendationConfidence
} from "./fit.types";

export type JsonPrimitive = string | number | boolean | null;
export type JsonValue = JsonPrimitive | readonly JsonValue[] | { readonly [key: string]: JsonValue };
export type MeasurementFeedback = Partial<Record<MeasurementKey, FeedbackFitLabel>>;

const MEASUREMENT_KEYS: readonly MeasurementKey[] = ["total_length", "shoulder_width", "chest_width", "sleeve_length", "waist_width", "hip_width", "rise", "outseam"] as const;
const MEASUREMENT_LABELS: Readonly<Record<MeasurementKey, string>> = {
  total_length: "total length",
  shoulder_width: "shoulder width",
  chest_width: "chest width",
  sleeve_length: "sleeve length",
  waist_width: "waist width",
  hip_width: "hip width",
  rise: "rise",
  outseam: "outseam"
};
const CATEGORIES: readonly Category[] = ["tshirt", "shirt", "sweatshirt", "hoodie", "knit", "jacket", "coat", "pants", "jeans", "shorts", "skirt"] as const;
const FIT_TYPES: readonly FitType[] = ["slim", "regular", "relaxed", "oversized"] as const;
const FIT_LABELS: readonly FitLabel[] = ["very_good_fit", "good_fit", "acceptable", "slightly_small", "slightly_large", "too_small", "too_large"] as const;
const FEEDBACK_LABELS: readonly FeedbackFitLabel[] = ["too_small", "slightly_small", "good", "slightly_large", "too_large"] as const;
const REASON_CODES: readonly FitScoreReasonCode[] = ["insufficient_comparable_measurements", "missing_measurements", "small_score_gap", "low_reference_sample_count", "feedback_profile_applied", "feedback_profile_unavailable", "data_quality_unverified_or_sparse", "low_measurement_extraction_confidence", "unverified_product_measurement_status", "mocked_product_measurements"] as const;
const CONFIDENCE_LABELS: readonly RecommendationConfidence[] = ["high", "medium", "low"] as const;
const CONTRIBUTION_STATUSES: readonly FitScoreContribution["status"][] = ["very_similar", "slightly_small", "slightly_large", "large_gap"] as const;
const FEEDBACK_RELIABILITY_STATUSES: readonly (FeedbackReliabilityStatus | "unavailable")[] = ["applied", "insufficient_signal", "conflicting_feedback", "no_directional_signal", "unavailable"] as const;
const DATA_QUALITY_SUMMARIES = ["complete", "sparse"] as const;
const MEASUREMENT_SOURCES = ["manual", "ocr", "url", "admin", "mock", "mocked"] as const;
const PARSING_STATUSES = ["manual", "accepted", "confirmed", "parsed", "pending", "failed", "mocked", "unverified"] as const;
const EVENT_TYPES = ["shown", "clicked", "purchased"] as const;
const SAFE_EXPORT_REF_PATTERN = /^(?:sample-\d{3,6}|(?:fit-)?export-[a-z0-9][a-z0-9_-]{7,39})$/;
const SAFE_SIZE_LABEL_PATTERN = /^[A-Za-z0-9][A-Za-z0-9 .+/_-]{0,15}$/;
const SAFE_ALGORITHM_VERSION_PATTERN = /^(mvp_rule_v\d+(?:_\d+)*|fit-score-v\d+(?:\.\d+)*)$/;
const SAFE_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const SAFE_OBSERVED_AT_PATTERN = /^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2}))?$/;
const SUSPICIOUS_TEXT_PATTERN = /(?:^|[^a-z])(ignore|instruction|prompt|private|token|bearer|secret|phone|email|address|leak|override|raw|payload)(?:$|[^a-z])/i;
const PHONE_LIKE_PATTERN = /\b\d{2,4}[-. ]\d{3,4}(?:[-. ]\d{0,4})?\b/;
const CONTIGUOUS_PRIVATE_DIGITS_PATTERN = /\d{7,}/;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const isAllowedString = <T extends string>(value: string, allowedValues: readonly T[]): value is T =>
  allowedValues.some((allowedValue) => allowedValue === value);

const normalizeToken = (value: string | null | undefined): string | null =>
  value?.trim().toLowerCase() ?? null;

const hasUnsafeText = (value: string): boolean =>
  SUSPICIOUS_TEXT_PATTERN.test(value) || PHONE_LIKE_PATTERN.test(value) || CONTIGUOUS_PRIVATE_DIGITS_PATTERN.test(value);

const isValidDateOnly = (value: string): boolean => {
  if (!SAFE_DATE_PATTERN.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().startsWith(`${value}T`);
};

export const normalizeCategory = (value: string | null | undefined): Category | null => {
  const normalized = normalizeToken(value);
  return normalized && isAllowedString(normalized, CATEGORIES) ? normalized : null;
};

export const normalizeFitType = (value: string | null | undefined): FitType | null => {
  const normalized = normalizeToken(value);
  return normalized && isAllowedString(normalized, FIT_TYPES) ? normalized : null;
};

export const normalizeFitLabel = (value: string | null | undefined): FitLabel | null => {
  const normalized = normalizeToken(value);
  return normalized && isAllowedString(normalized, FIT_LABELS) ? normalized : null;
};

export const normalizeFeedbackLabel = (value: string | null | undefined): FeedbackFitLabel | null => {
  const normalized = normalizeToken(value);
  return normalized && isAllowedString(normalized, FEEDBACK_LABELS) ? normalized : null;
};

export const normalizeRecommendationConfidence = (value: string | null | undefined): RecommendationConfidence | null => {
  const normalized = normalizeToken(value);
  return normalized && isAllowedString(normalized, CONFIDENCE_LABELS) ? normalized : null;
};

export const normalizeEventType = (value: string | null | undefined): typeof EVENT_TYPES[number] | null => {
  const normalized = normalizeToken(value);
  return normalized && isAllowedString(normalized, EVENT_TYPES) ? normalized : null;
};

export const normalizeAlgorithmVersion = (value: string | null | undefined): string | null => {
  const normalized = normalizeToken(value);
  return normalized && SAFE_ALGORITHM_VERSION_PATTERN.test(normalized) ? normalized : null;
};

export const normalizeExportRef = (value: string | null | undefined): string | null => {
  const normalized = value?.trim() ?? null;
  return normalized && !hasUnsafeText(normalized) && SAFE_EXPORT_REF_PATTERN.test(normalized) ? normalized : null;
};

export const normalizeObservedAt = (value: string | null | undefined): string | null => {
  const normalized = value?.trim() ?? null;
  if (!normalized || hasUnsafeText(normalized) || !SAFE_OBSERVED_AT_PATTERN.test(normalized)) return null;
  if (normalized.length === 10) return isValidDateOnly(normalized) ? normalized : null;
  return Number.isFinite(Date.parse(normalized)) && isValidDateOnly(normalized.slice(0, 10)) ? normalized : null;
};

export const normalizeSizeLabel = (value: string | null | undefined): string | null => {
  const normalized = value?.trim() ?? null;
  return normalized && !hasUnsafeText(normalized) && SAFE_SIZE_LABEL_PATTERN.test(normalized) ? normalized : null;
};

const isMeasurementKey = (value: string): value is MeasurementKey =>
  isAllowedString(value, MEASUREMENT_KEYS);

const isFeedbackLabel = (value: string): value is FeedbackFitLabel =>
  isAllowedString(value, FEEDBACK_LABELS);

const isReasonCode = (value: string): value is FitScoreReasonCode =>
  isAllowedString(value, REASON_CODES);

const isConfidenceLabel = (value: string): value is RecommendationConfidence =>
  isAllowedString(value, CONFIDENCE_LABELS);

const isContributionStatus = (value: string): value is FitScoreContribution["status"] =>
  isAllowedString(value, CONTRIBUTION_STATUSES);

const isFeedbackReliabilityStatus = (value: string): value is FeedbackReliabilityStatus | "unavailable" =>
  isAllowedString(value, FEEDBACK_RELIABILITY_STATUSES);

const isDataQualitySummary = (value: string): value is typeof DATA_QUALITY_SUMMARIES[number] =>
  isAllowedString(value, DATA_QUALITY_SUMMARIES);

const isMeasurementSource = (value: string): value is typeof MEASUREMENT_SOURCES[number] =>
  isAllowedString(value, MEASUREMENT_SOURCES);

const isParsingStatus = (value: string): value is typeof PARSING_STATUSES[number] =>
  isAllowedString(value, PARSING_STATUSES);

export const normalizeFiniteNumber = (value: unknown): number | null =>
  typeof value === "number" && Number.isFinite(value) ? value : null;

const isFiniteNumber = (value: unknown): value is number =>
  normalizeFiniteNumber(value) !== null;

const hasEntries = (value: Record<string, JsonValue>): boolean =>
  Object.keys(value).length > 0;

export const normalizePartFeedback = (value: unknown): MeasurementFeedback => {
  if (!isRecord(value)) return {};

  const partFeedback: MeasurementFeedback = {};
  for (const [key, label] of Object.entries(value)) {
    if (isMeasurementKey(key) && typeof label === "string" && isFeedbackLabel(label)) {
      partFeedback[key] = label;
    }
  }
  return partFeedback;
};

const measurementKeysOnly = (value: unknown): readonly MeasurementKey[] =>
  Array.isArray(value)
    ? value.filter((item): item is MeasurementKey => typeof item === "string" && isMeasurementKey(item))
    : [];

const reasonCodesOnly = (value: unknown): readonly FitScoreReasonCode[] =>
  Array.isArray(value)
    ? value.filter((item): item is FitScoreReasonCode => typeof item === "string" && isReasonCode(item))
    : [];

const numericMeasurementMap = (value: unknown): JsonValue | undefined => {
  if (!isRecord(value)) return undefined;
  const output: Record<string, JsonValue> = {};
  for (const [key, count] of Object.entries(value)) {
    if (isMeasurementKey(key) && isFiniteNumber(count)) output[key] = count;
  }
  return hasEntries(output) ? output : undefined;
};

const topContributingPartsOnly = (value: unknown): JsonValue | undefined => {
  if (!Array.isArray(value)) return undefined;
  const output = value.flatMap((item): JsonValue[] => {
    if (!isRecord(item) || typeof item.key !== "string" || !isMeasurementKey(item.key)) return [];
    const part: Record<string, JsonValue> = { key: item.key, label: MEASUREMENT_LABELS[item.key] };
    if (isFiniteNumber(item.diff)) part.diff = item.diff;
    if (isFiniteNumber(item.weightedImpact)) part.weightedImpact = item.weightedImpact;
    if (typeof item.status === "string" && isContributionStatus(item.status)) part.status = item.status;
    return [part];
  });
  return output.length > 0 ? output : undefined;
};

const setNumber = (output: Record<string, JsonValue>, key: string, value: unknown): void => {
  if (isFiniteNumber(value)) output[key] = value;
};

const setNullableNumber = (output: Record<string, JsonValue>, key: string, value: unknown): void => {
  if (value === null || isFiniteNumber(value)) output[key] = value;
};

const setMeasurementKeys = (output: Record<string, JsonValue>, key: string, value: unknown): void => {
  const keys = measurementKeysOnly(value);
  if (keys.length > 0) output[key] = keys;
};

const setReasonCodes = (output: Record<string, JsonValue>, key: string, value: unknown): void => {
  const codes = reasonCodesOnly(value);
  if (codes.length > 0) output[key] = codes;
};

export const normalizeScoreExplanation = (source: unknown): JsonValue | null => {
  if (!isRecord(source)) return null;
  const output: Record<string, JsonValue> = {};
  setNumber(output, "comparedMeasurementCount", source.comparedMeasurementCount);
  setMeasurementKeys(output, "comparedMeasurements", source.comparedMeasurements);
  setMeasurementKeys(output, "missingMeasurementKeys", source.missingMeasurementKeys);
  setNullableNumber(output, "scoreGapToNextCandidate", source.scoreGapToNextCandidate);
  setNumber(output, "normalizedDistance", source.normalizedDistance);
  setNumber(output, "penalty", source.penalty);
  const referenceSampleCounts = numericMeasurementMap(source.referenceSampleCounts);
  if (referenceSampleCounts !== undefined) output.referenceSampleCounts = referenceSampleCounts;
  const topContributingParts = topContributingPartsOnly(source.topContributingParts);
  if (topContributingParts !== undefined) output.topContributingParts = topContributingParts;
  setReasonCodes(output, "reasonCodes", source.reasonCodes);
  return hasEntries(output) ? output : null;
};

const normalizeFeedbackReliability = (source: unknown): JsonValue | undefined => {
  if (!isRecord(source)) return undefined;
  const output: Record<string, JsonValue> = {};
  if (typeof source.applied === "boolean") output.applied = source.applied;
  for (const key of ["sampleCount", "overallSampleCount", "partSampleCount", "weightedSampleCount"] as const) {
    setNumber(output, key, source[key]);
  }
  if (typeof source.status === "string" && isFeedbackReliabilityStatus(source.status)) output.status = source.status;
  if (typeof source.summary === "string" && isFeedbackReliabilityStatus(source.summary)) output.summary = source.summary;
  return hasEntries(output) ? output : undefined;
};

const normalizeProductMeasurementQuality = (source: unknown): JsonValue | undefined => {
  if (!isRecord(source)) return undefined;
  const output: Record<string, JsonValue> = {};
  if (typeof source.measurementSource === "string" && isMeasurementSource(source.measurementSource)) output.measurementSource = source.measurementSource;
  if (typeof source.parsingStatus === "string" && isParsingStatus(source.parsingStatus)) output.parsingStatus = source.parsingStatus;
  setNumber(output, "extractionConfidence", source.extractionConfidence);
  if (typeof source.trusted === "boolean") output.trusted = source.trusted;
  setReasonCodes(output, "reasonCodes", source.reasonCodes);
  return hasEntries(output) ? output : undefined;
};

const normalizeDataQuality = (source: unknown): JsonValue | undefined => {
  if (!isRecord(source)) return undefined;
  const output: Record<string, JsonValue> = {};
  setNumber(output, "comparedMeasurementRatio", source.comparedMeasurementRatio);
  setMeasurementKeys(output, "missingMeasurementKeys", source.missingMeasurementKeys);
  if (typeof source.summary === "string" && isDataQualitySummary(source.summary)) output.summary = source.summary;
  const productMeasurementQuality = normalizeProductMeasurementQuality(source.productMeasurementQuality);
  if (productMeasurementQuality !== undefined) output.productMeasurementQuality = productMeasurementQuality;
  return hasEntries(output) ? output : undefined;
};

export const normalizeConfidenceBreakdown = (source: unknown): JsonValue | null => {
  if (!isRecord(source)) return null;
  const output: Record<string, JsonValue> = {};
  if (typeof source.label === "string" && isConfidenceLabel(source.label)) output.label = source.label;
  setNumber(output, "score", source.score);
  setNumber(output, "comparedMeasurementCount", source.comparedMeasurementCount);
  setNullableNumber(output, "scoreGapToNextCandidate", source.scoreGapToNextCandidate);
  setNumber(output, "normalizedDistance", source.normalizedDistance);
  setNumber(output, "penalty", source.penalty);
  setReasonCodes(output, "reasonCodes", source.reasonCodes);
  const referenceSampleCounts = numericMeasurementMap(source.referenceSampleCounts);
  if (referenceSampleCounts !== undefined) output.referenceSampleCounts = referenceSampleCounts;
  const feedbackReliability = normalizeFeedbackReliability(source.feedbackReliability);
  if (feedbackReliability !== undefined) output.feedbackReliability = feedbackReliability;
  const dataQuality = normalizeDataQuality(source.dataQuality);
  if (dataQuality !== undefined) output.dataQuality = dataQuality;
  return hasEntries(output) ? output : null;
};

export const normalizeMeasurementSource = (value: string | null | undefined): string | null =>
  value && isMeasurementSource(value) ? value : null;

export const normalizeParsingStatus = (value: string | null | undefined): string | null =>
  value && isParsingStatus(value) ? value : null;
