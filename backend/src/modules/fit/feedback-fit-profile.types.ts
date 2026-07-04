import type {
  Category,
  FeedbackFitProfile,
  MeasurementDiffs,
  MeasurementKey,
  MeasurementWeights,
  PartFeedbackMap
} from "./fit.types";

export interface FeedbackRow {
  fit_analysis_result_id: string;
  actual_fit_label: string | null;
  part_feedback: PartFeedbackMap | null;
  created_at: string | null;
}

export interface FitResultFeedbackSource {
  id: string;
  external_product_id: string;
}

export interface ExternalProductFeedbackSource {
  id: string;
  category: Category;
}

export interface RecommendationLogFeedbackSource {
  fit_analysis_result_id: string | null;
  event_type: string;
  clicked_at: string | null;
  purchased_at: string | null;
}

export interface FeedbackProfileSourceRow {
  readonly fitAnalysisResultId: string;
  readonly actualFitLabel: string | null;
  readonly partFeedback?: PartFeedbackMap | null;
  readonly createdAt: string | null;
  readonly recommendationLog?: {
    readonly eventType: string;
    readonly clickedAt: string | null;
    readonly purchasedAt: string | null;
  };
}

export type FeedbackAccumulator = {
  readonly offsetTotals: MeasurementDiffs;
  readonly offsetWeights: Partial<Record<MeasurementKey, number>>;
  readonly partOffsetTotals: MeasurementDiffs;
  readonly partOffsetWeights: Partial<Record<MeasurementKey, number>>;
  readonly issueCounts: Partial<Record<MeasurementKey, number>>;
  readonly partFeedbackCounts: FeedbackFitProfile["partFeedbackCounts"];
  readonly partUsableRows: Partial<Record<MeasurementKey, number>>;
};

export type DirectionWeights = {
  readonly positive: number;
  readonly negative: number;
};
