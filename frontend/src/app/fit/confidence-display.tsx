import React, { type ReactElement } from "react";

export type RecommendationConfidence = "high" | "medium" | "low";

export type FitScoreReasonCode =
  | "insufficient_comparable_measurements"
  | "missing_measurements"
  | "small_score_gap"
  | "low_reference_sample_count"
  | "feedback_profile_applied"
  | "feedback_profile_unavailable"
  | "data_quality_unverified_or_sparse"
  | "low_measurement_extraction_confidence"
  | "unverified_product_measurement_status"
  | "mocked_product_measurements";

interface ScoreExplanationLike {
  readonly reasonCodes?: readonly FitScoreReasonCode[];
}

interface ConfidenceBreakdownLike {
  readonly label?: RecommendationConfidence;
  readonly reasonCodes?: readonly FitScoreReasonCode[];
  readonly dataQuality?: {
    readonly summary?: "complete" | "sparse" | "unavailable";
    readonly missingMeasurementKeys?: readonly string[];
    readonly productMeasurementQuality?: {
      readonly trusted?: boolean;
      readonly reasonCodes?: readonly FitScoreReasonCode[];
    };
  };
}

export interface ConfidenceDisplayResult {
  readonly recommendation_confidence?: RecommendationConfidence;
  readonly recommendationConfidence?: RecommendationConfidence;
  readonly scoreExplanation?: ScoreExplanationLike;
  readonly confidenceBreakdown?: ConfidenceBreakdownLike;
  readonly result_details?: {
    readonly scoreExplanation?: ScoreExplanationLike;
    readonly confidenceBreakdown?: ConfidenceBreakdownLike;
  };
}

interface ConfidenceDisplayCopy {
  readonly label: RecommendationConfidence | null;
  readonly reasonText: string | null;
  readonly caveatText: string | null;
}

const REASON_LABELS: Partial<Record<FitScoreReasonCode, string>> = {
  insufficient_comparable_measurements: "비교 가능한 실측값이 적습니다.",
  missing_measurements: "일부 측정값이 비어 있습니다.",
  small_score_gap: "후보 사이즈 간 점수 차이가 작습니다.",
  low_reference_sample_count: "기준 의류 샘플이 아직 적습니다.",
  feedback_profile_unavailable: "피드백 보정 데이터가 부족합니다."
};

const CAVEAT_LABELS: Partial<Record<FitScoreReasonCode, string>> = {
  data_quality_unverified_or_sparse: "측정 데이터가 충분히 촘촘하지 않습니다.",
  low_measurement_extraction_confidence: "상품 실측 추출 신뢰도가 낮습니다.",
  unverified_product_measurement_status: "상품 실측 확인 상태가 불완전합니다.",
  mocked_product_measurements: "상품 실측이 임시 데이터입니다."
};

const REASON_PRIORITY: readonly FitScoreReasonCode[] = [
  "small_score_gap",
  "insufficient_comparable_measurements",
  "missing_measurements",
  "low_reference_sample_count",
  "feedback_profile_unavailable",
  "data_quality_unverified_or_sparse",
  "low_measurement_extraction_confidence",
  "unverified_product_measurement_status",
  "mocked_product_measurements"
];

const getUniqueCodes = (codes: readonly FitScoreReasonCode[]): readonly FitScoreReasonCode[] =>
  REASON_PRIORITY.filter((code) => codes.includes(code));

export const getConfidenceDisplayCopy = (result: ConfidenceDisplayResult | null | undefined): ConfidenceDisplayCopy => {
  const details = result?.result_details;
  const confidenceBreakdown = result?.confidenceBreakdown ?? details?.confidenceBreakdown;
  const scoreExplanation = result?.scoreExplanation ?? details?.scoreExplanation;
  const label = result?.recommendation_confidence ?? result?.recommendationConfidence ?? confidenceBreakdown?.label ?? null;

  const reasonCodes = getUniqueCodes([
    ...(confidenceBreakdown?.reasonCodes ?? []),
    ...(scoreExplanation?.reasonCodes ?? []),
    ...(confidenceBreakdown?.dataQuality?.productMeasurementQuality?.reasonCodes ?? [])
  ]);

  const reasonText = reasonCodes.map((code) => REASON_LABELS[code]).find((text): text is string => Boolean(text)) ?? null;
  const caveatText = reasonCodes.map((code) => CAVEAT_LABELS[code]).find((text): text is string => Boolean(text)) ?? null;

  return { label, reasonText, caveatText };
};

export function ConfidenceExplanationText({
  result,
  tone = "dark"
}: {
  readonly result: ConfidenceDisplayResult | null | undefined;
  readonly tone?: "dark" | "light";
}): ReactElement | null {
  const { label, reasonText, caveatText } = getConfidenceDisplayCopy(result);
  if (!label || (label === "high" && !caveatText)) return null;

  const color = tone === "dark" ? "rgba(245,240,230,0.68)" : "var(--text-muted)";

  return (
    <p
      className="korean-sans"
      style={{
        margin: "8px 0 0",
        fontSize: 12,
        lineHeight: 1.55,
        color
      }}
    >
      신뢰도 {label}
      {reasonText ? ` · ${reasonText}` : ""}
      {caveatText ? ` 주의: ${caveatText}` : ""}
    </p>
  );
}
