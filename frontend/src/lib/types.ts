export type Category =
  | "tshirt"
  | "shirt"
  | "sweatshirt"
  | "hoodie"
  | "knit"
  | "jacket"
  | "coat"
  | "pants"
  | "jeans"
  | "shorts"
  | "skirt";

export type FitType = "slim" | "regular" | "relaxed" | "oversized";

export interface MeasurementFields {
  total_length?: number;
  shoulder_width?: number;
  chest_width?: number;
  sleeve_length?: number;
  waist_width?: number;
  hip_width?: number;
  rise?: number;
  outseam?: number;
}

export interface ReferenceVarianceInfo {
  stdDev: number;
  sampleCount: number;
  importance: "very_high" | "high" | "medium" | "low" | "very_low";
}

export type MeasurementWeights = Partial<Record<keyof MeasurementFields, number>>;
export type ReferenceVarianceMap = Partial<Record<keyof MeasurementFields, ReferenceVarianceInfo>>;
export type MeasurementToleranceMap = Partial<Record<keyof MeasurementFields, number>>;
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

export interface FitScoreContribution {
  readonly key: keyof MeasurementFields;
  readonly diff: number;
  readonly weightedImpact: number;
  readonly status: "very_similar" | "slightly_small" | "slightly_large" | "large_gap";
}

export interface ProductMeasurementQualitySummary {
  readonly measurementSource?: string | null;
  readonly parsingStatus?: string | null;
  readonly extractionConfidence?: number | null;
  readonly trusted: boolean;
  readonly reasonCodes: readonly FitScoreReasonCode[];
}

export interface FitScoreExplanation {
  readonly comparedMeasurementCount: number;
  readonly comparedMeasurements: readonly (keyof MeasurementFields)[];
  readonly missingMeasurementKeys: readonly (keyof MeasurementFields)[];
  readonly scoreGapToNextCandidate: number | null;
  readonly normalizedDistance: number;
  readonly penalty: number;
  readonly referenceSampleCounts: Partial<Record<keyof MeasurementFields, number>>;
  readonly topContributingParts: readonly FitScoreContribution[];
  readonly reasonCodes: readonly FitScoreReasonCode[];
}

export interface ConfidenceBreakdown {
  readonly label: RecommendationConfidence;
  readonly score: number;
  readonly comparedMeasurementCount: number;
  readonly scoreGapToNextCandidate: number | null;
  readonly normalizedDistance: number;
  readonly penalty: number;
  readonly reasonCodes: readonly FitScoreReasonCode[];
  readonly referenceSampleCounts: Partial<Record<keyof MeasurementFields, number>>;
  readonly feedbackReliability?: {
    readonly applied: boolean;
    readonly sampleCount: number;
    readonly overallSampleCount?: number;
    readonly partSampleCount?: number;
    readonly status?: string;
    readonly weightedSampleCount?: number;
    readonly summary?: string;
  };
  readonly dataQuality?: {
    readonly comparedMeasurementRatio: number;
    readonly missingMeasurementKeys: readonly (keyof MeasurementFields)[];
    readonly summary: "complete" | "sparse" | "unavailable";
    readonly productMeasurementQuality?: ProductMeasurementQualitySummary;
  };
}

export interface ReferenceFitProfile {
  measurements: MeasurementFields;
  tolerances: MeasurementToleranceMap;
  robustScales: MeasurementToleranceMap;
  sampleCounts: Partial<Record<keyof MeasurementFields, number>>;
  strategy: "weighted_huber_profile_v1";
}

export interface SizeScore {
  externalProductSizeId: string;
  sizeLabel: string;
  fitScore: number;
  fitLabel: string;
  weightedFitDistance: number;
  recommendationConfidence?: RecommendationConfidence;
  scoreExplanation?: FitScoreExplanation;
  confidenceBreakdown?: ConfidenceBreakdown;
}

export interface FitRecommendationResponse {
  fitAnalysisResultId: string;
  recommendedSize: string;
  fitScore: number;
  fitLabel: string;
  fitComment: string;
  recommendationConfidence: RecommendationConfidence;
  diff: MeasurementFields;
  partExplanations: string[];
  partStatuses: Partial<Record<keyof MeasurementFields, string>>;
  baseWeights?: MeasurementWeights;
  dynamicWeights?: MeasurementWeights;
  referenceVariance?: ReferenceVarianceMap;
  weightingStrategy?: "base_static" | "reference_variance_v1" | "reference_profile_v1" | "feedback_adjusted_profile_v1";
  referenceProfile?: ReferenceFitProfile;
  scoreExplanation?: FitScoreExplanation;
  confidenceBreakdown?: ConfidenceBreakdown;
  allSizeScores: SizeScore[];
  algorithmVersion: string;
}

export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: { id: string; email: string };
}

export interface ClothingItem {
  id: string;
  name: string;
  brand: string | null;
  category: Category;
  fit_type: FitType;
  size_label: string | null;
}

export interface ReferenceClothing {
  id: string;
  clothing_item_id: string;
  nickname: string | null;
  category: Category;
  fit_type: FitType;
  preference_score: number;
  is_active: boolean;
}

export interface ExternalProduct {
  id: string;
  product_name: string;
  brand: string | null;
  mall_name: string | null;
  product_url: string | null;
  category: Category;
  fit_type: FitType;
}
