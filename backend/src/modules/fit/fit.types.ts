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
  | "inseam";

export type MeasurementMap = Partial<Record<MeasurementKey, number | null>>;
export type MeasurementWeights = Partial<Record<MeasurementKey, number>>;
export type MeasurementDiffs = Partial<Record<MeasurementKey, number>>;

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
  recommendationConfidence: "high" | "medium" | "low";
  weightedFitDistance: number;
  penalty: number;
  diffs: MeasurementDiffs;
  comparedMeasurements: MeasurementKey[];
  algorithmVersion: string;
}

export interface BestSizeRecommendation {
  recommended: SizeFitScore;
  allSizeScores: SizeFitScore[];
}
