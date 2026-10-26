import { supabase } from "../../config/supabase";
import type { FitAnalysisResultRow } from "../../shared/types/database";
import { createHttpError } from "../../shared/utils/http-error";
import { getThreadBalance } from "../thread-wallet/thread-wallet.service";
import { loadFitResult } from "./fit-report.repository";
import { readStoredFitReport, storeFitReport } from "./fit-report.artifact";
import type { GenerateFitReportResult } from "./fit-report.types";

const referenceIds = (result: FitAnalysisResultRow): readonly string[] => {
  const stored = result.result_details["referenceClothingIds"];
  if (Array.isArray(stored)) {
    const ids = stored.filter((value): value is string => typeof value === "string");
    if (ids.length > 0) return [...new Set(ids)].sort();
  }
  return [result.reference_clothing_id];
};

export const assertSameComparisonBundle = (
  owner: string,
  original: FitAnalysisResultRow,
  revised: FitAnalysisResultRow
): void => {
  const originalReferences = referenceIds(original);
  const revisedReferences = referenceIds(revised);
  if (original.user_id !== owner || revised.user_id !== owner
    || original.external_product_id !== revised.external_product_id
    || originalReferences.length !== revisedReferences.length
    || originalReferences.some((id, index) => id !== revisedReferences[index])) {
    throw createHttpError(403, "같은 상품과 기준 의류의 분석 묶음에서만 다시 측정할 수 있어요.");
  }
};

export const loadPaidComparisonBundle = async (userId: string, originalAnalysisId: string): Promise<FitAnalysisResultRow> => {
  const original = await loadFitResult(userId, originalAnalysisId);
  const { data, error } = await supabase.from("thread_ledger_entries")
    .select("id").eq("user_id", userId).eq("fit_analysis_result_id", originalAnalysisId)
    .in("reason", ["fit_analysis", "fit_report"]).eq("amount", -1).limit(1).maybeSingle<{ id: string }>();
  if (error) throw createHttpError(500, "분석 묶음 결제 상태를 확인하지 못했어요.");
  if (!data) throw createHttpError(403, "실타래를 사용한 분석 묶음이 필요해요.");
  return original;
};

export const hasPaidCameraAnalysis = async (userId: string, analysisId: string): Promise<boolean> => {
  const { data, error } = await supabase.from("thread_ledger_entries").select("id")
    .eq("user_id", userId).eq("fit_analysis_result_id", analysisId).eq("reason", "fit_analysis")
    .eq("amount", -1).limit(1).maybeSingle<{ id: string }>();
  if (error) throw createHttpError(500, "분석 결제 상태를 확인하지 못했어요.");
  return data !== null;
};

export const authorizeComparisonBundle = async (
  userId: string,
  originalAnalysisId: string,
  revisedAnalysisId: string
): Promise<number> => {
  const [original, revised] = await Promise.all([
    loadPaidComparisonBundle(userId, originalAnalysisId),
    loadFitResult(userId, revisedAnalysisId)
  ]);
  assertSameComparisonBundle(userId, original, revised);
  return getThreadBalance(userId);
};

export const completeCameraComparison = async (
  userId: string,
  idempotencyKey: string,
  result: GenerateFitReportResult
): Promise<GenerateFitReportResult> => {
  const { data, error } = await supabase.rpc("complete_camera_comparison", {
    p_user_id: userId,
    p_idempotency_key: idempotencyKey,
    p_fit_analysis_result_id: result.fitAnalysisResultId,
    p_report_artifact: storeFitReport({}, result)["storedFitReport"]
  }).single<{ available_threads: number; status: string; stored_report: unknown }>();
  if (error?.code === "23505") throw createHttpError(409, "이미 다른 분석에 사용한 요청이에요.");
  if (error || !data) throw createHttpError(500, "분석 완료 상태를 확인하지 못했어요. 같은 요청으로 다시 시도하면 중복 차감되지 않아요.");
  if (data.status === "insufficient") throw createHttpError(402, "실타래가 부족해요. 충전 후 같은 측정으로 이어갈 수 있어요.");
  const stored = readStoredFitReport({ storedFitReport: data.stored_report });
  if (!stored) throw createHttpError(500, "저장된 분석을 불러오지 못했어요. 같은 요청으로 다시 시도해주세요.");
  return { ...result, ...stored, availableThreads: data.available_threads };
};
