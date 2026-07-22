import { z } from "zod";
import type { ClothingFitAssessmentRow } from "./fit-reassessment.types";

const assessmentSchema = z.object({
  id: z.string(),
  user_id: z.string(),
  clothing_item_id: z.string(),
  clothing_size_id: z.string().nullable(),
  fit_score: z.number().min(0).max(100),
  fit_label: z.enum([
    "very_good_fit",
    "good_fit",
    "acceptable",
    "slightly_small",
    "slightly_large",
    "too_small",
    "too_large"
  ]),
  fit_comment: z.string(),
  recommendation_confidence: z.enum(["high", "medium", "low"]),
  weighted_fit_distance: z.number(),
  diffs: z.record(z.string(), z.number()),
  part_explanations: z.array(z.string()),
  part_statuses: z.record(
    z.string(),
    z.enum(["very_similar", "slightly_small", "slightly_large", "large_gap"])
  ),
  compared_measurement_count: z.number().int().positive(),
  result_details: z.record(z.string(), z.unknown()),
  algorithm_version: z.string(),
  evaluated_at: z.string(),
  created_at: z.string()
});

export const parseClothingFitAssessment = (
  value: unknown
): ClothingFitAssessmentRow => assessmentSchema.parse(value);
