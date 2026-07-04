import type { Category, FeedbackFitLabel, MeasurementKey } from "./fit.types";

export type CalibrationReadinessReason = "ready" | "insufficient_feedback";
export type ResultDetailsShape = "current_fit_engine_v1" | "legacy_chart_diff" | "unknown_object" | "malformed";

export interface CalibrationFeedbackRow {
  readonly category: Category | string | null;
  readonly actualFitLabel?: string | null; readonly actual_fit_label?: string | null;
  readonly actualFitRating?: number | null; readonly actual_fit_rating?: number | null;
  readonly purchasedSizeLabel?: string | null; readonly purchased_size_label?: string | null;
  readonly partFeedback?: unknown; readonly part_feedback?: unknown;
}

export interface CalibrationRecommendationLogRow {
  readonly eventType?: string | null; readonly event_type?: string | null;
  readonly clickedAt?: string | null; readonly clicked_at?: string | null;
  readonly purchasedAt?: string | null; readonly purchased_at?: string | null;
}

export interface CalibrationExternalSizeRow {
  readonly measurementSource?: string | null; readonly measurement_source?: string | null;
  readonly parsingStatus?: string | null; readonly parsing_status?: string | null;
  readonly extractionConfidence?: number | null; readonly extraction_confidence?: number | null;
}

export interface CalibrationFitResultRow {
  readonly resultDetails?: unknown;
  readonly result_details?: unknown;
}

export interface FitCalibrationAuditInput {
  readonly feedbackRows: readonly CalibrationFeedbackRow[];
  readonly recommendationLogs: readonly CalibrationRecommendationLogRow[];
  readonly externalSizeRows: readonly CalibrationExternalSizeRow[];
  readonly fitResultRows: readonly CalibrationFitResultRow[];
}

export interface FieldPresenceSummary {
  fieldPresentRows: number;
  presentRows: number;
}

export interface CategoryCalibrationSummary {
  feedbackRows: number;
  reliableFeedbackRows: number;
  calibrationReady: boolean;
  reason: CalibrationReadinessReason;
  actualFitLabels: Record<string, number>;
  purchasedSize: FieldPresenceSummary;
  partFeedback: {
    totalParts: number;
    malformedRows: number;
    byMeasurement: Partial<Record<MeasurementKey, Partial<Record<FeedbackFitLabel, number>>>>;
  };
}

export interface FitCalibrationAudit {
  readonly overall: Readonly<Pick<CategoryCalibrationSummary, "feedbackRows" | "reliableFeedbackRows" | "calibrationReady" | "reason">>;
  readonly categories: Record<string, CategoryCalibrationSummary>;
  readonly recommendationLogs: {
    readonly totalRows: number;
    readonly eventTypes: Record<string, number>;
    readonly clickedAt: FieldPresenceSummary;
    readonly purchasedAt: FieldPresenceSummary;
  };
  readonly externalSizes: {
    readonly totalRows: number;
    readonly measurementSource: Record<string, number>;
    readonly parsingStatus: Record<string, number>;
    readonly extractionConfidence: Record<"missing" | "low" | "medium" | "high", number>;
  };
  readonly resultDetailsShapes: Record<ResultDetailsShape, number>;
}

const MIN_RELIABLE_FEEDBACK_ROWS = 5;
const MEASUREMENT_KEYS: readonly string[] = ["total_length", "shoulder_width", "chest_width", "sleeve_length", "waist_width", "hip_width", "rise", "outseam"];

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const increment = (counts: Record<string, number>, key: string): void => {
  counts[key] = (counts[key] ?? 0) + 1;
};

const hasPresentValue = (value: string | number | null | undefined): boolean =>
  value !== null && value !== undefined && value !== "";

const normalizeFeedbackLabel = (label: string | null | undefined): FeedbackFitLabel | undefined => {
  switch (label) {
    case "too_small":
    case "small":
      return "too_small";
    case "slightly_small":
      return "slightly_small";
    case "very_good_fit":
    case "good_fit":
    case "acceptable":
    case "good":
      return "good";
    case "slightly_large":
      return "slightly_large";
    case "too_large":
    case "large":
      return "too_large";
    default:
      return undefined;
  }
};

const isMeasurementKey = (key: string): key is MeasurementKey =>
  MEASUREMENT_KEYS.includes(key);

const createCategorySummary = (): CategoryCalibrationSummary => ({
  feedbackRows: 0,
  reliableFeedbackRows: 0,
  calibrationReady: false,
  reason: "insufficient_feedback",
  actualFitLabels: {},
  purchasedSize: { fieldPresentRows: 0, presentRows: 0 },
  partFeedback: { totalParts: 0, malformedRows: 0, byMeasurement: {} }
});

const finalizeCategory = (summary: CategoryCalibrationSummary): CategoryCalibrationSummary => {
  const calibrationReady = summary.reliableFeedbackRows >= MIN_RELIABLE_FEEDBACK_ROWS;
  return {
    ...summary,
    calibrationReady,
    reason: calibrationReady ? "ready" : "insufficient_feedback"
  };
};

