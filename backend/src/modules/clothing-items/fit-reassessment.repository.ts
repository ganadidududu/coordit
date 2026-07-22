import { supabase } from "../../config/supabase";
import type {
  ClothingItemRow,
  ClothingSizeRow,
  ReferenceClothingRow
} from "../../shared/types/database";
import { getCompatibleCategories } from "../../shared/utils/category-compatibility";
import { createHttpError } from "../../shared/utils/http-error";
import type {
  FitReassessmentRepository,
  FitReassessmentSource
} from "./fit-reassessment.types";
import { parseClothingFitAssessment } from "./fit-reassessment.validation";

const loadSizes = async (
  userId: string,
  clothingItemIds: readonly string[]
): Promise<readonly ClothingSizeRow[]> => {
  const { data, error } = await supabase
    .from("clothing_sizes")
    .select("*")
    .eq("user_id", userId)
    .in("clothing_item_id", [...clothingItemIds])
    .order("created_at", { ascending: false })
    .returns<ClothingSizeRow[]>();
  if (error) throw createHttpError(500, "Failed to load clothing measurements for reassessment");
  return data ?? [];
};

const loadSource = async (
  userId: string,
  clothingItemId: string
): Promise<FitReassessmentSource | null> => {
  const { data: targetItem, error: targetError } = await supabase
    .from("clothing_items")
    .select("*")
    .eq("user_id", userId)
    .eq("id", clothingItemId)
    .maybeSingle<ClothingItemRow>();
  if (targetError) throw createHttpError(500, "Failed to load clothing item for reassessment");
  if (!targetItem) return null;

  const { data: references, error: referenceError } = await supabase
    .from("reference_clothing")
    .select("*")
    .eq("user_id", userId)
    .eq("is_active", true)
    .in("category", [...getCompatibleCategories(targetItem.category)])
    .order("preference_score", { ascending: false })
    .returns<ReferenceClothingRow[]>();
  if (referenceError) throw createHttpError(500, "Failed to load references for reassessment");

  const referenceRows = references ?? [];
  const sizes = await loadSizes(userId, [
    clothingItemId,
    ...referenceRows.map((reference) => reference.clothing_item_id)
  ]);
  const sizesByItem = new Map<string, ClothingSizeRow>();
  for (const size of sizes) {
    if (!sizesByItem.has(size.clothing_item_id)) {
      sizesByItem.set(size.clothing_item_id, size);
    }
  }

  return {
    target: {
      item: targetItem,
      size: sizesByItem.get(clothingItemId) ?? null
    },
    references: referenceRows.map((reference) => ({
      reference,
      size: sizesByItem.get(reference.clothing_item_id) ?? null
    }))
  };
};

const record: FitReassessmentRepository["record"] = async (input) => {
  const { data, error } = await supabase.rpc("record_clothing_fit_assessment", {
    p_user_id: input.userId,
    p_clothing_item_id: input.clothingItemId,
    p_clothing_size_id: input.clothingSizeId,
    p_assessment: input.assessment
  });
  if (error) throw createHttpError(500, "Failed to persist clothing fit reassessment");
  return parseClothingFitAssessment(data);
};

export const supabaseFitReassessmentRepository: FitReassessmentRepository = {
  loadSource,
  record
};
