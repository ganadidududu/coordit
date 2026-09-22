import type { Category } from "../types/database";
import type { CategoryCompatibility } from "../../modules/fit/fit.types";

const RELATED_CATEGORIES: Readonly<Record<Category, readonly Category[]>> = {
  tshirt: ["shirt", "sweatshirt", "knit"],
  shirt: ["tshirt", "knit"],
  sweatshirt: ["tshirt", "hoodie", "knit"],
  hoodie: ["sweatshirt", "knit"],
  knit: ["tshirt", "shirt", "sweatshirt", "hoodie"],
  jacket: ["coat"],
  coat: ["jacket"],
  pants: ["jeans", "shorts"],
  jeans: ["pants", "shorts"],
  shorts: ["pants", "jeans"],
  skirt: []
};

export const getCategoryCompatibility = (
  referenceCategory: Category,
  targetCategory: Category
): CategoryCompatibility => {
  if (referenceCategory === targetCategory) return "exact";
  return RELATED_CATEGORIES[targetCategory].some((category) => category === referenceCategory)
    ? "related"
    : "incompatible";
};

export const getCompatibleCategories = (category: Category): readonly Category[] =>
  [category, ...RELATED_CATEGORIES[category]];

export const areCategoriesCompatible = (
  referenceCategory: Category,
  targetCategory: Category
): boolean => {
  return getCategoryCompatibility(referenceCategory, targetCategory) !== "incompatible";
};

export const getCategoryCompatibilityReason = (
  referenceCategory: Category,
  targetCategory: Category
): string => {
  const compatibility = getCategoryCompatibility(referenceCategory, targetCategory);
  return `${referenceCategory} is ${compatibility} for ${targetCategory}`;
};

export const selectReferenceCategoryTier = (
  references: readonly { readonly id: string; readonly category: Category }[],
  targetCategory: Category
): {
  readonly level: "exact" | "related" | null;
  readonly usedIds: readonly string[];
  readonly excludedIds: readonly string[];
} => {
  const exactIds = references
    .filter((reference) => getCategoryCompatibility(reference.category, targetCategory) === "exact")
    .map((reference) => reference.id);
  const relatedIds = references
    .filter((reference) => getCategoryCompatibility(reference.category, targetCategory) === "related")
    .map((reference) => reference.id);
  const usedIds = exactIds.length > 0 ? exactIds : relatedIds;
  return {
    level: exactIds.length > 0 ? "exact" : relatedIds.length > 0 ? "related" : null,
    usedIds,
    excludedIds: references.filter((reference) => !usedIds.includes(reference.id)).map((reference) => reference.id)
  };
};
