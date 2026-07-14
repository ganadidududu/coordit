import assert from "node:assert/strict";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { ConfidenceExplanationText } from "./confidence-display";
import type { ConfidenceDisplayResult } from "./confidence-display";

const legacyResult: ConfidenceDisplayResult = {
  recommendation_confidence: "medium"
};

const legacyMarkup = renderToStaticMarkup(createElement(ConfidenceExplanationText, { result: legacyResult }));
assert.match(legacyMarkup, /신뢰도 medium/);
assert.doesNotMatch(legacyMarkup, /상품 실측 추출 신뢰도가 낮습니다/);

const enrichedResult: ConfidenceDisplayResult = {
  recommendation_confidence: "medium",
  result_details: {
    scoreExplanation: {
      reasonCodes: ["small_score_gap"]
    },
    confidenceBreakdown: {
      label: "medium",
      reasonCodes: ["small_score_gap", "low_measurement_extraction_confidence"],
      dataQuality: {
        summary: "sparse",
        missingMeasurementKeys: [],
        productMeasurementQuality: {
          trusted: false,
          reasonCodes: ["low_measurement_extraction_confidence"]
        }
      }
    }
  }
};

const enrichedMarkup = renderToStaticMarkup(createElement(ConfidenceExplanationText, { result: enrichedResult }));
assert.match(enrichedMarkup, /신뢰도 medium/);
assert.match(enrichedMarkup, /후보 사이즈 간 점수 차이가 작습니다/);
assert.match(enrichedMarkup, /상품 실측 추출 신뢰도가 낮습니다/);

console.log("confidence-display smoke passed");
