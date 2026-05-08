import { supabase } from "../../config/supabase";
import type { FitAnalysisResultRow } from "../../shared/types/database";
import { areCategoriesCompatible } from "../../shared/utils/category-compatibility";
import { createHttpError } from "../../shared/utils/http-error";
import { rowToMeasurements } from "../../shared/utils/measurements";
import { ALGORITHM_VERSION } from "./fit.constants";
import { recommendBestSizeWithReferences } from "./fit-score.engine";
import type {
  Category,
  ExternalProductSizeInput,
  FitType,
  MeasurementMap,
  ReferenceClothingInput
} from "./fit.types";

interface RecommendFitParams {
  userId: string;
  referenceClothingId?: string;
  referenceClothingIds?: string[];
  externalProductId: string;
}

interface DbReferenceClothing {
  id: string;
  user_id: string;
  clothing_item_id: string;
  category: string;
  fit_type: FitType;
  preference_score?: number | null;
}

interface DbClothingItem {
  id: string;
  category: string;
  fit_type: FitType;
  size_label: string | null;
}

interface DbMeasurementRow extends MeasurementMap {
  id: string;
  clothing_item_id: string;
  size_label?: string | null;
}

interface DbExternalProduct {
  id: string;
  category: string;
  fit_type: FitType;
}

interface DbExternalProductSize extends MeasurementMap {
  id: string;
  size_label: string;
}

