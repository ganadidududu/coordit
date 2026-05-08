import { supabase } from "../../config/supabase";
import type { ClothingItemRow } from "../../shared/types/database";
import { createHttpError } from "../../shared/utils/http-error";
import type { CreateClothingItemDto, UpdateClothingItemDto } from "./clothing-items.types";

export const insertClothingItem = async (
  userId: string,
  dto: CreateClothingItemDto
): Promise<ClothingItemRow> => {
  const { data, error } = await supabase
    .from("clothing_items")
    .insert({ ...dto, user_id: userId })
    .select("*")
    .single<ClothingItemRow>();
  if (error || !data) throw createHttpError(500, "Failed to create clothing item");
  return data;
};

export const selectClothingItems = async (userId: string): Promise<ClothingItemRow[]> => {
  const { data, error } = await supabase
    .from("clothing_items")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .returns<ClothingItemRow[]>();
  if (error) throw createHttpError(500, "Failed to load clothing items");
  return data ?? [];
};

export const selectClothingItemById = async (
  userId: string,
  id: string
): Promise<ClothingItemRow> => {
  const { data, error } = await supabase
    .from("clothing_items")
    .select("*")
    .eq("user_id", userId)
    .eq("id", id)
    .single<ClothingItemRow>();
  if (error || !data) throw createHttpError(404, "Clothing item was not found");
  return data;
};

export const patchClothingItem = async (
  userId: string,
  id: string,
  dto: UpdateClothingItemDto
): Promise<ClothingItemRow> => {
  const { data, error } = await supabase
    .from("clothing_items")
    .update({ ...dto, updated_at: new Date().toISOString() })
    .eq("user_id", userId)
    .eq("id", id)
    .select("*")
    .single<ClothingItemRow>();
  if (error || !data) throw createHttpError(500, "Failed to update clothing item");
  return data;
};

export const removeClothingItem = async (userId: string, id: string): Promise<void> => {
  const { error } = await supabase
    .from("clothing_items")
    .delete()
    .eq("user_id", userId)
    .eq("id", id);
  if (error) throw createHttpError(500, "Failed to delete clothing item");
};
