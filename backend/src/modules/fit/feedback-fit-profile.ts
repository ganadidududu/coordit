import { supabase } from "../../config/supabase";
import { BOTTOM_CATEGORIES } from "./fit.constants";
import type {
  Category,
  FeedbackFitLabel,
  FeedbackFitProfile,
  MeasurementDiffs,
  MeasurementKey,
  MeasurementWeights,
  PartFeedbackMap
} from "./fit.types";

interface FeedbackRow {
  fit_analysis_result_id: string;
  actual_fit_label: string | null;
  part_feedback: PartFeedbackMap | null;
}

interface FitResultFeedbackSource {
  id: string;
  external_product_id: string;
}

interface ExternalProductFeedbackSource {
  id: string;
  category: Category;
}

const MAX_FEEDBACK_ROWS = 50;
const MAX_OFFSET_CM = 2;
const MAX_WEIGHT_MULTIPLIER = 1.3;
const ISSUE_WEIGHT_STEP = 0.1;

const MEASUREMENT_OFFSET_SCALE: Record<MeasurementKey, number> = {
  shoulder_width: 1,
  chest_width: 1,
  total_length: 1.5,
  sleeve_length: 1.25,
  waist_width: 0.75,
  hip_width: 1,
  rise: 0.75,
  outseam: 1.5
};

const TOP_KEYS: MeasurementKey[] = ["shoulder_width", "chest_width", "total_length", "sleeve_length"];
const BOTTOM_KEYS: MeasurementKey[] = ["waist_width", "hip_width", "rise", "outseam"];

const getCategoryMeasurementKeys = (category: Category): MeasurementKey[] =>
  BOTTOM_CATEGORIES.includes(category) ? BOTTOM_KEYS : TOP_KEYS;

const normalizeFeedbackLabel = (label: string | null | undefined): FeedbackFitLabel | undefined => {
  switch (label) {
    case "too_small":
    case "small":
      return "too_small";
    case "slightly_small":
      return "slightly_small";
    case "very_good_fit":
    case "good_fit":
    case "acceptable":
    case "good":
      return "good";
    case "slightly_large":
      return "slightly_large";
    case "too_large":
    case "large":
      return "too_large";
    default:
      return undefined;
  }
};

const getFeedbackDirection = (label: FeedbackFitLabel): number => {
  switch (label) {
    case "too_small":
      return 1;
    case "slightly_small":
      return 0.5;
    case "good":
      return 0;
    case "slightly_large":
      return -0.5;
    case "too_large":
      return -1;
  }
};

const clamp = (value: number, minimum: number, maximum: number): number =>
  Math.max(minimum, Math.min(maximum, value));

const round = (value: number, digits = 3): number => Number(value.toFixed(digits));

const normalizePartFeedback = (value: unknown): PartFeedbackMap => {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};

  return Object.entries(value as Record<string, unknown>).reduce<PartFeedbackMap>((partFeedback, [key, label]) => {
    const normalizedLabel = normalizeFeedbackLabel(typeof label === "string" ? label : undefined);
    if (normalizedLabel && MEASUREMENT_OFFSET_SCALE[key as MeasurementKey]) {
      partFeedback[key as MeasurementKey] = normalizedLabel;
    }
    return partFeedback;
  }, {});
};

