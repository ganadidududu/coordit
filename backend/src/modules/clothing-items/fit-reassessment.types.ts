import type {
  ClothingItemRow,
  ClothingSizeRow,
  JsonObject,
  ReferenceClothingRow
} from "../../shared/types/database";
import type {
  Category,
  FeedbackFitProfile,
  FitLabel,
  MeasurementDiffs,
  RecommendationConfidence,
  SizeFitScore
} from "../fit/fit.types";

export type ClothingFitAssessmentPayload = {
  readonly fit_score: number;
  readonly fit_label: FitLabel;
  readonly fit_comment: string;
  readonly recommendation_confidence: RecommendationConfidence;
  readonly weighted_fit_distance: number;
  readonly diffs: MeasurementDiffs;
  readonly part_explanations: readonly string[];
  readonly part_statuses: SizeFitScore["partStatuses"];
  readonly compared_measurement_count: number;
  readonly result_details: JsonObject;
  readonly algorithm_version: string;
  readonly evaluated_at: string;
};

export type ClothingFitAssessmentRow = ClothingFitAssessmentPayload & {
  readonly id: string;
  readonly user_id: string;
  readonly clothing_item_id: string;
  readonly clothing_size_id: string | null;
  readonly created_at: string;
};

export type FitReassessmentSource = {
  readonly target: {
    readonly item: ClothingItemRow;
    readonly size: ClothingSizeRow | null;
  };
  readonly references: readonly {
    readonly reference: ReferenceClothingRow;
    readonly size: ClothingSizeRow | null;
  }[];
};

export type FitReassessmentRepository = {
  readonly loadSource: (
    userId: string,
    clothingItemId: string
  ) => Promise<FitReassessmentSource | null>;
  readonly record: (input: {
    readonly userId: string;
    readonly clothingItemId: string;
    readonly clothingSizeId: string;
    readonly assessment: ClothingFitAssessmentPayload;
  }) => Promise<ClothingFitAssessmentRow>;
};

export type FitReassessmentService = {
  readonly reassess: (
    userId: string,
    clothingItemId: string
  ) => Promise<ClothingFitAssessmentRow>;
};

export type FitReassessmentDependencies = {
  readonly repository: FitReassessmentRepository;
  readonly buildFeedbackProfile: (
    userId: string,
    category: Category
  ) => Promise<FeedbackFitProfile | undefined>;
  readonly now: () => Date;
};
