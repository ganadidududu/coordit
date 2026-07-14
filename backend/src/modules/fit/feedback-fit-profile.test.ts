import assert from "node:assert/strict";
import { buildFeedbackFitProfileFromRows } from "./feedback-fit-profile";
import type { Category, FeedbackFitProfile, PartFeedbackMap } from "./fit.types";

const now = new Date("2026-07-02T00:00:00.000Z");

type FeedbackFixtureRow = {
  readonly fitAnalysisResultId: string;
  readonly actualFitLabel: string | null;
  readonly partFeedback?: PartFeedbackMap;
  readonly createdAt: string;
  readonly recommendationLog?: {
    readonly eventType: string;
    readonly clickedAt: string | null;
    readonly purchasedAt: string | null;
  };
};

const row = (
  index: number,
  actualFitLabel: string | null,
  createdAt: string,
  partFeedback?: PartFeedbackMap,
  recommendationLog?: FeedbackFixtureRow["recommendationLog"]
): FeedbackFixtureRow => ({
  fitAnalysisResultId: `fit-${index}`,
  actualFitLabel,
  partFeedback,
  createdAt,
  recommendationLog
});

const buildProfile = (
  category: Category,
  rows: readonly FeedbackFixtureRow[]
): FeedbackFitProfile | undefined => buildFeedbackFitProfileFromRows(category, rows, now);

const assertNoAppliedAdjustment = (profile: FeedbackFitProfile | undefined): void => {
  assert.ok(profile);
  assert.equal(profile.reliability?.applied, false);
  assert.deepEqual(profile.measurementOffsets, {});
  assert.deepEqual(profile.weightMultipliers, {});
};

const noisyProfile = buildProfile("pants", [
  row(1, "too_small", "2026-07-01T00:00:00.000Z", { waist_width: "too_small" })
]);
assertNoAppliedAdjustment(noisyProfile);
assert.equal(noisyProfile?.sampleCount, 1);
assert.equal(noisyProfile?.reliability?.status, "insufficient_signal");

const recentConsistentRows = Array.from({ length: 5 }, (_, index) =>
  row(
    index + 1,
    "too_small",
    "2026-07-01T00:00:00.000Z",
    index < 3 ? { waist_width: "too_small" } : undefined
  )
);
const consistentProfile = buildProfile("pants", recentConsistentRows);
assert.ok(consistentProfile);
assert.equal(consistentProfile.reliability?.applied, true);
assert.equal(consistentProfile.reliability?.status, "applied");
assert.ok((consistentProfile.measurementOffsets.waist_width ?? 0) > 0);
assert.ok((consistentProfile.measurementOffsets.waist_width ?? 0) <= 2);
assert.ok((consistentProfile.weightMultipliers.waist_width ?? 0) > 1);
assert.equal(consistentProfile.reliability?.partUsableRows.waist_width, 3);

const oldRows = Array.from({ length: 5 }, (_, index) =>
  row(index + 1, "too_small", "2024-07-02T00:00:00.000Z")
);
const oldProfile = buildProfile("pants", oldRows);
assert.ok(oldProfile);
assert.ok((oldProfile.reliability?.weightedSampleCount ?? 0) < (consistentProfile.reliability?.weightedSampleCount ?? 0));

const belowPartThresholdProfile = buildProfile("pants", [
  row(1, "too_small", "2026-07-01T00:00:00.000Z", { waist_width: "too_small" }),
  row(2, "too_small", "2026-07-01T00:00:00.000Z", { waist_width: "too_small" }),
  row(3, "too_small", "2026-07-01T00:00:00.000Z"),
  row(4, "too_small", "2026-07-01T00:00:00.000Z"),
  row(5, "too_small", "2026-07-01T00:00:00.000Z")
]);
assert.ok(belowPartThresholdProfile);
assert.equal(belowPartThresholdProfile.weightMultipliers.waist_width, undefined);

const corroboratedProfile = buildProfile("pants", [
  row(1, "too_small", "2026-07-01T00:00:00.000Z", undefined, {
    eventType: "purchased",
    clickedAt: null,
    purchasedAt: "2026-07-01T12:00:00.000Z"
  }),
  ...Array.from({ length: 4 }, (_, index) =>
    row(index + 2, "too_small", "2026-07-01T00:00:00.000Z")
  )
]);
assert.ok(corroboratedProfile);
assert.ok((corroboratedProfile.reliability?.weightedSampleCount ?? 0) > (consistentProfile.reliability?.weightedSampleCount ?? 0));
assert.equal(corroboratedProfile.reliability?.corroboratedRows, 1);

const conflictingProfile = buildProfile("pants", [
  row(1, "too_small", "2026-07-01T00:00:00.000Z"),
  row(2, "too_small", "2026-07-01T00:00:00.000Z"),
  row(3, "too_small", "2026-07-01T00:00:00.000Z"),
  row(4, "too_large", "2026-07-01T00:00:00.000Z"),
  row(5, "too_large", "2026-07-01T00:00:00.000Z")
]);
assertNoAppliedAdjustment(conflictingProfile);
assert.equal(conflictingProfile?.reliability?.status, "conflicting_feedback");
assert.ok(Math.abs(conflictingProfile?.measurementOffsets.waist_width ?? 0) <= 0.5);

const partConflictingProfile = buildProfile("pants", [
  row(1, null, "2026-07-01T00:00:00.000Z", { waist_width: "too_small" }),
  row(2, null, "2026-07-01T00:00:00.000Z", { waist_width: "too_small" }),
  row(3, null, "2026-07-01T00:00:00.000Z", { waist_width: "too_small" }),
  row(4, null, "2026-07-01T00:00:00.000Z", { waist_width: "too_large" }),
  row(5, null, "2026-07-01T00:00:00.000Z", { waist_width: "too_large" })
]);
assertNoAppliedAdjustment(partConflictingProfile);
assert.equal(partConflictingProfile?.reliability?.status, "conflicting_feedback");
assert.equal(partConflictingProfile?.reliability?.partUsableRows.waist_width, 5);
assert.ok(Math.abs(partConflictingProfile?.measurementOffsets.waist_width ?? 0) <= 0.5);

const independentPartSignalsProfile = buildProfile("pants", [
  row(1, null, "2026-07-01T00:00:00.000Z", { waist_width: "too_small" }),
  row(2, null, "2026-07-01T00:00:00.000Z", { waist_width: "too_small" }),
  row(3, null, "2026-07-01T00:00:00.000Z", { waist_width: "too_small" }),
  row(4, null, "2026-07-01T00:00:00.000Z", { outseam: "too_large" }),
  row(5, null, "2026-07-01T00:00:00.000Z", { outseam: "too_large" }),
  row(6, null, "2026-07-01T00:00:00.000Z", { outseam: "too_large" })
]);
assert.ok(independentPartSignalsProfile);
assert.equal(independentPartSignalsProfile.reliability?.status, "applied");
assert.equal(independentPartSignalsProfile.reliability?.applied, true);
assert.ok((independentPartSignalsProfile.measurementOffsets.waist_width ?? 0) > 0);
assert.ok((independentPartSignalsProfile.measurementOffsets.outseam ?? 0) < 0);
assert.ok((independentPartSignalsProfile.weightMultipliers.waist_width ?? 0) > 1);
assert.ok((independentPartSignalsProfile.weightMultipliers.outseam ?? 0) > 1);
assert.equal(independentPartSignalsProfile.reliability?.partUsableRows.waist_width, 3);
assert.equal(independentPartSignalsProfile.reliability?.partUsableRows.outseam, 3);

console.log("feedback-fit-profile tests passed");
