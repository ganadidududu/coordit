import type { Category } from "../types/database";

const compatibleGroups: Category[][] = [
  ["hoodie", "sweatshirt"],
  ["pants", "jeans"],
  ["shirt", "tshirt", "knit"],
  ["jacket", "coat"],
  ["shorts", "skirt"]
];

export const areCategoriesCompatible = (
  referenceCategory: Category,
  targetCategory: Category
): boolean => {
  if (referenceCategory === targetCategory) return true;
  return compatibleGroups.some(
    (group) => group.includes(referenceCategory) && group.includes(targetCategory)
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
