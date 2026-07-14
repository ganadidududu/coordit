import type {
  Category,
  FeedbackFitProfile,
  MeasurementDiffs,
  MeasurementKey,
  MeasurementWeights
} from "./fit.types";
import type { DirectionWeights, FeedbackAccumulator, FeedbackProfileSourceRow } from "./feedback-fit-profile.types";
import {
  CATEGORY_MIN_USABLE_ROWS,
  CONFLICTING_DIRECTION_RATIO,
  ISSUE_WEIGHT_STEP,
  MAX_OFFSET_CM,
  MAX_WEIGHT_MULTIPLIER,
  MEASUREMENT_OFFSET_SCALE,
  PART_MIN_USABLE_ROWS,
  clamp,
  getCategoryMeasurementKeys,
  getFeedbackDirection,
  getRowWeight,
  hasUsableFeedback,
  normalizeFeedbackLabel,
  normalizePartFeedback,
  round
} from "./feedback-fit-profile.signals";

const createAccumulator = (): FeedbackAccumulator => ({
  offsetTotals: {},
  offsetWeights: {},
  partOffsetTotals: {},
  partOffsetWeights: {},
  issueCounts: {},
  partFeedbackCounts: {},
  partUsableRows: {}
});

const addOffsetSignal = (
  totals: MeasurementDiffs,
  weights: Partial<Record<MeasurementKey, number>>,
  key: MeasurementKey,
  direction: number,
  rowWeight: number
): void => {
  totals[key] = (totals[key] ?? 0) + direction * MEASUREMENT_OFFSET_SCALE[key] * rowWeight;
  weights[key] = (weights[key] ?? 0) + rowWeight;
};

const addDirectionWeight = (weights: DirectionWeights, direction: number, rowWeight: number): DirectionWeights => ({
  positive: weights.positive + (direction > 0 ? direction * rowWeight : 0),
  negative: weights.negative + (direction < 0 ? Math.abs(direction) * rowWeight : 0)
});

const getHasConflictingFeedback = ({ positive, negative }: DirectionWeights): boolean => {
  if (positive === 0 || negative === 0) return false;
  return Math.min(positive, negative) / Math.max(positive, negative) >= CONFLICTING_DIRECTION_RATIO;
};

const buildOffsets = (
  measurementKeys: readonly MeasurementKey[],
  accumulator: FeedbackAccumulator
): MeasurementDiffs =>
  measurementKeys.reduce<MeasurementDiffs>((offsets, key) => {
    const categoryWeight = accumulator.offsetWeights[key] ?? 0;
    const partWeight = accumulator.partOffsetWeights[key] ?? 0;
    const categoryOffset = categoryWeight > 0 ? (accumulator.offsetTotals[key] ?? 0) / categoryWeight : 0;
    const partOffset = (accumulator.partUsableRows[key] ?? 0) >= PART_MIN_USABLE_ROWS && partWeight > 0
      ? (accumulator.partOffsetTotals[key] ?? 0) / partWeight
      : 0;
    const offset = categoryOffset + partOffset;
    if (offset !== 0) offsets[key] = round(clamp(offset, -MAX_OFFSET_CM, MAX_OFFSET_CM));
    return offsets;
  }, {});

const buildWeightMultipliers = (
  measurementKeys: readonly MeasurementKey[],
  accumulator: FeedbackAccumulator
): MeasurementWeights =>
  measurementKeys.reduce<MeasurementWeights>((multipliers, key) => {
    const partRows = accumulator.partUsableRows[key] ?? 0;
    const issueCount = accumulator.issueCounts[key] ?? 0;
    if (partRows >= PART_MIN_USABLE_ROWS && issueCount > 0) {
      multipliers[key] = round(clamp(1 + issueCount * ISSUE_WEIGHT_STEP, 1, MAX_WEIGHT_MULTIPLIER));
    }
    return multipliers;
  }, {});

