import { supabase } from "../../config/supabase";
import { createHttpError } from "../../shared/utils/http-error";
import { asOptionalNumber, asOptionalRecord, asOptionalString, asRequiredString } from "../../shared/utils/request";

export const createUserFeedback = async (
  userId: string,
  fitAnalysisResultId: string,
  body: Record<string, unknown>
) => {
  const actualFitLabel = asRequiredString(
    body.actualFitLabel ?? body.actual_fit_label,
    "actualFitLabel"
  );

  const { data: fitResult, error: fitResultError } = await supabase
    .from("fit_analysis_results")
    .select("id")
    .eq("user_id", userId)
    .eq("id", fitAnalysisResultId)
    .single();

  if (fitResultError || !fitResult) throw createHttpError(404, "Fit analysis result was not found");

  const { data, error } = await supabase
    .from("user_feedback")
    .insert({
      user_id: userId,
      fit_analysis_result_id: fitAnalysisResultId,
      purchased_size_label: asOptionalString(body.purchasedSizeLabel ?? body.purchased_size_label),
      actual_fit_rating: asOptionalNumber(body.actualFitRating ?? body.actual_fit_rating),
      actual_fit_label: actualFitLabel,
      part_feedback: asOptionalRecord(body.partFeedback ?? body.part_feedback),
      comment: asOptionalString(body.comment),
      raw_data: asOptionalRecord(body.rawData ?? body.raw_data)
    })
    .select("*")
    .single();

  if (error || !data) throw createHttpError(500, "Failed to save user feedback");
  return data;
};

export const listUserFeedback = async (userId: string) => {
  const { data, error } = await supabase
    .from("user_feedback")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw createHttpError(500, "Failed to load user feedback");
  return data ?? [];
};
