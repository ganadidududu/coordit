import assert from "node:assert/strict";
import test from "node:test";
import {
  areCategoriesCompatible,
  getCompatibleCategories
} from "./category-compatibility";

test("all upper categories share the same reference pool", () => {
  // Given: references from exact upper categories that differ from the target.
  const upperReferences = ["shirt", "hoodie", "coat"] as const;

  // When: compatibility is evaluated for a T-shirt target.
  const compatibility = upperReferences.map((category) =>
    areCategoriesCompatible(category, "tshirt")
  );

  // Then: every upper reference can contribute to the calculation.
  assert.deepEqual(compatibility, [true, true, true]);
});

test("all lower categories share the same reference pool", () => {
  // Given: a pants target and every supported lower exact category.
  const lowerCategories = ["pants", "jeans", "shorts", "skirt"] as const;

  // When: compatible categories are resolved.
  const compatibleCategories = getCompatibleCategories("pants");

  // Then: the complete lower group is returned without upper categories.
  assert.deepEqual(compatibleCategories, lowerCategories);
});

test("upper and lower categories remain incompatible", () => {
  // Given: categories from opposite garment groups.
  // When: compatibility is evaluated.
  const isCompatible = areCategoriesCompatible("jacket", "jeans");

  // Then: cross-group references are rejected.
  assert.equal(isCompatible, false);
});
