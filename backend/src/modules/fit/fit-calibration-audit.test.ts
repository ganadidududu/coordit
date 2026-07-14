import assert from "node:assert/strict";
import { auditFitCalibrationSignals } from "./fit-calibration-audit";

const main = (): void => {
  {
    // Given: a category with enough reliable feedback plus malformed legacy payloads.
    const audit = auditFitCalibrationSignals({
      feedbackRows: [
        {
          category: "shirt",
          actualFitLabel: "good_fit",
          purchasedSizeLabel: "M",
          partFeedback: { chest_width: "slightly_small", total_length: "good_fit" }
        },
        { category: "shirt", actualFitLabel: "too_small", purchasedSizeLabel: "M", partFeedback: ["bad"] },
        { category: "shirt", actualFitLabel: "slightly_large", purchasedSizeLabel: null, partFeedback: "bad" },
        { category: "shirt", actualFitLabel: "acceptable", purchasedSizeLabel: "L", partFeedback: { sleeve_length: "too_large" } },
        { category: "shirt", actualFitLabel: "large", purchasedSizeLabel: "L", partFeedback: { unknown: "too_small" } },
        { category: "pants", actualFitLabel: "good_fit", purchasedSizeLabel: null, partFeedback: { waist_width: "good_fit" } }
      ],
      recommendationLogs: [
        { eventType: "shown", clickedAt: null, purchasedAt: null },
        { eventType: "clicked", clickedAt: "2026-07-01T00:00:00.000Z", purchasedAt: null },
        { eventType: "purchased", clickedAt: "2026-07-01T00:00:00.000Z", purchasedAt: "2026-07-01T01:00:00.000Z" },
        { eventType: "legacy" }
      ],
      externalSizeRows: [
        { measurementSource: "manual", parsingStatus: "manual", extractionConfidence: null },
        { measurementSource: "ocr", parsingStatus: "accepted", extractionConfidence: 0.92 },
        { measurementSource: "ocr", parsingStatus: "pending", extractionConfidence: 0.42 },
        { measurementSource: null, parsingStatus: null, extractionConfidence: null }
      ],
      fitResultRows: [
        { resultDetails: { allSizeScores: [], diffs: {}, referenceProfile: { measurements: {} } } },
        { resultDetails: { diff: {}, chartData: [] } },
        { resultDetails: { unexpected: true } },
        { resultDetails: "bad" }
      ]
    });

    // When: the audit summarizes the fixture.
    const shirtSummary = audit.categories.shirt;

    // Then: reliable category counts and legacy/malformed shapes are observable.
    assert.equal(shirtSummary.feedbackRows, 5);
    assert.equal(shirtSummary.reliableFeedbackRows, 5);
    assert.equal(shirtSummary.calibrationReady, true);
    assert.equal(shirtSummary.reason, "ready");
    assert.equal(shirtSummary.purchasedSize.presentRows, 4);
    assert.equal(shirtSummary.partFeedback.totalParts, 3);
    assert.equal(audit.recommendationLogs.clickedAt.presentRows, 2);
    assert.equal(audit.recommendationLogs.purchasedAt.fieldPresentRows, 3);
    assert.equal(audit.externalSizes.measurementSource.ocr, 2);
    assert.equal(audit.externalSizes.extractionConfidence.low, 1);
    assert.equal(audit.resultDetailsShapes.current_fit_engine_v1, 1);
    assert.equal(audit.resultDetailsShapes.legacy_chart_diff, 1);
    assert.equal(audit.resultDetailsShapes.unknown_object, 1);
    assert.equal(audit.resultDetailsShapes.malformed, 1);

    console.log(JSON.stringify({
      categories: audit.categories,
      recommendationLogs: audit.recommendationLogs,
      externalSizes: audit.externalSizes,
      resultDetailsShapes: audit.resultDetailsShapes
    }, null, 2));
  }

  {
    // Given: no feedback rows.
    const audit = auditFitCalibrationSignals({
      feedbackRows: [],
      recommendationLogs: [],
      externalSizeRows: [],
      fitResultRows: []
    });

    // When: the zero-row category is absent from observed categories.
    const summary = audit.overall;

    // Then: calibration is blocked for insufficient feedback.
    assert.equal(summary.calibrationReady, false);
    assert.equal(summary.reason, "insufficient_feedback");
    assert.equal(summary.reliableFeedbackRows, 0);
  }

  console.log("fit-calibration-audit tests passed");
};

main();
