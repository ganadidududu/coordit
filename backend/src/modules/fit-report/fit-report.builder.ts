import { supabase } from "../../config/supabase";
import type {
  Category,
  ExternalProductRow,
  ExternalProductSizeRow,
  FitAnalysisResultRow,
  FitType,
  JsonObject,
  MeasurementKey,
  MeasurementMap,
  ReferenceClothingRow
} from "../../shared/types/database";
import { createHttpError } from "../../shared/utils/http-error";
import { measurementKeys, rowToMeasurements } from "../../shared/utils/measurements";
import { MEASUREMENT_LABELS } from "../fit/fit.constants";
import type {
  FitReportChartData,
  FitReportInput,
  GenerateFitReportOptions,
  MeasurementReportRow,
  ReferenceClothingReportSummary,
  SizeScoreReportRow
} from "./fit-report.types";

interface ClothingItemForReport {
  id: string;
  name: string;
  category: Category;
  fit_type: FitType;
  size_label: string | null;
}

interface ClothingSizeForReport extends MeasurementMap {
  clothing_item_id: string;
}

type ResultDetails = JsonObject & {
  referenceProfile?: {
    measurements?: MeasurementMap;
    tolerances?: Partial<Record<MeasurementKey, number>>;
  };
  feedbackProfile?: {
    sampleCount?: number;
    measurementOffsets?: JsonObject;
    weightMultipliers?: JsonObject;
    partFeedbackCounts?: JsonObject;
  };
  dynamicWeights?: Partial<Record<MeasurementKey, number>>;
  weightingStrategy?: string;
  referenceClothingIds?: string[];
  allSizeScores?: unknown[];
  partStatuses?: Partial<Record<MeasurementKey, string>>;
};

const isNumber = (value: unknown): value is number =>
  typeof value === "number" && Number.isFinite(value);

const round = (value: number, digits = 3): number => Number(value.toFixed(digits));

const asNumber = (value: unknown): number | null => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
};

const pickNumericMap = (source: unknown): MeasurementMap => {
  if (!source || typeof source !== "object" || Array.isArray(source)) return {};
  return measurementKeys.reduce<MeasurementMap>((picked, key) => {
    const value = asNumber((source as Record<string, unknown>)[key]);
    if (value !== null) picked[key] = value;
    return picked;
  }, {});
};

const pickWeightMap = (source: unknown): Partial<Record<MeasurementKey, number>> => {
  if (!source || typeof source !== "object" || Array.isArray(source)) return {};
  return measurementKeys.reduce<Partial<Record<MeasurementKey, number>>>((picked, key) => {
    const value = asNumber((source as Record<string, unknown>)[key]);
    if (value !== null) picked[key] = value;
    return picked;
  }, {});
};

const getDirection = (diff: number): "larger" | "smaller" | "same" => {
  if (diff > 0) return "larger";
  if (diff < 0) return "smaller";
  return "same";
};

const getPartStatus = (diff: number): string => {
  const absDiff = Math.abs(diff);
  if (absDiff <= 1) return "good";
  if (absDiff <= 3) return diff > 0 ? "loose" : "tight";
  return diff > 0 ? "too_loose" : "too_tight";
};

const getReferenceIds = (fitResult: FitAnalysisResultRow, details: ResultDetails): string[] => {
  const ids = Array.isArray(details.referenceClothingIds)
    ? details.referenceClothingIds.filter((id): id is string => typeof id === "string")
    : [];
  return ids.length > 0 ? ids : [fitResult.reference_clothing_id];
};

const loadFitResult = async (userId: string, id: string): Promise<FitAnalysisResultRow> => {
  const { data, error } = await supabase
    .from("fit_analysis_results")
    .select("*")
    .eq("user_id", userId)
    .eq("id", id)
    .single<FitAnalysisResultRow>();

  if (error || !data) throw createHttpError(404, "Fit analysis result was not found");
  return data;
};

const loadExternalProduct = async (
  userId: string,
  id: string
): Promise<ExternalProductRow> => {
  const { data, error } = await supabase
    .from("external_products")
    .select("*")
    .eq("user_id", userId)
    .eq("id", id)
    .single<ExternalProductRow>();

  if (error || !data) throw createHttpError(404, "External product was not found");
  return data;
};

const loadExternalProductSizes = async (
  userId: string,
  externalProductId: string
): Promise<ExternalProductSizeRow[]> => {
  const { data, error } = await supabase
    .from("external_product_sizes")
    .select("*")
    .eq("user_id", userId)
    .eq("external_product_id", externalProductId)
    .returns<ExternalProductSizeRow[]>();

  if (error) throw createHttpError(500, "Failed to load external product sizes");
  return data ?? [];
};

