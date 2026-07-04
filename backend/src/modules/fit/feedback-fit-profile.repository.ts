import type { Category, FeedbackFitProfile } from "./fit.types";
import { buildFeedbackFitProfileFromRows } from "./feedback-fit-profile.builder";
import type {
  ExternalProductFeedbackSource,
  FeedbackProfileSourceRow,
  FeedbackRow,
  FitResultFeedbackSource,
  RecommendationLogFeedbackSource
} from "./feedback-fit-profile.types";

const MAX_FEEDBACK_ROWS = 50;

const getBestRecommendationLog = (
  logs: readonly RecommendationLogFeedbackSource[],
  fitAnalysisResultId: string
): FeedbackProfileSourceRow["recommendationLog"] | undefined => {
  const matchingLogs = logs.filter((log) => log.fit_analysis_result_id === fitAnalysisResultId);
  const purchasedLog = matchingLogs.find((log) => log.purchased_at || log.event_type === "purchased");
  const clickedLog = matchingLogs.find((log) => log.clicked_at || log.event_type === "clicked");
  const selectedLog = purchasedLog ?? clickedLog ?? matchingLogs[0];
  if (!selectedLog) return undefined;
  return {
    eventType: selectedLog.event_type,
    clickedAt: selectedLog.clicked_at,
    purchasedAt: selectedLog.purchased_at
  };
};

export const buildUserFeedbackFitProfile = async (
  userId: string,
  category: Category
): Promise<FeedbackFitProfile | undefined> => {
  const { supabase } = await import("../../config/supabase");
  const { data: feedbackRows, error: feedbackError } = await supabase
    .from("user_feedback")
    .select("fit_analysis_result_id, actual_fit_label, part_feedback, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(MAX_FEEDBACK_ROWS)
    .returns<FeedbackRow[]>();

  if (feedbackError || !feedbackRows || feedbackRows.length === 0) return undefined;

  const fitResultIds = Array.from(new Set(feedbackRows.map((row) => row.fit_analysis_result_id)));
  const { data: fitResults, error: fitResultsError } = await supabase
    .from("fit_analysis_results")
    .select("id, external_product_id")
    .eq("user_id", userId)
    .in("id", fitResultIds)
    .returns<FitResultFeedbackSource[]>();

  if (fitResultsError || !fitResults || fitResults.length === 0) return undefined;

  const externalProductIds = Array.from(new Set(fitResults.map((result) => result.external_product_id)));
  const { data: externalProducts, error: externalProductsError } = await supabase
    .from("external_products")
    .select("id, category")
    .eq("user_id", userId)
    .in("id", externalProductIds)
    .returns<ExternalProductFeedbackSource[]>();

  if (externalProductsError || !externalProducts || externalProducts.length === 0) return undefined;

  const { data: recommendationLogs } = await supabase
    .from("recommendation_logs")
    .select("fit_analysis_result_id, event_type, clicked_at, purchased_at")
    .eq("user_id", userId)
    .in("fit_analysis_result_id", fitResultIds)
    .returns<RecommendationLogFeedbackSource[]>();

  const logs = recommendationLogs ?? [];
  const productCategoryById = new Map(externalProducts.map((product) => [product.id, product.category]));
  const resultCategoryById = new Map(
    fitResults.map((result) => [result.id, productCategoryById.get(result.external_product_id)])
  );
  const categoryFeedback = feedbackRows
    .filter((row) => resultCategoryById.get(row.fit_analysis_result_id) === category)
    .map<FeedbackProfileSourceRow>((row) => ({
      fitAnalysisResultId: row.fit_analysis_result_id,
      actualFitLabel: row.actual_fit_label,
      partFeedback: row.part_feedback,
      createdAt: row.created_at,
      recommendationLog: getBestRecommendationLog(logs, row.fit_analysis_result_id)
    }));

  return buildFeedbackFitProfileFromRows(category, categoryFeedback);
};
