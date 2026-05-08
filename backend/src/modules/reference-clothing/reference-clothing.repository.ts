import { supabase } from "../../config/supabase";
import type { Category, FitType, ReferenceClothingRow } from "../../shared/types/database";
import { createHttpError } from "../../shared/utils/http-error";

export interface ReferenceClothingDto {
  clothing_item_id: string;
  nickname: string | null;
  category: Category;
  fit_type: FitType;
  preference_score: number;
  is_active: boolean;
  notes: string | null;
}

export const insertReferenceClothing = async (
  userId: string,
  dto: ReferenceClothingDto
): Promise<ReferenceClothingRow> => {
  const { data, error } = await supabase
    .from("reference_clothing")
    .upsert({ ...dto, user_id: userId }, { onConflict: "user_id,clothing_item_id" })
    .select("*")
    .single<ReferenceClothingRow>();
  if (error || !data) throw createHttpError(500, "Failed to save reference clothing");
  return data;
};

export const selectReferenceClothing = async (userId: string): Promise<ReferenceClothingRow[]> => {
  const { data, error } = await supabase
    .from("reference_clothing")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .returns<ReferenceClothingRow[]>();
  if (error) throw createHttpError(500, "Failed to load reference clothing");
  return data ?? [];
};

export const selectReferenceClothingByCategory = async (
  userId: string,
  category: Category
): Promise<ReferenceClothingRow[]> => {
  const { data, error } = await supabase
    .from("reference_clothing")
    .select("*")
    .eq("user_id", userId)
    .eq("category", category)
    .eq("is_active", true)
    .order("preference_score", { ascending: false })
    .returns<ReferenceClothingRow[]>();
  if (error) throw createHttpError(500, "Failed to load reference clothing by category");
  return data ?? [];
};

export const selectReferenceClothingById = async (
  userId: string,
  id: string
): Promise<ReferenceClothingRow> => {
  const { data, error } = await supabase
    .from("reference_clothing")
    .select("*")
    .eq("user_id", userId)
    .eq("id", id)
    .single<ReferenceClothingRow>();
  if (error || !data) throw createHttpError(404, "Reference clothing was not found");
  return data;
};

export const patchReferenceClothing = async (
  userId: string,
  id: string,
  dto: Partial<ReferenceClothingDto>
): Promise<ReferenceClothingRow> => {
  const { data, error } = await supabase
    .from("reference_clothing")
    .update({ ...dto, updated_at: new Date().toISOString() })
    .eq("user_id", userId)
    .eq("id", id)
    .select("*")
    .single<ReferenceClothingRow>();
  if (error || !data) throw createHttpError(500, "Failed to update reference clothing");
  return data;
};