const loadReferenceClothing = async (
  userId: string,
  ids: string[]
): Promise<ReferenceClothingRow[]> => {
  const { data, error } = await supabase
    .from("reference_clothing")
    .select("*")
    .eq("user_id", userId)
    .in("id", ids)
    .returns<ReferenceClothingRow[]>();

  if (error) throw createHttpError(500, "Failed to load reference clothing");
  return data ?? [];
};

const loadClothingItems = async (
  userId: string,
  ids: string[]
): Promise<ClothingItemForReport[]> => {
  if (ids.length === 0) return [];
  const { data, error } = await supabase
    .from("clothing_items")
    .select("id, name, category, fit_type, size_label")
    .eq("user_id", userId)
    .in("id", ids)
    .returns<ClothingItemForReport[]>();

  if (error) throw createHttpError(500, "Failed to load clothing items");
  return data ?? [];
};

const loadClothingSizes = async (
  userId: string,
  clothingItemIds: string[]
): Promise<ClothingSizeForReport[]> => {
  if (clothingItemIds.length === 0) return [];
  const { data, error } = await supabase
    .from("clothing_sizes")
    .select("*")
    .eq("user_id", userId)
    .in("clothing_item_id", clothingItemIds)
    .returns<ClothingSizeForReport[]>();

  if (error) throw createHttpError(500, "Failed to load clothing measurements");
  return data ?? [];
};

const buildReferenceSummary = async (
  userId: string,
  referenceIds: string[]
): Promise<ReferenceClothingReportSummary[]> => {
  const references = await loadReferenceClothing(userId, referenceIds);
  const clothingItems = await loadClothingItems(
    userId,
    references.map((reference) => reference.clothing_item_id)
  );
  const clothingSizes = await loadClothingSizes(
    userId,
    references.map((reference) => reference.clothing_item_id)
  );

  return references.map((reference) => {
    const item = clothingItems.find((candidate) => candidate.id === reference.clothing_item_id);
    const size = clothingSizes.find((candidate) => candidate.clothing_item_id === reference.clothing_item_id);
    return {
      name: reference.nickname || item?.name || "기준 의류",
      category: reference.category,
      fitType: reference.fit_type,
      sizeLabel: item?.size_label ?? null,
      preferenceScore: reference.preference_score,
      measurements: size ? rowToMeasurements(size) : {}
    };
  });
};

const getSelectedProductSize = (
  sizes: ExternalProductSizeRow[],
  selectedSizeLabel: string,
  recommendedExternalProductSizeId: string | null
): ExternalProductSizeRow | undefined =>
  sizes.find((size) => size.size_label === selectedSizeLabel) ??
  sizes.find((size) => size.id === recommendedExternalProductSizeId) ??
  sizes[0];

const getScoreGapToSecond = (sizeScores: SizeScoreReportRow[]): number | null => {
  if (sizeScores.length < 2) return null;
  return round(sizeScores[0].fitScore - sizeScores[1].fitScore, 2);
};

const buildMeasurementRows = (
  idealMeasurements: MeasurementMap,
  productMeasurements: MeasurementMap,
  details: ResultDetails
): MeasurementReportRow[] =>
  measurementKeys.flatMap((key) => {
    const ideal = idealMeasurements[key];
    const product = productMeasurements[key];
    if (!isNumber(ideal) || !isNumber(product)) return [];
    const diff = round(product - ideal, 2);
    return [{
      key,
      label: MEASUREMENT_LABELS[key],
      ideal: round(ideal, 3),
      product: round(product, 3),
      diff,
      unit: "cm" as const,
      weight: asNumber(details.dynamicWeights?.[key]),
      tolerance: asNumber(details.referenceProfile?.tolerances?.[key]),
      status: getPartStatus(diff)
    }];
  });

const buildChartData = (
  measurementRows: MeasurementReportRow[],
  sizeScores: SizeScoreReportRow[],
  details: ResultDetails
): FitReportChartData => ({
  idealVsProduct: measurementRows.map((row) => ({
    measurement: row.key,
    label: row.label,
    ideal: row.ideal,
    product: row.product,
    diff: row.diff,
    status: row.status
  })),
  differenceBar: measurementRows.map((row) => ({
    measurement: row.key,
    label: row.label,
    diff: row.diff,
    direction: getDirection(row.diff),
    status: row.status
  })),
  sizeScoreRanking: sizeScores,
  feedbackAdjustment: measurementKeys.map((key) => ({
    measurement: key,
    label: MEASUREMENT_LABELS[key],
    offset: asNumber(details.feedbackProfile?.measurementOffsets?.[key]) ?? 0,
    weightMultiplier: asNumber(details.feedbackProfile?.weightMultipliers?.[key]) ?? 1
  }))
});

