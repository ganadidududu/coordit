import { createHash } from "node:crypto";
import { supabase } from "../../config/supabase";
import { createHttpError } from "../../shared/utils/http-error";
import { assertSameComparisonBundle, loadPaidComparisonBundle } from "../fit-report/fit-report.comparison-bundle";
import { getThreadBalance } from "../thread-wallet/thread-wallet.service";
import { getFitAnalysisResult, prepareFitRecommendation, replayFitRecommendation } from "./fit.service";

interface CameraRemeasurementRequest {
  readonly userId: string;
  readonly bundleAnalysisId: string;
  readonly idempotencyKey: string;
  readonly externalProductId: string;
  readonly referenceClothingIds: readonly string[];
}

export const remeasureCameraComparison = async (request: CameraRemeasurementRequest) => {
  const original = await loadPaidComparisonBundle(request.userId, request.bundleAnalysisId);
  assertSameComparisonBundle(request.userId, original, {
    ...original,
    external_product_id: request.externalProductId,
    result_details: { referenceClothingIds: request.referenceClothingIds }
  });
  if (request.referenceClothingIds.length === 0) throw createHttpError(400, "같은 기준 의류를 선택해주세요.");
  const prepared = await prepareFitRecommendation({
    userId: request.userId, referenceClothingIds: [...request.referenceClothingIds], externalProductId: request.externalProductId
  });
  const value = prepared.persistence;
  const digest = createHash("sha256").update(`coordit.camera.remeasurement.v1:${request.userId}:${request.idempotencyKey}`).digest("hex");
  const id = `${digest.slice(0, 8)}-${digest.slice(8, 12)}-4${digest.slice(13, 16)}-8${digest.slice(17, 20)}-${digest.slice(20, 32)}`;
  const { error } = await supabase.from("fit_analysis_results").upsert({
    id, user_id: request.userId, reference_clothing_id: value.referenceClothingId,
    external_product_id: value.externalProductId, recommended_external_product_size_id: value.recommendedExternalProductSizeId,
    recommended_size_label: value.recommendedSizeLabel, fit_score: value.fitScore, fit_label: value.fitLabel,
    fit_comment: value.fitComment, weighted_fit_distance: value.weightedFitDistance, algorithm_version: value.algorithmVersion,
    recommendation_confidence: value.recommendationConfidence,
    result_details: { ...value.resultDetails, cameraComparisonBundleAnalysisId: request.bundleAnalysisId }
  }, { onConflict: "id", ignoreDuplicates: true });
  if (error) throw createHttpError(500, "재측정 분석을 저장하지 못했어요. 같은 요청으로 다시 시도해주세요.");
  const stored = await getFitAnalysisResult(request.userId, id);
  assertSameComparisonBundle(request.userId, original, stored);
  if (stored.result_details["cameraComparisonBundleAnalysisId"] !== request.bundleAnalysisId) {
    throw createHttpError(409, "이미 다른 분석 묶음에 사용한 요청이에요.");
  }
  return { ...replayFitRecommendation(stored), availableThreads: await getThreadBalance(request.userId) };
};
