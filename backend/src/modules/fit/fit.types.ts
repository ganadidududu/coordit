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

export type FitLabel =
  | "very_good_fit"
  | "good_fit"
  | "acceptable"
  | "slightly_small"
  | "slightly_large"
  | "too_small"
  | "too_large";

export type MeasurementKey =
  | "total_length"
  | "shoulder_width"
  | "chest_width"
  | "sleeve_length"
  | "waist_width"
  | "hip_width"
  | "rise"
  | "outseam";

export type MeasurementMap = Partial<Record<MeasurementKey, number | null>>;
export type MeasurementWeights = Partial<Record<MeasurementKey, number>>;
export type MeasurementDiffs = Partial<Record<MeasurementKey, number>>;
export type ReferenceVarianceImportance = "very_high" | "high" | "medium" | "low" | "very_low";
export type FeedbackFitLabel = "too_small" | "slightly_small" | "good" | "slightly_large" | "too_large";
export type PartFeedbackMap = Partial<Record<MeasurementKey, FeedbackFitLabel>>;
export type FeedbackReliabilityStatus =
  | "applied"
  | "insufficient_signal"
  | "conflicting_feedback"
  | "no_directional_signal";

export interface FeedbackReliabilityMetadata {
  applied: boolean;
  status: FeedbackReliabilityStatus;
  categoryUsableRows: number;
  categoryMinUsableRows: number;
  partMinUsableRows: number;
  weightedSampleCount: number;
  partUsableRows: Partial<Record<MeasurementKey, number>>;
  corroboratedRows: number;
}

export interface ReferenceVarianceInfo {
  stdDev: number;
  sampleCount: number;
  importance: ReferenceVarianceImportance;
}

export type ReferenceVarianceMap = Partial<Record<MeasurementKey, ReferenceVarianceInfo>>;
export type MeasurementToleranceMap = Partial<Record<MeasurementKey, number>>;
export type WeightingStrategy =
  | "base_static"
  | "reference_variance_v1"
  | "reference_profile_v1"
  | "feedback_adjusted_profile_v1";
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

export interface ProductMeasurementQuality {
  measurementSource?: string | null;
  parsingStatus?: string | null;
  extractionConfidence?: number | null;
}

export interface ProductMeasurementQualitySummary extends ProductMeasurementQuality {
  trusted: boolean;
  reasonCodes: FitScoreReasonCode[];
}

export interface FitScoreContribution {
  key: MeasurementKey;
  diff: number;
  weightedImpact: number;
  status: "very_similar" | "slightly_small" | "slightly_large" | "large_gap";
}

export interface FitScoreExplanation {
  comparedMeasurementCount: number;
  comparedMeasurements: MeasurementKey[];
  missingMeasurementKeys: MeasurementKey[];
  scoreGapToNextCandidate: number | null;
  normalizedDistance: number;
  penalty: number;
  referenceSampleCounts: Partial<Record<MeasurementKey, number>>;
  topContributingParts: FitScoreContribution[];
  reasonCodes: FitScoreReasonCode[];
}

export interface ConfidenceBreakdown {
  label: RecommendationConfidence;
  score: number;
  comparedMeasurementCount: number;
  scoreGapToNextCandidate: number | null;
  normalizedDistance: number;
  penalty: number;
  reasonCodes: FitScoreReasonCode[];
  referenceSampleCounts: Partial<Record<MeasurementKey, number>>;
  feedbackReliability: {
    applied: boolean;
    sampleCount: number;
    overallSampleCount: number;
    partSampleCount: number;
    status: FeedbackReliabilityStatus | "unavailable";
    weightedSampleCount: number;
    summary: FeedbackReliabilityStatus | "unavailable";
  };
  dataQuality: {
    comparedMeasurementRatio: number;
    missingMeasurementKeys: MeasurementKey[];
    summary: "complete" | "sparse";
    productMeasurementQuality?: ProductMeasurementQualitySummary;
  };
}

