import { pickMeasurements } from "../../shared/utils/measurements";
import { asOptionalRecord, asOptionalString } from "../../shared/utils/request";
import {
  insertClothingSize,
  patchClothingSize,
  removeClothingSize,
  selectClothingSizes,
  type ClothingSizeDto
} from "./clothing-sizes.repository";

const toDto = (body: Record<string, unknown>): ClothingSizeDto => ({
  size_label: asOptionalString(body.sizeLabel ?? body.size_label),
  raw_measurements: asOptionalRecord(body.rawMeasurements ?? body.raw_measurements),
  ...pickMeasurements(body)
});

export const createClothingSizeForUser = (
  userId: string,
  clothingItemId: string,
  body: Record<string, unknown>
) => insertClothingSize(userId, clothingItemId, toDto(body));

export const listClothingSizesForUser = (userId: string, clothingItemId: string) =>
  selectClothingSizes(userId, clothingItemId);

export const updateClothingSizeForUser = (
  userId: string,
  id: string,
  body: Record<string, unknown>
) => patchClothingSize(userId, id, toDto(body));

export const deleteClothingSizeForUser = (userId: string, id: string) =>
  removeClothingSize(userId, id);