export const recommendFit = async ({
  userId,
  referenceClothingId,
  referenceClothingIds,
  externalProductId
}: RecommendFitParams) => {
  const selectedReferenceIds = referenceClothingIds?.length
    ? referenceClothingIds
    : referenceClothingId
      ? [referenceClothingId]
      : [];

  if (selectedReferenceIds.length === 0) {
    throw createHttpError(400, "At least one reference clothing id is required");
  }

  const { data: referenceClothing, error: referenceError } = await supabase
    .from("reference_clothing")
    .select("*")
    .eq("user_id", userId)
    .eq("is_active", true)
    .in("id", selectedReferenceIds)
    .returns<DbReferenceClothing[]>();

  if (referenceError || !referenceClothing || referenceClothing.length === 0) {
    throw createHttpError(404, "Active reference clothing was not found");
  }

  const clothingItemIds = referenceClothing.map((reference) => reference.clothing_item_id);

  const { data: clothingItems, error: itemError } = await supabase
    .from("clothing_items")
    .select("*")
    .eq("user_id", userId)
    .in("id", clothingItemIds)
    .returns<DbClothingItem[]>();

  if (itemError || !clothingItems || clothingItems.length === 0) {
    throw createHttpError(404, "Connected clothing item was not found");
  }

  const { data: clothingSizes, error: clothingSizeError } = await supabase
    .from("clothing_sizes")
    .select("*")
    .eq("user_id", userId)
    .in("clothing_item_id", clothingItemIds)
    .returns<DbMeasurementRow[]>();

  if (clothingSizeError || !clothingSizes || clothingSizes.length === 0) {
    throw createHttpError(404, "Reference clothing measurements were not found");
  }

  const { data: externalProduct, error: productError } = await supabase
    .from("external_products")
    .select("*")
    .eq("id", externalProductId)
    .eq("user_id", userId)
    .single<DbExternalProduct>();

  if (productError || !externalProduct) {
    throw createHttpError(404, "External product was not found");
  }

  const incompatibleReference = referenceClothing.find(
    (reference) =>
      !areCategoriesCompatible(reference.category as Category, externalProduct.category as Category)
  );
  if (incompatibleReference) {
    throw createHttpError(400, "Reference clothing category is not compatible with external product category");
  }

  const { data: externalSizes, error: sizesError } = await supabase
    .from("external_product_sizes")
    .select("*")
    .eq("external_product_id", externalProductId)
    .eq("user_id", userId)
    .returns<DbExternalProductSize[]>();

  if (sizesError || !externalSizes || externalSizes.length === 0) {
    throw createHttpError(404, "External product sizes were not found");
  }

  const referenceInput: ReferenceClothingInput[] = referenceClothing.map((reference) => {
    const clothingItem = clothingItems.find((item) => item.id === reference.clothing_item_id);
    const clothingSize = clothingSizes.find((size) => size.clothing_item_id === reference.clothing_item_id);
    if (!clothingItem || !clothingSize) {
      throw createHttpError(404, "Reference clothing measurements were not found");
    }
    return {
      id: reference.id,
      clothingItemId: clothingItem.id,
      sizeLabel: clothingItem.size_label,
      fitType: reference.fit_type,
      preferenceScore: reference.preference_score ?? 100,
      measurements: rowToMeasurements(clothingSize)
    };
  });

  const sizeInputs: ExternalProductSizeInput[] = externalSizes.map((size) => ({
    id: size.id,
    sizeLabel: size.size_label,
    fitType: externalProduct.fit_type,
    measurements: rowToMeasurements(size)
  }));

  const recommendation = recommendBestSizeWithReferences(
    referenceInput,
    sizeInputs,
    externalProduct.category as Category
  );
  const best = recommendation.recommended;

  const { data: fitResult, error: resultError } = await supabase
    .from("fit_analysis_results")
    .insert({
      user_id: userId,
      reference_clothing_id: referenceInput[0].id,
      external_product_id: externalProduct.id,
      recommended_external_product_size_id: best.externalProductSizeId,
      recommended_size_label: best.sizeLabel,
      fit_score: best.finalFitScore,
      fit_label: best.fitLabel,
      fit_comment: best.fitComment,
      weighted_fit_distance: best.weightedFitDistance,
      algorithm_version: ALGORITHM_VERSION,
      recommendation_confidence: best.recommendationConfidence,
      result_details: {
        diffs: best.diffs,
        partExplanations: best.partExplanations,
        partStatuses: best.partStatuses,
        referenceClothingIds: referenceInput.map((reference) => reference.id),
        allSizeScores: recommendation.allSizeScores
      }
    })
    .select("*")
    .single<{ id: string }>();

  if (resultError || !fitResult) {
    throw createHttpError(500, "Failed to save fit analysis result");
  }

  await supabase.from("recommendation_logs").insert({
    user_id: userId,
    fit_analysis_result_id: fitResult.id,
    external_product_id: externalProduct.id,
    recommended_size_label: best.sizeLabel,
    event_type: "shown",
    algorithm_version: ALGORITHM_VERSION,
    raw_data: { source: "fit_recommend_api" }
  });

  return {
    fitAnalysisResultId: fitResult.id,
    recommendedSize: best.sizeLabel,
    fitScore: best.finalFitScore,
    fitLabel: best.fitLabel,
    fitComment: best.fitComment,
    recommendationConfidence: best.recommendationConfidence,
    diff: best.diffs,
    partExplanations: best.partExplanations,
    partStatuses: best.partStatuses,
    allSizeScores: recommendation.allSizeScores.map((score) => ({
      externalProductSizeId: score.externalProductSizeId,
      sizeLabel: score.sizeLabel,
      fitScore: score.finalFitScore,
      fitLabel: score.fitLabel,
      weightedFitDistance: score.weightedFitDistance,
      recommendationConfidence: score.recommendationConfidence
    })),
    algorithmVersion: ALGORITHM_VERSION
  };
};

export const recommendFitBatch = async (
  userId: string,
  referenceClothingIds: string[],
  externalProductIds: string[]
) =>
  Promise.all(
    externalProductIds.map((externalProductId) =>
      recommendFit({ userId, referenceClothingIds, externalProductId })
    )
  );

export const listRecentFitAnalysisResults = async (userId: string): Promise<FitAnalysisResultRow[]> => {
  const { data, error } = await supabase
    .from("fit_analysis_results")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(20)
    .returns<FitAnalysisResultRow[]>();
  if (error) throw createHttpError(500, "Failed to load recent fit analysis results");
  return data ?? [];
};

export const getFitAnalysisResult = async (
  userId: string,
  id: string
): Promise<FitAnalysisResultRow> => {
  const { data, error } = await supabase
    .from("fit_analysis_results")
    .select("*")
    .eq("user_id", userId)
    .eq("id", id)
    .single<FitAnalysisResultRow>();
  if (error || !data) throw createHttpError(404, "Fit analysis result was not found");
  return data;
};
