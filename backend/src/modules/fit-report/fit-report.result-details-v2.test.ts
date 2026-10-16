import assert from "node:assert/strict";
import test from "node:test";
import { readStoredFitReport } from "./fit-report.artifact";
import { parseResultDetails } from "./fit-report.result-details.sanitizer";

test("V2 result details preserve deterministic report facts", () => {
  const details = parseResultDetails({
    measurementSubscores: { chest_width: 72, SECRET: 100 },
    semanticSubscores: { silhouette: 82, layering: 76, SECRET: 100 },
    semanticFacts: [{
      measurement: "chest_width", reference: 57, product: 54, diff: -3,
      normalizedDiff: 1.2, direction: "smaller", severity: "moderate",
      importance: "critical", semanticEffects: ["layering_room_reduced", "SECRET_PRIVATE_REASON"]
    }, { measurement: "SECRET", reference: 1, product: 2 }],
    interactions: [{
      id: "outerwear_volume_balance", severity: "moderate", direction: "mixed",
      involvedMeasurements: ["chest_width", "sleeve_length", "SECRET"],
      semanticEffects: ["layering_volume_balance_changed", "SECRET_PRIVATE_REASON"], scorePenalty: .5
    }],
    sizeTradeoff: {
      recommended: "M", alternative: "L",
      tradeoffs: [{ measurement: "chest_width", recommendedDiff: -3, alternativeDiff: 1, preferred: "alternative" }]
    },
    versions: {
      fitEngineVersion: "fit_engine_v2_0",
      garmentProfileVersion: "garment_profiles_v2_0",
      semanticRulesVersion: "fit_semantics_v2_0",
      fitReportPromptVersion: "fit_report_v7"
    }
  });

  assert.deepEqual(details.measurementSubscores, { chest_width: 72 });
  assert.deepEqual(details.semanticSubscores, { silhouette: 82, layering: 76 });
  assert.equal(details.semanticFacts?.length, 1);
  assert.deepEqual(details.semanticFacts?.[0]?.semanticEffects, ["layering_room_reduced"]);
  assert.deepEqual(details.interactions?.[0]?.involvedMeasurements, ["chest_width", "sleeve_length"]);
  assert.deepEqual(details.interactions?.[0]?.semanticEffects, ["layering_volume_balance_changed"]);
  assert.equal(details.sizeTradeoff?.alternative, "L");
  assert.equal(details.versions?.fitReportPromptVersion, "fit_report_v7");
});

test("legacy result details remain readable without V2 metadata", () => {
  const details = parseResultDetails({
    referenceProfile: { measurements: { chest_width: 57 }, tolerances: { chest_width: 1.5 } },
    dynamicWeights: { chest_width: 1 },
    weightingStrategy: "reference_profile_v1"
  });
  assert.deepEqual(details.referenceProfile?.measurements, { chest_width: 57 });
  assert.equal(details.semanticFacts, undefined);
  assert.equal(details.sizeTradeoff, undefined);
});

test("a stored V6 report remains readable without V7 narrative fields", () => {
  const stored = readStoredFitReport({
    storedFitReport: {
      schemaVersion: 1,
      source: "fallback",
      modelName: "legacy",
      promptVersion: "fit_report_v6",
      report: {
        title: "기존 리포트",
        summary: "기존 요약",
        recommendationReason: "기존 추천 이유",
        measurementAnalysis: [],
        cautions: [],
        nextActions: []
      },
      chartData: { idealVsProduct: [], differenceBar: [], sizeScoreRanking: [], feedbackAdjustment: [] }
    }
  });
  assert.equal(stored?.promptVersion, "fit_report_v6");
  assert.equal(stored?.report.garmentFitContext, undefined);
  assert.deepEqual(stored?.chartData.fitPointScores, []);
  assert.deepEqual(stored?.chartData.measurementScores, []);
});