const normalizeSizeScores = (
  allSizeScores: ResultDetails["allSizeScores"],
  fitResult: FitAnalysisResultRow
): SizeScoreReportRow[] => {
  const fromDetails = Array.isArray(allSizeScores)
    ? allSizeScores.flatMap((score) => {
      if (!score || typeof score !== "object") return [];
      if (!score || typeof score !== "object" || Array.isArray(score)) return [];
      const scoreRecord = score as Record<string, unknown>;
      const fitScore = asNumber(scoreRecord.finalFitScore) ?? asNumber(scoreRecord.fitScore);
      const weightedFitDistance = asNumber(scoreRecord.weightedFitDistance);
      const sizeLabel = scoreRecord.sizeLabel;
      const fitLabel = scoreRecord.fitLabel;
      const recommendationConfidence = scoreRecord.recommendationConfidence;
      if (
        typeof sizeLabel !== "string" ||
        fitScore === null ||
        typeof fitLabel !== "string" ||
        weightedFitDistance === null ||
        typeof recommendationConfidence !== "string"
      ) return [];
      return [{ sizeLabel, fitScore, fitLabel, weightedFitDistance, recommendationConfidence }];
    })
    : [];

  if (fromDetails.length > 0) {
    return fromDetails.sort((a, b) => b.fitScore - a.fitScore);
  }

  return [{
    sizeLabel: fitResult.recommended_size_label,
    fitScore: fitResult.fit_score,
    fitLabel: fitResult.fit_label,
    weightedFitDistance: fitResult.weighted_fit_distance,
    recommendationConfidence: fitResult.recommendation_confidence
  }];
};

export const buildFitReportInput = async (
  userId: string,
  fitAnalysisResultId: string,
  options: GenerateFitReportOptions = {}
): Promise<FitReportInput> => {
  const fitResult = await loadFitResult(userId, fitAnalysisResultId);
  const details = fitResult.result_details as ResultDetails;
  const externalProduct = await loadExternalProduct(userId, fitResult.external_product_id);
  const externalSizes = await loadExternalProductSizes(userId, fitResult.external_product_id);
  const selectedSizeLabel = options.selectedSizeLabel ?? fitResult.recommended_size_label;
  const selectedSize = getSelectedProductSize(
    externalSizes,
    selectedSizeLabel,
    fitResult.recommended_external_product_size_id
  );
  if (!selectedSize) throw createHttpError(404, "External product size was not found");

  const referenceIds = getReferenceIds(fitResult, details);
  const referenceSummary = await buildReferenceSummary(userId, referenceIds);
  const idealMeasurements = pickNumericMap(details.referenceProfile?.measurements);
  const productMeasurements = rowToMeasurements(selectedSize);
  const sizeScores = normalizeSizeScores(details.allSizeScores, fitResult);
  const measurementRows = buildMeasurementRows(idealMeasurements, productMeasurements, details);
  const chartData = buildChartData(measurementRows, sizeScores, details);

  return {
    locale: "ko-KR",
    reportStyle: options.style ?? "concise_but_explanatory",
    engineVersion: fitResult.algorithm_version,
    recommendation: {
      recommendedSize: fitResult.recommended_size_label,
      fitScore: fitResult.fit_score,
      fitLabel: fitResult.fit_label,
      recommendationConfidence: fitResult.recommendation_confidence,
      weightedFitDistance: fitResult.weighted_fit_distance,
      scoreGapToSecond: getScoreGapToSecond(sizeScores),
      weightingStrategy: typeof details.weightingStrategy === "string" ? details.weightingStrategy : null
    },
    targetProduct: {
      productName: externalProduct.product_name,
      brand: externalProduct.brand,
      mallName: externalProduct.mall_name,
      category: externalProduct.category,
      fitType: externalProduct.fit_type,
      selectedSizeLabel: selectedSize.size_label,
      recommendedSizeLabel: fitResult.recommended_size_label
    },
    referenceClothingSummary: referenceSummary,
    idealFitNumbers: {
      measurements: idealMeasurements,
      tolerances: pickWeightMap(details.referenceProfile?.tolerances),
      weights: pickWeightMap(details.dynamicWeights)
    },
    measurements: measurementRows,
    sizeScores,
    feedbackPersonalization: {
      applied: (asNumber(details.feedbackProfile?.sampleCount) ?? 0) > 0,
      sampleCount: asNumber(details.feedbackProfile?.sampleCount) ?? 0,
      measurementOffsets: details.feedbackProfile?.measurementOffsets ?? {},
      weightMultipliers: details.feedbackProfile?.weightMultipliers ?? {},
      partFeedbackCounts: details.feedbackProfile?.partFeedbackCounts ?? {}
    },
    chartData
  };
};
