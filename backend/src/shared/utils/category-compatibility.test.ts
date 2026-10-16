import assert from "node:assert/strict";
import test from "node:test";
import {
  areCategoriesCompatible,
  getCategoryCompatibility,
  getCompatibleCategories,
  selectReferenceCategoryTier
} from "./category-compatibility";

test("category compatibility distinguishes exact, related, and incompatible", () => {
  assert.equal(getCategoryCompatibility("tshirt", "tshirt"), "exact");
  assert.equal(getCategoryCompatibility("sweatshirt", "hoodie"), "related");
  assert.equal(getCategoryCompatibility("hoodie", "sweatshirt"), "related");
  assert.equal(getCategoryCompatibility("shirt", "tshirt"), "related");
  assert.equal(getCategoryCompatibility("tshirt", "shirt"), "related");
  assert.equal(getCategoryCompatibility("jacket", "coat"), "related");
  assert.equal(getCategoryCompatibility("pants", "jeans"), "related");
  assert.equal(getCategoryCompatibility("tshirt", "coat"), "incompatible");
  assert.equal(getCategoryCompatibility("skirt", "pants"), "incompatible");
});

test("exact references take priority and related references are the fallback", () => {
  const withExact = selectReferenceCategoryTier([
    { id: "related", category: "coat" },
    { id: "exact", category: "jacket" },
    { id: "bad", category: "tshirt" }
  ], "jacket");
  const relatedOnly = selectReferenceCategoryTier([
    { id: "related", category: "coat" },
    { id: "bad", category: "tshirt" }
  ], "jacket");
  assert.deepEqual(withExact, { level: "exact", usedIds: ["exact"], excludedIds: ["related", "bad"] });
  assert.deepEqual(relatedOnly, { level: "related", usedIds: ["related"], excludedIds: ["bad"] });
});

test("compatible category list contains exact and related categories only", () => {
  assert.deepEqual(getCompatibleCategories("coat"), ["coat", "jacket"]);
  assert.equal(areCategoriesCompatible("jacket", "coat"), true);
  assert.equal(areCategoriesCompatible("tshirt", "coat"), false);
});
