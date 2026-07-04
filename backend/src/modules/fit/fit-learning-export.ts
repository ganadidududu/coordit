import {
  normalizeAlgorithmVersion,
  normalizeCategory,
  normalizeConfidenceBreakdown,
  normalizeEventType,
  normalizeFeedbackLabel,
  normalizeFitLabel,
  normalizeFitType,
  normalizeMeasurementSource,
  normalizeExportRef,
  normalizeFiniteNumber,
  normalizeObservedAt,
  normalizeParsingStatus,
  normalizePartFeedback,
  normalizeRecommendationConfidence,
  normalizeScoreExplanation,
  normalizeSizeLabel
} from "./fit-learning-export.normalizers";
import type { JsonValue, MeasurementFeedback } from "./fit-learning-export.normalizers";

export interface FitLearningExportSourceRow {
  readonly fitResult: { readonly exportRef: string; readonly recommended_size_label?: string | null; readonly fit_score?: unknown; readonly fit_label?: string | null; readonly weighted_fit_distance?: unknown; readonly recommendation_confidence?: string | null; readonly algorithm_version?: string | null; readonly result_details?: unknown; readonly created_at?: string | null; readonly id?: string | null; readonly user_id?: string | null; readonly authToken?: string | null; readonly raw_data?: unknown };
  readonly feedback?: { readonly purchased_size_label?: string | null; readonly actual_fit_rating?: unknown; readonly actual_fit_label?: string | null; readonly part_feedback?: unknown; readonly comment?: string | null; readonly raw_data?: unknown; readonly user_id?: string | null } | null;
  readonly recommendationLog?: { readonly event_type?: string | null; readonly clicked_at?: string | null; readonly purchased_at?: string | null; readonly recommended_size_label?: string | null; readonly raw_data?: unknown; readonly user_id?: string | null } | null;
  readonly externalProduct?: { readonly category?: string | null; readonly fit_type?: string | null; readonly id?: string | null; readonly user_id?: string | null; readonly product_url?: string | null; readonly raw_product_data?: unknown } | null;
  readonly recommendedSize?: { readonly id?: string | null; readonly size_label?: string | null; readonly measurement_source?: string | null; readonly parsing_status?: string | null; readonly extraction_confidence?: unknown; readonly extracted_text?: string | null; readonly raw_size_data?: unknown; readonly user_id?: string | null } | null;
}

export interface FitLearningExportRecord {
  readonly schemaVersion: "fit_learning_export_v1";
  readonly exportRef: string | null;
  readonly observedAt: string | null;
  readonly productContext: { readonly category: string | null; readonly fitType: string | null };
  readonly recommendation: { readonly recommendedSizeLabel: string | null; readonly fitScore: number | null; readonly fitLabel: string | null; readonly weightedFitDistance: number | null; readonly recommendationConfidence: string | null; readonly algorithmVersion: string | null };
  readonly outcome: { readonly purchasedSizeLabel: string | null; readonly actualFitRating: number | null; readonly actualFitLabel: string | null; readonly partFeedback: MeasurementFeedback };
  readonly engagement: { readonly eventType: string | null; readonly clicked: boolean; readonly purchased: boolean };
  readonly scoreExplanation: JsonValue | null;
  readonly confidenceBreakdown: JsonValue | null;
  readonly measurementSource: { readonly recommendedSizeLabel: string | null; readonly measurementSource: string | null; readonly parsingStatus: string | null; readonly extractionConfidence: number | null };
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const getResultDetails = (row: FitLearningExportSourceRow): Record<string, unknown> | undefined => {
  const resultDetails = row.fitResult.result_details;
  return isRecord(resultDetails) ? resultDetails : undefined;
};

export const buildFitLearningExportRecords = (
  rows: readonly FitLearningExportSourceRow[]
): readonly FitLearningExportRecord[] =>
  rows.map((row) => {
    const resultDetails = getResultDetails(row);
    return {
      schemaVersion: "fit_learning_export_v1",
      exportRef: normalizeExportRef(row.fitResult.exportRef),
      observedAt: normalizeObservedAt(row.fitResult.created_at),
      productContext: {
        category: normalizeCategory(row.externalProduct?.category),
        fitType: normalizeFitType(row.externalProduct?.fit_type)
      },
      recommendation: {
        recommendedSizeLabel: normalizeSizeLabel(row.fitResult.recommended_size_label),
        fitScore: normalizeFiniteNumber(row.fitResult.fit_score),
        fitLabel: normalizeFitLabel(row.fitResult.fit_label),
        weightedFitDistance: normalizeFiniteNumber(row.fitResult.weighted_fit_distance),
        recommendationConfidence: normalizeRecommendationConfidence(row.fitResult.recommendation_confidence),
        algorithmVersion: normalizeAlgorithmVersion(row.fitResult.algorithm_version)
      },
      outcome: {
        purchasedSizeLabel: normalizeSizeLabel(row.feedback?.purchased_size_label),
        actualFitRating: normalizeFiniteNumber(row.feedback?.actual_fit_rating),
        actualFitLabel: normalizeFeedbackLabel(row.feedback?.actual_fit_label),
        partFeedback: normalizePartFeedback(row.feedback?.part_feedback)
      },
      engagement: {
        eventType: normalizeEventType(row.recommendationLog?.event_type),
        clicked: Boolean(row.recommendationLog?.clicked_at),
        purchased: Boolean(row.recommendationLog?.purchased_at)
      },
      scoreExplanation: normalizeScoreExplanation(resultDetails?.scoreExplanation),
      confidenceBreakdown: normalizeConfidenceBreakdown(resultDetails?.confidenceBreakdown),
      measurementSource: {
        recommendedSizeLabel: normalizeSizeLabel(row.recommendedSize?.size_label) ?? normalizeSizeLabel(row.fitResult.recommended_size_label),
        measurementSource: normalizeMeasurementSource(row.recommendedSize?.measurement_source),
        parsingStatus: normalizeParsingStatus(row.recommendedSize?.parsing_status),
        extractionConfidence: normalizeFiniteNumber(row.recommendedSize?.extraction_confidence)
      }
    };
  });

export const exportFitLearningJsonl = (rows: readonly FitLearningExportSourceRow[]): string =>
  buildFitLearningExportRecords(rows)
    .map((record) => JSON.stringify(record))
    .join("\n");
