import { areCategoriesCompatible } from "../../shared/utils/category-compatibility";
import { createHttpError } from "../../shared/utils/http-error";
import { rowToMeasurements } from "../../shared/utils/measurements";
import { recommendBestSizeWithReferences } from "../fit/fit-score.engine";
import type {
  ExternalProductSizeInput,
  MeasurementKey,
  ReferenceClothingInput
} from "../fit/fit.types";
import type {
  FitReassessmentDependencies,
  FitReassessmentService
} from "./fit-reassessment.types";

const MEASUREMENT_KEYS = [
  "total_length",
  "shoulder_width",
  "chest_width",
  "sleeve_length",
  "waist_width",
  "hip_width",
  "rise",
  "outseam"
] as const satisfies readonly MeasurementKey[];

const insufficientData = (): Error => createHttpError(
  422,
  "재평가에 필요한 기준 의류 또는 비교 가능한 실측 정보가 부족해요."
);

export const createFitReassessmentService = (
  dependencies: FitReassessmentDependencies
): FitReassessmentService => ({
  reassess: async (userId, clothingItemId) => {
    const source = await dependencies.repository.loadSource(userId, clothingItemId);
    if (!source) throw createHttpError(404, "Clothing item was not found");
    if (!source.target.size) throw insufficientData();

    const category = source.target.item.category;
    const references: ReferenceClothingInput[] = source.references.flatMap(({ reference, size }) => {
      if (
        reference.clothing_item_id === clothingItemId
        || !reference.is_active
        || !areCategoriesCompatible(reference.category, category)
        || !size
      ) return [];
      return [{
        id: reference.id,
        clothingItemId: reference.clothing_item_id,
        sizeLabel: size.size_label,
        fitType: reference.fit_type,
        preferenceScore: reference.preference_score,
        measurements: rowToMeasurements(size)
      }];
    });
    if (references.length === 0) throw insufficientData();

    const target: ExternalProductSizeInput = {
      id: source.target.size.id,
      sizeLabel: source.target.size.size_label ?? source.target.item.size_label ?? "현재 사이즈",
      fitType: source.target.item.fit_type,
      measurements: rowToMeasurements(source.target.size)
    };
    const hasComparableMeasurement = MEASUREMENT_KEYS.some((key) =>
      typeof target.measurements[key] === "number"
        && references.some((reference) => typeof reference.measurements[key] === "number")
    );
    if (!hasComparableMeasurement) throw insufficientData();

    const feedbackProfile = await dependencies.buildFeedbackProfile(userId, category);
    const recommendation = recommendBestSizeWithReferences(
      references,
      [target],
      category,
      feedbackProfile
    );
    const best = recommendation.recommended;
    return dependencies.repository.record({
      userId,
      clothingItemId,
      clothingSizeId: source.target.size.id,
      assessment: {
        fit_score: best.finalFitScore,
        fit_label: best.fitLabel,
        fit_comment: best.fitComment,
        recommendation_confidence: best.recommendationConfidence,
        weighted_fit_distance: best.weightedFitDistance,
        diffs: best.diffs,
        part_explanations: best.partExplanations,
        part_statuses: best.partStatuses,
        compared_measurement_count: best.comparedMeasurements.length,
        result_details: {
          baseWeights: recommendation.baseWeights,
          dynamicWeights: recommendation.dynamicWeights,
          referenceVariance: recommendation.referenceVariance,
          weightingStrategy: recommendation.weightingStrategy,
          referenceProfile: recommendation.referenceProfile,
          feedbackProfile: recommendation.feedbackProfile,
          referenceClothingIds: references.map((reference) => reference.id)
        },
        algorithm_version: best.algorithmVersion,
        evaluated_at: dependencies.now().toISOString()
      }
    });
  }
});