export const buildFeedbackFitProfileFromRows = (
  category: Category,
  rows: readonly FeedbackProfileSourceRow[],
  now = new Date()
): FeedbackFitProfile | undefined => {
  const measurementKeys = getCategoryMeasurementKeys(category);
  const usableRows = rows.filter(hasUsableFeedback);
  if (usableRows.length === 0) return undefined;

  const accumulator = createAccumulator();
  let overallSampleCount = 0;
  let partSampleCount = 0;
  let weightedSampleCount = 0;
  let corroboratedRows = 0;
  let overallDirectionWeights: DirectionWeights = { positive: 0, negative: 0 };
  const partDirectionWeights: Partial<Record<MeasurementKey, DirectionWeights>> = {};

  for (const feedback of usableRows) {
    const rowWeight = getRowWeight(feedback, now);
    weightedSampleCount += rowWeight;
    if (feedback.recommendationLog) corroboratedRows += 1;

    const overallLabel = normalizeFeedbackLabel(feedback.actualFitLabel);
    if (overallLabel) {
      overallSampleCount += 1;
      const direction = getFeedbackDirection(overallLabel);
      overallDirectionWeights = addDirectionWeight(overallDirectionWeights, direction, rowWeight);
      if (direction !== 0) {
        for (const key of measurementKeys) {
          addOffsetSignal(accumulator.offsetTotals, accumulator.offsetWeights, key, direction, rowWeight);
        }
      }
    }

    const partFeedback = normalizePartFeedback(feedback.partFeedback);
    for (const key of measurementKeys) {
      const label = partFeedback[key];
      if (!label) continue;
      partSampleCount += 1;
      accumulator.partUsableRows[key] = (accumulator.partUsableRows[key] ?? 0) + 1;
      accumulator.partFeedbackCounts[key] = {
        ...accumulator.partFeedbackCounts[key],
        [label]: (accumulator.partFeedbackCounts[key]?.[label] ?? 0) + 1
      };

      const direction = getFeedbackDirection(label);
      partDirectionWeights[key] = addDirectionWeight(
        partDirectionWeights[key] ?? { positive: 0, negative: 0 },
        direction,
        rowWeight
      );
      if (direction !== 0) {
        addOffsetSignal(accumulator.partOffsetTotals, accumulator.partOffsetWeights, key, direction, rowWeight);
        accumulator.issueCounts[key] = (accumulator.issueCounts[key] ?? 0) + 1;
      }
    }
  }

  const hasMinimumSignal = usableRows.length >= CATEGORY_MIN_USABLE_ROWS;
  const hasOverallConflict = getHasConflictingFeedback(overallDirectionWeights);
  const hasPartConflict = measurementKeys.some((key) => {
    const weights = partDirectionWeights[key];
    return weights ? getHasConflictingFeedback(weights) : false;
  });
  const hasConflictingFeedback = hasOverallConflict || hasPartConflict;
  const canApplyFeedback = hasMinimumSignal && !hasConflictingFeedback;
  const measurementOffsets = canApplyFeedback ? buildOffsets(measurementKeys, accumulator) : {};
  const weightMultipliers = canApplyFeedback ? buildWeightMultipliers(measurementKeys, accumulator) : {};
  const hasAppliedAdjustment =
    Object.keys(measurementOffsets).length > 0 || Object.keys(weightMultipliers).length > 0;
  const status = !hasMinimumSignal
    ? "insufficient_signal"
    : hasConflictingFeedback
      ? "conflicting_feedback"
      : hasAppliedAdjustment
        ? "applied"
        : "no_directional_signal";

  return {
    category,
    sampleCount: usableRows.length,
    overallSampleCount,
    partSampleCount,
    measurementOffsets,
    weightMultipliers,
    partFeedbackCounts: accumulator.partFeedbackCounts,
    reliability: {
      applied: status === "applied",
      status,
      categoryUsableRows: usableRows.length,
      categoryMinUsableRows: CATEGORY_MIN_USABLE_ROWS,
      partMinUsableRows: PART_MIN_USABLE_ROWS,
      weightedSampleCount: round(weightedSampleCount),
      partUsableRows: accumulator.partUsableRows,
      corroboratedRows
    },
    strategy: "feedback_offset_weight_v1"
  };
};
