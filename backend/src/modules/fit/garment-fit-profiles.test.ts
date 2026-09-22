import assert from "node:assert/strict";
import test from "node:test";
import { GARMENT_PROFILE_VERSION, getGarmentFitProfile } from "./garment-fit-profiles";
import type { Category, MeasurementWeights } from "./fit.types";

const categories: readonly Category[] = [
  "tshirt", "shirt", "sweatshirt", "hoodie", "knit", "jacket",
  "coat", "pants", "jeans", "shorts", "skirt"
];

const weightTotal = (weights: MeasurementWeights): number =>
  Number(Object.values(weights).reduce((total, weight) => total + (weight ?? 0), 0).toFixed(4));

test("every supported category has a normalized garment profile", () => {
  for (const category of categories) {
    const profile = getGarmentFitProfile(category);
    assert.equal(profile.category, category);
    assert.equal(weightTotal(profile.weights), 1);
    assert.ok(profile.criticalMeasurements.length > 0);
    assert.ok(Object.keys(profile.directionalTolerances).length > 0);
  }
  assert.equal(GARMENT_PROFILE_VERSION, "garment_profiles_v2_0");
});

test("skirt profile is based on waist, hip, and total length", () => {
  const weights = getGarmentFitProfile("skirt").weights;
  assert.deepEqual(Object.keys(weights).sort(), ["hip_width", "total_length", "waist_width"]);
  assert.equal(weights.rise, undefined);
  assert.equal(weights.outseam, undefined);
});

test("category profiles assign visibly different priorities", () => {
  const tshirt = getGarmentFitProfile("tshirt").weights;
  const jacket = getGarmentFitProfile("jacket").weights;
  assert.notDeepEqual(tshirt, jacket);
  assert.ok((jacket.shoulder_width ?? 0) > (tshirt.shoulder_width ?? 0));
});
