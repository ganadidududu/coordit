import type { Category } from "../types/database";

const UPPER_CATEGORIES = [
  "tshirt",
  "shirt",
  "sweatshirt",
  "hoodie",
  "knit",
  "jacket",
  "coat"
] as const satisfies readonly Category[];

const LOWER_CATEGORIES = [
  "pants",
  "jeans",
  "shorts",
  "skirt"
] as const satisfies readonly Category[];

export const getCompatibleCategories = (category: Category): readonly Category[] =>
  UPPER_CATEGORIES.some((candidate) => candidate === category)
    ? UPPER_CATEGORIES
    : LOWER_CATEGORIES;

export const areCategoriesCompatible = (
  referenceCategory: Category,
  targetCategory: Category
): boolean => {
  return getCompatibleCategories(targetCategory).some(
    (category) => category === referenceCategory
  );
};

export const getCategoryCompatibilityReason = (
  referenceCategory: Category,
  targetCategory: Category
): string => {
  if (areCategoriesCompatible(referenceCategory, targetCategory)) {
    return `${referenceCategory} can be compared with ${targetCategory}`;
  }
  return `${referenceCategory} cannot be used as a fit reference for ${targetCategory}`;
};
