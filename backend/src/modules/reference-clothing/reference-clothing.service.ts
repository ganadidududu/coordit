import type { Category } from "../../shared/types/database";
import { asOptionalNumber, asOptionalString, asRequiredString } from "../../shared/utils/request";
import {
  insertReferenceClothing,
  patchReferenceClothing,
  selectReferenceClothing,
  selectReferenceClothingByCategory,
  selectReferenceClothingById,
  type ReferenceClothingDto
} from "./reference-clothing.repository";

const toDto = (body: Record<string, unknown>): ReferenceClothingDto => ({
  clothing_item_id: asRequiredString(body.clothingItemId ?? body.clothing_item_id, "clothingItemId"),
  nickname: asOptionalString(body.nickname),
  category: asRequiredString(body.category, "category") as ReferenceClothingDto["category"],
  fit_type: (asOptionalString(body.fitType ?? body.fit_type) ?? "regular") as ReferenceClothingDto["fit_type"],
  preference_score: asOptionalNumber(body.preferenceScore ?? body.preference_score) ?? 100,
  is_active: body.isActive ?? body.is_active ?? true ? true : false,
  notes: asOptionalString(body.notes)
});

export const createReferenceClothingForUser = (userId: string, body: Record<string, unknown>) =>
  insertReferenceClothing(userId, toDto(body));

export const listReferenceClothingForUser = (userId: string) => selectReferenceClothing(userId);

export const listReferenceClothingByCategoryForUser = (userId: string, category: Category) =>
  selectReferenceClothingByCategory(userId, category);

export const getReferenceClothingForUser = (userId: string, id: string) =>
  selectReferenceClothingById(userId, id);

export const updateReferenceClothingForUser = (
  userId: string,
  id: string,
  body: Record<string, unknown>
) => patchReferenceClothing(userId, id, toDto(body));

export const deactivateReferenceClothingForUser = (userId: string, id: string) =>
  patchReferenceClothing(userId, id, { is_active: false });