export const buildUserFeedbackFitProfile = async (
  userId: string,
  category: Category
): Promise<FeedbackFitProfile | undefined> => {
  const { data: feedbackRows, error: feedbackError } = await supabase
    .from("user_feedback")
    .select("fit_analysis_result_id, actual_fit_label, part_feedback")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(MAX_FEEDBACK_ROWS)
    .returns<FeedbackRow[]>();

  if (feedbackError || !feedbackRows || feedbackRows.length === 0) return undefined;

  const fitResultIds = Array.from(new Set(feedbackRows.map((row) => row.fit_analysis_result_id)));
  const { data: fitResults, error: fitResultsError } = await supabase
    .from("fit_analysis_results")
    .select("id, external_product_id")
    .eq("user_id", userId)
    .in("id", fitResultIds)
    .returns<FitResultFeedbackSource[]>();

  if (fitResultsError || !fitResults || fitResults.length === 0) return undefined;

  const externalProductIds = Array.from(new Set(fitResults.map((result) => result.external_product_id)));
  const { data: externalProducts, error: externalProductsError } = await supabase
    .from("external_products")
    .select("id, category")
    .eq("user_id", userId)
    .in("id", externalProductIds)
    .returns<ExternalProductFeedbackSource[]>();

  if (externalProductsError || !externalProducts || externalProducts.length === 0) return undefined;

  const productCategoryById = new Map(externalProducts.map((product) => [product.id, product.category]));
  const resultCategoryById = new Map(
    fitResults.map((result) => [result.id, productCategoryById.get(result.external_product_id)])
  );
  const categoryFeedback = feedbackRows.filter(
    (row) => resultCategoryById.get(row.fit_analysis_result_id) === category
  );

  if (categoryFeedback.length === 0) return undefined;

  const measurementKeys = getCategoryMeasurementKeys(category);
  const offsetTotals: MeasurementDiffs = {};
  const offsetCounts: Partial<Record<MeasurementKey, number>> = {};
  const issueCounts: Partial<Record<MeasurementKey, number>> = {};
  const partFeedbackCounts: FeedbackFitProfile["partFeedbackCounts"] = {};
  let overallSampleCount = 0;
  let partSampleCount = 0;

  for (const feedback of categoryFeedback) {
    const overallLabel = normalizeFeedbackLabel(feedback.actual_fit_label);
    if (overallLabel) {
      const direction = getFeedbackDirection(overallLabel);
      if (direction !== 0) {
        overallSampleCount += 1;
        for (const key of measurementKeys) {
          offsetTotals[key] = (offsetTotals[key] ?? 0) + direction * MEASUREMENT_OFFSET_SCALE[key];
          offsetCounts[key] = (offsetCounts[key] ?? 0) + 1;
        }
      }
    }

    const partFeedback = normalizePartFeedback(feedback.part_feedback);
    for (const [key, label] of Object.entries(partFeedback) as [MeasurementKey, FeedbackFitLabel][]) {
      if (!measurementKeys.includes(key)) continue;
      partSampleCount += 1;
      partFeedbackCounts[key] = {
        ...partFeedbackCounts[key],
        [label]: (partFeedbackCounts[key]?.[label] ?? 0) + 1
      };

      const direction = getFeedbackDirection(label);
      if (direction !== 0) {
        offsetTotals[key] = (offsetTotals[key] ?? 0) + direction * MEASUREMENT_OFFSET_SCALE[key];
        offsetCounts[key] = (offsetCounts[key] ?? 0) + 1;
        issueCounts[key] = (issueCounts[key] ?? 0) + 1;
      }
    }
  }

  const measurementOffsets = measurementKeys.reduce<MeasurementDiffs>((offsets, key) => {
    const count = offsetCounts[key] ?? 0;
    if (count > 0) {
      offsets[key] = round(clamp((offsetTotals[key] ?? 0) / count, -MAX_OFFSET_CM, MAX_OFFSET_CM));
    }
    return offsets;
  }, {});

  const weightMultipliers = measurementKeys.reduce<MeasurementWeights>((multipliers, key) => {
    const issueCount = issueCounts[key] ?? 0;
    if (issueCount > 0) {
      multipliers[key] = round(clamp(1 + issueCount * ISSUE_WEIGHT_STEP, 1, MAX_WEIGHT_MULTIPLIER));
    }
    return multipliers;
  }, {});

  const sampleCount = overallSampleCount + partSampleCount;
  if (sampleCount === 0) return undefined;

  return {
    category,
    sampleCount,
    overallSampleCount,
    partSampleCount,
    measurementOffsets,
    weightMultipliers,
    partFeedbackCounts,
    strategy: "feedback_offset_weight_v1"
  };
};
