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

export interface SizeScore {
  externalProductSizeId: string;
  sizeLabel: string;
  fitScore: number;
  fitLabel: string;
  weightedFitDistance: number;
  recommendationConfidence?: "high" | "medium" | "low";
}

export interface FitRecommendationResponse {
  fitAnalysisResultId: string;
  recommendedSize: string;
  fitScore: number;
  fitLabel: string;
  fitComment: string;
  recommendationConfidence: "high" | "medium" | "low";
  diff: MeasurementFields;
  partExplanations: string[];
  partStatuses: Partial<Record<keyof MeasurementFields, string>>;
  baseWeights?: MeasurementWeights;
  dynamicWeights?: MeasurementWeights;
  referenceVariance?: ReferenceVarianceMap;
  weightingStrategy?: "base_static" | "reference_variance_v1";
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