const summarizeFeedback = (
  feedbackRows: readonly CalibrationFeedbackRow[]
): { readonly overall: FitCalibrationAudit["overall"]; readonly categories: Record<string, CategoryCalibrationSummary> } => {
  const categories: Record<string, CategoryCalibrationSummary> = {};
  let reliableFeedbackRows = 0;

  for (const row of feedbackRows) {
    const category = row.category ?? "unknown";
    categories[category] = categories[category] ?? createCategorySummary();
    const categorySummary = categories[category];
    categorySummary.feedbackRows += 1;

    if (Object.hasOwn(row, "purchasedSizeLabel") || Object.hasOwn(row, "purchased_size_label")) {
      categorySummary.purchasedSize.fieldPresentRows += 1;
    }
    if (hasPresentValue(row.purchasedSizeLabel ?? row.purchased_size_label)) {
      categorySummary.purchasedSize.presentRows += 1;
    }

    const normalizedLabel = normalizeFeedbackLabel(row.actualFitLabel ?? row.actual_fit_label);
    const rating = row.actualFitRating ?? row.actual_fit_rating;
    const isReliable = normalizedLabel !== undefined || (typeof rating === "number" && rating >= 1 && rating <= 5);
    if (isReliable) {
      categorySummary.reliableFeedbackRows += 1;
      reliableFeedbackRows += 1;
    }
    if (normalizedLabel) increment(categorySummary.actualFitLabels, normalizedLabel);

    const partFeedback = row.partFeedback ?? row.part_feedback;
    if (partFeedback === undefined || partFeedback === null) continue;
    if (!isRecord(partFeedback)) {
      categorySummary.partFeedback.malformedRows += 1;
      continue;
    }

    for (const [key, value] of Object.entries(partFeedback)) {
      if (!isMeasurementKey(key) || typeof value !== "string") continue;
      const normalizedPartLabel = normalizeFeedbackLabel(value);
      if (!normalizedPartLabel) continue;
      const measurementCounts = categorySummary.partFeedback.byMeasurement[key] ?? {};
      measurementCounts[normalizedPartLabel] = (measurementCounts[normalizedPartLabel] ?? 0) + 1;
      categorySummary.partFeedback.byMeasurement[key] = measurementCounts;
      categorySummary.partFeedback.totalParts += 1;
    }
  }

  const finalizedCategories = Object.fromEntries(
    Object.entries(categories).map(([category, summary]) => [category, finalizeCategory(summary)])
  );
  const calibrationReady = reliableFeedbackRows >= MIN_RELIABLE_FEEDBACK_ROWS;

  return {
    overall: {
      feedbackRows: feedbackRows.length,
      reliableFeedbackRows,
      calibrationReady,
      reason: calibrationReady ? "ready" : "insufficient_feedback"
    },
    categories: finalizedCategories
  };
};

const summarizeFieldPresence = <Row extends object>(
  rows: readonly Row[],
  camelField: keyof Row,
  snakeField: keyof Row
): FieldPresenceSummary => {
  let fieldPresentRows = 0;
  let presentRows = 0;

  for (const row of rows) {
    if (Object.hasOwn(row, camelField) || Object.hasOwn(row, snakeField)) fieldPresentRows += 1;
    const value = row[camelField] ?? row[snakeField];
    if (typeof value === "string" && value !== "") presentRows += 1;
  }

  return { fieldPresentRows, presentRows };
};

const summarizeRecommendationLogs = (rows: readonly CalibrationRecommendationLogRow[]): FitCalibrationAudit["recommendationLogs"] => {
  const eventTypes: Record<string, number> = {};
  for (const row of rows) {
    increment(eventTypes, row.eventType ?? row.event_type ?? "unknown");
  }

  return {
    totalRows: rows.length,
    eventTypes,
    clickedAt: summarizeFieldPresence(rows, "clickedAt", "clicked_at"),
    purchasedAt: summarizeFieldPresence(rows, "purchasedAt", "purchased_at")
  };
};

const getConfidenceBucket = (value: number | null | undefined): "missing" | "low" | "medium" | "high" => {
  if (typeof value !== "number") return "missing";
  if (value >= 0.8) return "high";
  if (value >= 0.5) return "medium";
  return "low";
};

const summarizeExternalSizes = (rows: readonly CalibrationExternalSizeRow[]): FitCalibrationAudit["externalSizes"] => {
  const measurementSource: Record<string, number> = {};
  const parsingStatus: Record<string, number> = {};
  const extractionConfidence = { missing: 0, low: 0, medium: 0, high: 0 };

  for (const row of rows) {
    increment(measurementSource, row.measurementSource ?? row.measurement_source ?? "unknown");
    increment(parsingStatus, row.parsingStatus ?? row.parsing_status ?? "unknown");
    extractionConfidence[getConfidenceBucket(row.extractionConfidence ?? row.extraction_confidence)] += 1;
  }

  return { totalRows: rows.length, measurementSource, parsingStatus, extractionConfidence };
};

const classifyResultDetails = (value: unknown): ResultDetailsShape => {
  if (!isRecord(value)) return "malformed";
  if ("allSizeScores" in value || "referenceProfile" in value || "partExplanations" in value) {
    return "current_fit_engine_v1";
  }
  if ("diff" in value || "chartData" in value) return "legacy_chart_diff";
  return "unknown_object";
};

const summarizeResultDetailsShapes = (rows: readonly CalibrationFitResultRow[]): Record<ResultDetailsShape, number> => {
  const shapes: Record<ResultDetailsShape, number> = {
    current_fit_engine_v1: 0,
    legacy_chart_diff: 0,
    unknown_object: 0,
    malformed: 0
  };

  for (const row of rows) {
    const shape = classifyResultDetails(row.resultDetails ?? row.result_details);
    shapes[shape] += 1;
  }

  return shapes;
};

export const auditFitCalibrationSignals = (input: FitCalibrationAuditInput): FitCalibrationAudit => {
  const feedback = summarizeFeedback(input.feedbackRows);

  return {
    overall: feedback.overall,
    categories: feedback.categories,
    recommendationLogs: summarizeRecommendationLogs(input.recommendationLogs),
    externalSizes: summarizeExternalSizes(input.externalSizeRows),
    resultDetailsShapes: summarizeResultDetailsShapes(input.fitResultRows)
  };
};