export interface ReferenceFitProfile {
  measurements: MeasurementMap;
  tolerances: MeasurementToleranceMap;
  robustScales: MeasurementToleranceMap;
  sampleCounts: Partial<Record<MeasurementKey, number>>;
  strategy: "weighted_huber_profile_v1";
}

export interface FeedbackFitProfile {
  category: Category;
  sampleCount: number;
  overallSampleCount: number;
  partSampleCount: number;
  measurementOffsets: MeasurementDiffs;
  weightMultipliers: MeasurementWeights;
  partFeedbackCounts: Partial<Record<MeasurementKey, Partial<Record<FeedbackFitLabel, number>>>>;
  reliability?: FeedbackReliabilityMetadata;
  strategy: "feedback_offset_weight_v1";
}

export interface ReferenceClothingInput {
  id: string;
  clothingItemId?: string;
  sizeLabel?: string | null;
  fitType: FitType;
  preferenceScore?: number;
  measurements: MeasurementMap;
}

export interface ExternalProductSizeInput {
  id: string;
  sizeLabel: string;
  fitType?: FitType;
  measurements: MeasurementMap;
  measurementQuality?: ProductMeasurementQuality;
}

export interface SizeFitScore {
  externalProductSizeId: string;
  sizeLabel: string;
  fitScore: number;
  finalFitScore: number;
  fitLabel: FitLabel;
  fitComment: string;
  partExplanations: string[];
  partStatuses: Partial<Record<MeasurementKey, "very_similar" | "slightly_small" | "slightly_large" | "large_gap">>;
  recommendationConfidence: RecommendationConfidence;
  weightedFitDistance: number;
  penalty: number;
  diffs: MeasurementDiffs;
  comparedMeasurements: MeasurementKey[];
  scoreExplanation: FitScoreExplanation;
  confidenceBreakdown: ConfidenceBreakdown;
  measurementQuality?: ProductMeasurementQuality;
  algorithmVersion: string;
}

export interface BestSizeRecommendation {
  recommended: SizeFitScore;
  allSizeScores: SizeFitScore[];
  baseWeights: MeasurementWeights;
  dynamicWeights: MeasurementWeights;
  referenceVariance: ReferenceVarianceMap;
  weightingStrategy: WeightingStrategy;
  referenceProfile?: ReferenceFitProfile;
  feedbackProfile?: FeedbackFitProfile;
}

export interface FitRecommendationSizeScore {
  readonly externalProductSizeId: string;
  readonly sizeLabel: string;
  readonly fitScore: number;
  readonly fitLabel: FitLabel;
  readonly weightedFitDistance: number;
  readonly recommendationConfidence: RecommendationConfidence;
  readonly scoreExplanation?: FitScoreExplanation;
  readonly confidenceBreakdown?: ConfidenceBreakdown;
}

export interface FitRecommendationResult {
  readonly fitAnalysisResultId: string;
  readonly recommendedSize: string;
  readonly fitScore: number;
  readonly fitLabel: FitLabel;
  readonly fitComment: string;
  readonly recommendationConfidence: RecommendationConfidence;
  readonly diff: MeasurementDiffs;
  readonly partExplanations: readonly string[];
  readonly partStatuses: SizeFitScore["partStatuses"];
  readonly scoreExplanation?: FitScoreExplanation;
  readonly confidenceBreakdown?: ConfidenceBreakdown;
  readonly baseWeights: MeasurementWeights;
  readonly dynamicWeights: MeasurementWeights;
  readonly referenceVariance: ReferenceVarianceMap;
  readonly weightingStrategy: WeightingStrategy;
  readonly referenceProfile?: ReferenceFitProfile;
  readonly feedbackProfile?: FeedbackFitProfile;
  readonly allSizeScores: readonly FitRecommendationSizeScore[];
  readonly algorithmVersion: string;
}
