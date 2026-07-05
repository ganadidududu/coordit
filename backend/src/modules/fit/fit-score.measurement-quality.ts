import type {
  FitScoreReasonCode,
  ProductMeasurementQuality,
  ProductMeasurementQualitySummary,
  RecommendationConfidence
} from "./fit.types";

const MIN_TRUSTED_EXTRACTION_CONFIDENCE = 0.8;
const UNTRUSTED_PARSING_STATUSES: readonly string[] = ["unverified", "pending", "failed", "mocked"];
const MOCKED_MEASUREMENT_SOURCES: readonly string[] = ["mock", "mocked"];

const isNumber = (value: number | null | undefined): value is number =>
  typeof value === "number" && Number.isFinite(value);

const normalizeQualityValue = (value: string | null | undefined): string | null => {
  const normalized = value?.trim().toLowerCase();
  return normalized && normalized.length > 0 ? normalized : null;
};

const getProductMeasurementQualityReasonCodes = (
  quality: ProductMeasurementQuality
): FitScoreReasonCode[] => {
  const reasonCodes: FitScoreReasonCode[] = [];
  const measurementSource = normalizeQualityValue(quality.measurementSource);
  const parsingStatus = normalizeQualityValue(quality.parsingStatus);

  if (measurementSource && MOCKED_MEASUREMENT_SOURCES.includes(measurementSource)) {
    reasonCodes.push("mocked_product_measurements");
  }
  if (parsingStatus && UNTRUSTED_PARSING_STATUSES.includes(parsingStatus)) {
    reasonCodes.push("unverified_product_measurement_status");
  }
  if (
    isNumber(quality.extractionConfidence) &&
    quality.extractionConfidence < MIN_TRUSTED_EXTRACTION_CONFIDENCE
  ) {
    reasonCodes.push("low_measurement_extraction_confidence");
  }

  return reasonCodes;
};

export const getProductMeasurementQualitySummary = (
  quality: ProductMeasurementQuality | undefined
): ProductMeasurementQualitySummary | undefined => {
  if (!quality) return undefined;

  const reasonCodes = getProductMeasurementQualityReasonCodes(quality);
  return {
    measurementSource: quality.measurementSource ?? null,
    parsingStatus: quality.parsingStatus ?? null,
    extractionConfidence: quality.extractionConfidence ?? null,
    trusted: reasonCodes.length === 0,
    reasonCodes
  };
};

const lowerConfidence = (confidence: RecommendationConfidence): RecommendationConfidence =>
  confidence === "high" ? "medium" : confidence === "medium" ? "low" : "low";

export const applyProductMeasurementQualityToConfidence = (
  confidence: RecommendationConfidence,
  productMeasurementQuality: ProductMeasurementQualitySummary | undefined
): RecommendationConfidence =>
  productMeasurementQuality && productMeasurementQuality.reasonCodes.length > 0
    ? lowerConfidence(confidence)
    : confidence;
