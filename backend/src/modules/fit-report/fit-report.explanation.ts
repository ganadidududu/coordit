import { MEASUREMENT_LABELS } from "../fit/fit.constants";
import type { FitScoreReasonCode } from "../fit/fit.types";
import type {
  DataQualityReportSummary,
  ExplanationFactorReportSummary,
  FeedbackReliabilityReportSummary,
  FitReportExplanationSummary,
  MissingMeasurementReportSummary
} from "./fit-report.types";
import { asNumber, getFeedbackApplied, round, type ResultDetails } from "./fit-report.result-details";

const CONFIDENCE_REASON_EXPLANATIONS: Record<FitScoreReasonCode, string> = {
  insufficient_comparable_measurements: "비교 가능한 측정값 수가 부족함",
  missing_measurements: "누락된 측정값이 있음",
  small_score_gap: "1위와 2위 점수 차이가 작음",
  low_reference_sample_count: "기준 의류 샘플 수가 적음",
  feedback_profile_applied: "사용자 피드백 보정이 반영됨",
  feedback_profile_unavailable: "사용자 피드백 보정 데이터가 없음",
  data_quality_unverified_or_sparse: "측정 데이터 품질 확인이 부족하거나 희소함",
  low_measurement_extraction_confidence: "상품 실측 추출 신뢰도가 낮음",
  unverified_product_measurement_status: "상품 실측 파싱 상태가 확인되지 않음",
  mocked_product_measurements: "상품 실측이 목업 데이터임"
};

const getUniqueReasonCodes = (details: ResultDetails): FitScoreReasonCode[] => {
  const reasonCodes = [
    ...(details.confidenceBreakdown?.reasonCodes ?? []),
    ...(details.scoreExplanation?.reasonCodes ?? [])
  ];
  return [...new Set(reasonCodes)];
};

const buildMissingMeasurementSummary = (details: ResultDetails): MissingMeasurementReportSummary => {
  const explanation = details.scoreExplanation;
  if (explanation) {
    return {
      comparedMeasurementCount: explanation.comparedMeasurementCount,
      comparedMeasurements: explanation.comparedMeasurements,
      missingMeasurementKeys: explanation.missingMeasurementKeys,
      summary: explanation.missingMeasurementKeys.length > 0 ? "sparse" : "complete"
    };
  }

  const dataQuality = details.confidenceBreakdown?.dataQuality;
  if (dataQuality) {
    const missingMeasurementKeys = dataQuality.missingMeasurementKeys ?? [];
    return {
      comparedMeasurementCount: details.confidenceBreakdown?.comparedMeasurementCount ?? null,
      comparedMeasurements: [],
      missingMeasurementKeys: [...missingMeasurementKeys],
      summary: dataQuality.summary ?? (missingMeasurementKeys.length > 0 ? "sparse" : "complete")
    };
  }

  return {
    comparedMeasurementCount: null,
    comparedMeasurements: [],
    missingMeasurementKeys: [],
    summary: "unavailable"
  };
};

const buildDataQualitySummary = (details: ResultDetails): DataQualityReportSummary => {
  const dataQuality = details.confidenceBreakdown?.dataQuality;
  if (!dataQuality) {
    return {
      comparedMeasurementRatio: null,
      missingMeasurementKeys: [],
      summary: "unavailable"
    };
  }

  return {
    comparedMeasurementRatio: dataQuality.comparedMeasurementRatio ?? null,
    missingMeasurementKeys: [...(dataQuality.missingMeasurementKeys ?? [])],
    summary: dataQuality.summary ?? "unavailable"
  };
};

const isFeedbackReliabilityStatus = (
  value: unknown
): value is FeedbackReliabilityReportSummary["status"] => {
  switch (value) {
    case "applied":
    case "insufficient_signal":
    case "conflicting_feedback":
    case "no_directional_signal":
    case "unavailable":
      return true;
    default:
      return false;
  }
};

const buildFeedbackReliability = (details: ResultDetails): FeedbackReliabilityReportSummary => {
  const reliability = details.confidenceBreakdown?.feedbackReliability;
  const profileReliability = details.feedbackProfile?.reliability;
  const sampleCount = asNumber(reliability?.sampleCount) ?? asNumber(details.feedbackProfile?.sampleCount) ?? 0;
  const applied = getFeedbackApplied(details);
  const fallbackStatus = applied ? "applied" : "unavailable";
  const status = isFeedbackReliabilityStatus(reliability?.status)
    ? reliability.status
    : isFeedbackReliabilityStatus(profileReliability?.status)
      ? profileReliability.status
      : fallbackStatus;
  const summary = isFeedbackReliabilityStatus(reliability?.summary) ? reliability.summary : status;

  return {
    applied,
    sampleCount,
    overallSampleCount: asNumber(reliability?.overallSampleCount)
      ?? asNumber(details.feedbackProfile?.overallSampleCount)
      ?? asNumber(details.feedbackProfile?.sampleCount)
      ?? 0,
    partSampleCount: asNumber(reliability?.partSampleCount) ?? asNumber(details.feedbackProfile?.partSampleCount) ?? 0,
    status,
    weightedSampleCount: asNumber(reliability?.weightedSampleCount)
      ?? asNumber(profileReliability?.weightedSampleCount)
      ?? sampleCount,
    summary
  };
};

const buildTopExplanationFactors = (details: ResultDetails): ExplanationFactorReportSummary[] =>
  (details.scoreExplanation?.topContributingParts ?? []).slice(0, 3).map((factor) => ({
    measurement: factor.key,
    label: MEASUREMENT_LABELS[factor.key],
    diff: round(factor.diff, 2),
    weightedImpact: round(factor.weightedImpact, 3),
    status: factor.status
  }));

export const buildExplanationSummary = (details: ResultDetails): FitReportExplanationSummary => ({
  confidenceReasons: getUniqueReasonCodes(details).map((code) => ({
    code,
    explanation: CONFIDENCE_REASON_EXPLANATIONS[code]
  })),
  missingMeasurementSummary: buildMissingMeasurementSummary(details),
  dataQualitySummary: buildDataQualitySummary(details),
  feedbackReliability: buildFeedbackReliability(details),
  topExplanationFactors: buildTopExplanationFactors(details)
});
