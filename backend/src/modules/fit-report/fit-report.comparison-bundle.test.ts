import assert from "node:assert/strict";
import type { FitAnalysisResultRow } from "../../shared/types/database";
import { configureReportTestEnv } from "./fit-report.service.test-fixtures";

const main = async (): Promise<void> => {
  configureReportTestEnv();
  const { assertSameComparisonBundle } = await import("./fit-report.comparison-bundle");
  const original: FitAnalysisResultRow = {
    id: "original", user_id: "owner", reference_clothing_id: "reference", external_product_id: "product",
    recommended_external_product_size_id: "size-m", recommended_size_label: "M", fit_score: 90,
    fit_label: "good_fit", fit_comment: "", weighted_fit_distance: 1, algorithm_version: "v4",
    recommendation_confidence: "medium", result_details: { referenceClothingIds: ["reference"] }, created_at: "2026-10-26"
  };
  assert.doesNotThrow(() => assertSameComparisonBundle("owner", original, { ...original, id: "remeasured", fit_score: 95 }));
  assert.throws(() => assertSameComparisonBundle("intruder", original, original));
  assert.throws(() => assertSameComparisonBundle("owner", original, { ...original, external_product_id: "another-product" }));
  assert.throws(() => assertSameComparisonBundle("owner", original, { ...original, reference_clothing_id: "another-reference", result_details: {} }));
  assert.throws(() => assertSameComparisonBundle("owner", original, { ...original, result_details: { referenceClothingIds: ["reference", "added-reference"] } }));
  const multiple = { ...original, result_details: { referenceClothingIds: ["one", "two"] } };
  assert.doesNotThrow(() => assertSameComparisonBundle("owner", multiple, { ...multiple, result_details: { referenceClothingIds: ["two", "one"] } }));
};

main().then(() => console.log("PASS comparison bundle rejects cross-user, cross-product and changed references"), (error: unknown) => {
  console.error(error instanceof Error ? error.message : "Comparison bundle test failed");
  process.exitCode = 1;
});
