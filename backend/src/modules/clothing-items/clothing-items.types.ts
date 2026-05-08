import type { Category, FitType, JsonObject } from "../../shared/types/database";

export interface CreateClothingItemDto {
  name: string;
  brand: string | null;
  category: Category;
  fit_type: FitType;
  size_label: string | null;
  notes: string | null;
  image_url: string | null;
  raw_product_data: JsonObject;
}

export type UpdateClothingItemDto = Partial<CreateClothingItemDto>;
