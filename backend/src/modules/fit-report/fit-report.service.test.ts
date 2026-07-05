import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import {
  configureReportTestEnv,
  FakeSupabaseQuery,
  fitResultId,
  forbiddenTokens,
  useAdversarialConsumedMetadataFitResult,
  useConflictingFeedbackFitResult,
  useEnrichedFitResult,
  useInsufficientFeedbackFitResult,
  usePartialConfidenceBreakdownFitResult,
  useLegacyFitResult,
  userId
} from "./fit-report.service.test-fixtures";

const main = async (): Promise<void> => {
  configureReportTestEnv();

  const [{ supabase }, reportBuilder, promptModule, reportService] = await Promise.all([
    import("../../config/supabase"),
    import("./fit-report.builder"),
    import("./fit-report.prompt"),
    import("./fit-report.service")
  ]);

  Object.defineProperty(supabase, "from", {
    value: (table: string): FakeSupabaseQuery => new FakeSupabaseQuery(table)
  });

  useLegacyFitResult();
  const legacyReportInput = await reportBuilder.buildFitReportInput(userId, fitResultId);
  assert.equal(legacyReportInput.recommendation.recommendedSize, "S");
  assert.equal(legacyReportInput.recommendation.scoreGapToSecond, 3);
  assert.equal(legacyReportInput.sizeScores.length, 2);
  assert.equal(legacyReportInput.explanation.missingMeasurementSummary.summary, "unavailable");

  useEnrichedFitResult();
  const reportInput = await reportBuilder.buildFitReportInput(userId, fitResultId);
  assert.deepEqual(reportInput.explanation.missingMeasurementSummary.missingMeasurementKeys, ["total_length"]);
  assert.equal(reportInput.explanation.dataQualitySummary.summary, "sparse");
  assert.equal(reportInput.explanation.feedbackReliability.summary, "unavailable");
  assert.equal(reportInput.explanation.feedbackReliability.status, "unavailable");
  assert.equal(reportInput.explanation.feedbackReliability.weightedSampleCount, 0);
  assert.equal(reportInput.explanation.topExplanationFactors[0]?.label, "가슴단면");
  assert.ok(reportInput.explanation.confidenceReasons.some((reason) => reason.code === "missing_measurements"));

  const prompt = promptModule.buildFitReportPrompt(reportInput);
  for (const token of forbiddenTokens) {
    assert.equal(prompt.includes(token), false, `${token} leaked into prompt`);
  }

  const fallback = reportService.buildFallbackFitReport(reportInput);
  assert.ok(fallback.recommendationReason.includes("누락된 측정값"));
  assert.ok(fallback.cautions.some((caution) => caution.includes("점수 차이가 작음")));

  const assertFeedbackNotApplied = async (
    status: "insufficient_signal" | "conflicting_feedback",
    expectedSampleCount: number
  ): Promise<void> => {
    const blockedReportInput = await reportBuilder.buildFitReportInput(userId, fitResultId);
    assert.equal(blockedReportInput.feedbackPersonalization.applied, false);
    assert.equal(blockedReportInput.feedbackPersonalization.sampleCount, expectedSampleCount);
    assert.equal(blockedReportInput.explanation.feedbackReliability.applied, false);
    assert.equal(blockedReportInput.explanation.feedbackReliability.status, status);

    const blockedFallback = reportService.buildFallbackFitReport(blockedReportInput);
    assert.equal(blockedFallback.fitDnaSummary.includes("반영된 피드백 보정은 없습니다."), true);
    assert.equal(blockedFallback.fitDnaSummary.includes("보정에 반영됐습니다"), false);
    assert.equal(blockedFallback.feedbackPersonalization.includes("적용되지 않았습니다"), true);
    assert.equal(blockedFallback.feedbackPersonalization.includes("reflected"), false);
    assert.equal(blockedFallback.feedbackPersonalization.includes("applied"), false);
  };

  useInsufficientFeedbackFitResult();
  await assertFeedbackNotApplied("insufficient_signal", 1);

  useConflictingFeedbackFitResult();
  await assertFeedbackNotApplied("conflicting_feedback", 6);

  usePartialConfidenceBreakdownFitResult();
  const partialMetadataReportInput = await reportBuilder.buildFitReportInput(userId, fitResultId);
  assert.equal(partialMetadataReportInput.feedbackPersonalization.applied, false);
  assert.equal(partialMetadataReportInput.feedbackPersonalization.sampleCount, 9);
  assert.equal(partialMetadataReportInput.explanation.feedbackReliability.applied, false);
  assert.equal(partialMetadataReportInput.explanation.feedbackReliability.status, "insufficient_signal");
  assert.equal(partialMetadataReportInput.explanation.feedbackReliability.weightedSampleCount, 9);

  useAdversarialConsumedMetadataFitResult();
  const adversarialReportInput = await reportBuilder.buildFitReportInput(userId, fitResultId);
  const adversarialPrompt = promptModule.buildFitReportPrompt(adversarialReportInput);
  const adversarialFallback = reportService.buildFallbackFitReport(adversarialReportInput);
  const adversarialArtifact = JSON.stringify({
    reportInput: adversarialReportInput,
    prompt: adversarialPrompt,
    fallback: adversarialFallback
  });
  for (const token of forbiddenTokens) {
    assert.equal(adversarialArtifact.includes(token), false, `${token} leaked through consumed metadata`);
  }
  assert.deepEqual(
    adversarialReportInput.explanation.confidenceReasons.map((reason) => reason.code),
    ["small_score_gap", "missing_measurements"]
  );
  assert.deepEqual(adversarialReportInput.explanation.topExplanationFactors, [
    {
      measurement: "chest_width",
      label: "가슴단면",
      diff: -3.2,
      weightedImpact: 1.28,
      status: "large_gap"
    }
  ]);
  assert.deepEqual(adversarialReportInput.explanation.missingMeasurementSummary.missingMeasurementKeys, [
    "total_length"
  ]);
  assert.equal(adversarialReportInput.recommendation.weightingStrategy, null);
  assert.deepEqual(adversarialReportInput.feedbackPersonalization.partFeedbackCounts, {
    chest_width: { too_small: 2, good: 1 }
  });
  assert.deepEqual(adversarialReportInput.sizeScores, [
    {
      sizeLabel: "M",
      fitScore: 69,
      fitLabel: "good_fit",
      weightedFitDistance: 1.4,
      recommendationConfidence: "high"
    },
    {
      sizeLabel: "프리",
      fitScore: 62,
      fitLabel: "acceptable",
      weightedFitDistance: 2.2,
      recommendationConfidence: "medium"
    }
  ]);

  useEnrichedFitResult();
  globalThis.fetch = async (): Promise<Response> =>
    new Response(JSON.stringify({ response: "not valid json" }), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    });

  const generated = await reportService.generateFitReport(userId, fitResultId, { includeDebug: true });
  assert.equal(generated.source, "fallback");
  assert.equal(generated.report.summary.includes("S"), true);
  assert.equal(generated.report.summary.includes("67"), true);
  assert.equal(generated.reportInput?.explanation.feedbackReliability.status, "unavailable");
  assert.equal(generated.reportInput?.explanation.feedbackReliability.weightedSampleCount, 0);

  const snapshotPath = resolve(process.cwd(), "../.omo/evidence/task-4-fit-score-engine-evolution.report.json");
  await mkdir(dirname(snapshotPath), { recursive: true });
  await writeFile(snapshotPath, `${JSON.stringify({
    source: generated.source,
    recommendedSize: generated.reportInput?.recommendation.recommendedSize,
    fitScore: generated.reportInput?.recommendation.fitScore,
    explanation: generated.reportInput?.explanation,
    fallbackReport: generated.report
  }, null, 2)}\n`);

  const promptSafetyPath = resolve(process.cwd(), "../.omo/evidence/task-4-fit-score-engine-evolution.prompt-safety.log");
  await writeFile(
    promptSafetyPath,
    `prompt safety passed\nforbidden raw/private token checks: ${forbiddenTokens.length}\nprompt length: ${prompt.length}\n`
  );

  console.log("fit-report tests passed");
};

main().catch((error: unknown) => {
  if (error instanceof Error) {
    console.error(error.message);
  }
  throw error;
});
