import { supabase } from "../../config/supabase";
import { createHttpError } from "../../shared/utils/http-error";
import type { PreparedFitRecommendation } from "../fit/fit.service";
import { verifyAppleTransaction } from "./apple-iap-verifier";
import { threadAmountForAppleProduct } from "./apple-iap-products";
import { requireThreadPurchaseMember } from "./thread-purchase-access.service";
import type {
  AppleIapEnvironment,
  AppleIapVerifiedTransaction
} from "./apple-iap-policy";

interface ThreadBalanceRow {
  available_threads: number;
}

interface ThreadConsumptionRow extends ThreadBalanceRow {
  status: "already_consumed" | "consumed" | "insufficient";
}

export type FitReportThreadConsumption = {
  readonly availableThreads: number;
  readonly status: "already_consumed" | "consumed";
};

interface ThreadLedgerRow {
  fit_analysis_result_id: string | null;
}

interface AtomicFitAnalysisRow extends ThreadBalanceRow {
  fit_analysis_result_id: string | null;
  status: "already_consumed" | "consumed" | "insufficient";
}

interface AppleIapCreditRow extends ThreadBalanceRow {
  status: "credited" | "already_credited";
}

export { appleIapThreadProductIDs } from "./apple-iap-products";
export type { AppleIapEnvironment, AppleIapVerifiedTransaction } from "./apple-iap-policy";

export type AppleIapCreditInput = AppleIapVerifiedTransaction & {
  readonly userId: string;
  readonly threads: number;
};

export type AppleIapCreditResult = {
  readonly availableThreads: number;
  readonly status: AppleIapCreditRow["status"];
};

export type AppleIapPurchaseRequest = {
  readonly userId: string;
  readonly signedTransaction: string;
};

type AppleIapPurchaseDependencies = {
  readonly requireMember: (userId: string) => Promise<void>;
  readonly resolveTransactionOwner?: (transaction: AppleIapVerifiedTransaction) => Promise<string>;
  readonly verifyAppleTransaction: (signedTransaction: string) => Promise<AppleIapVerifiedTransaction>;
  readonly creditAppleTransaction: (input: AppleIapCreditInput) => Promise<AppleIapCreditResult>;
};

export const settleAppleIapPurchase = async (
  request: AppleIapPurchaseRequest,
  dependencies: AppleIapPurchaseDependencies
): Promise<AppleIapCreditResult> => {
  await dependencies.requireMember(request.userId);
  const transaction = await dependencies.verifyAppleTransaction(request.signedTransaction);
  const owner = dependencies.resolveTransactionOwner
    ? await dependencies.resolveTransactionOwner(transaction)
    : transaction.appAccountToken;
  if (owner.toLowerCase() !== request.userId.toLowerCase()) {
    throw createHttpError(403, "이 계정으로 구매한 실타래만 충전할 수 있어요.");
  }
  return dependencies.creditAppleTransaction({
    userId: request.userId,
    ...transaction,
    threads: threadAmountForAppleProduct(transaction.productId)
  });
};

export const resolveAppleTransactionOwner = async (
  transaction: AppleIapVerifiedTransaction
): Promise<string> => {
  const { data, error } = await supabase.from("apple_iap_transactions")
    .select("user_id, app_account_token")
    .eq("transaction_id", transaction.transactionId)
    .maybeSingle<{ readonly user_id: string | null; readonly app_account_token: string }>();
  if (error) throw createHttpError(500, "Failed to resolve Apple transaction owner");
  if (!data) {
    const { data: merge, error: mergeError } = await supabase.from("guest_account_merges")
      .select("member_user_id").eq("guest_user_id", transaction.appAccountToken)
      .maybeSingle<{ readonly member_user_id: string | null }>();
    if (mergeError) throw createHttpError(500, "Failed to resolve merged Apple transaction owner");
    if (merge?.member_user_id) return merge.member_user_id;
    if (merge) throw createHttpError(409, "삭제된 계정의 구매 거래예요.");
    return transaction.appAccountToken;
  }
  if (data.user_id === null || data.app_account_token.toLowerCase() !== transaction.appAccountToken.toLowerCase()) {
    throw createHttpError(409, "이 구매 거래는 현재 계정으로 복구할 수 없어요.");
  }
  return data.user_id;
};

export const creditAppleIapTransaction = async (
  input: AppleIapCreditInput
): Promise<AppleIapCreditResult> => {
  const { data, error } = await supabase
    .rpc("grant_apple_iap_threads", {
      p_user_id: input.userId,
      p_transaction_id: input.transactionId,
      p_original_transaction_id: input.originalTransactionId,
      p_product_id: input.productId,
      p_app_account_token: input.appAccountToken,
      p_purchased_at: input.purchasedAt,
      p_environment: input.environment,
      p_thread_amount: input.threads
    })
    .single<AppleIapCreditRow>();
  if (error?.code === "23505") throw createHttpError(409, "이미 취소되었거나 다른 계정에서 처리된 구매 거래예요.");
  if (error || !data) throw createHttpError(500, "Failed to credit Apple in-app purchase");
  return {
    availableThreads: data.available_threads,
    status: data.status
  };
};

export const submitAppleIapPurchase = async (
  request: AppleIapPurchaseRequest
): Promise<AppleIapCreditResult> => {
  return settleAppleIapPurchase(request, {
    requireMember: requireThreadPurchaseMember,
    verifyAppleTransaction,
    resolveTransactionOwner: resolveAppleTransactionOwner,
    creditAppleTransaction: creditAppleIapTransaction
  });
};

export const getThreadBalance = async (userId: string): Promise<number> => {
  const { data, error } = await supabase
    .rpc("get_thread_balance", { p_user_id: userId })
    .single<ThreadBalanceRow>();
  if (error || !data) throw createHttpError(500, "Failed to load thread balance");
  return data.available_threads;
};

export const consumeFitAnalysisThread = async (
  userId: string,
  idempotencyKey: string,
  fitAnalysisResultId: string
): Promise<number> => {
  const { data, error } = await supabase
    .rpc("consume_fit_analysis_thread", {
      p_user_id: userId,
      p_idempotency_key: idempotencyKey,
      p_fit_analysis_result_id: fitAnalysisResultId
    })
    .single<ThreadConsumptionRow>();
  if (error || !data) throw createHttpError(500, "Failed to consume thread");
  if (data.status === "already_consumed") {
    throw createHttpError(409, "이미 처리한 핏 분석 요청이에요. 히스토리에서 결과를 확인해 주세요.");
  }
  if (data.status === "insufficient") {
    throw createHttpError(402, "실타래가 부족해요. 충전 후 다시 시도해 주세요.");
  }
  return data.available_threads;
};

export const consumeFitReportThread = async (
  userId: string,
  idempotencyKey: string,
  fitAnalysisResultId: string
): Promise<FitReportThreadConsumption> => {
  const { data, error } = await supabase
    .rpc("consume_fit_report_thread", {
      p_user_id: userId,
      p_idempotency_key: idempotencyKey,
      p_fit_analysis_result_id: fitAnalysisResultId
    })
    .single<ThreadConsumptionRow>();
  if (error?.code === "23505") throw createHttpError(409, "이미 다른 리포트에 사용된 요청이에요.");
  if (error || !data) throw createHttpError(500, "Failed to consume report thread");
  if (data.status === "insufficient") {
    throw createHttpError(402, "실타래가 부족해요. 충전 후 다시 시도해 주세요.");
  }
  return {
    availableThreads: data.available_threads,
    status: data.status
  };
};

export const findFitAnalysisThreadConsumption = async (
  userId: string,
  idempotencyKey: string
): Promise<string | null> => {
  const { data, error } = await supabase
    .from("thread_ledger_entries")
    .select("fit_analysis_result_id")
    .eq("user_id", userId)
    .eq("idempotency_key", idempotencyKey)
    .eq("reason", "fit_analysis")
    .limit(1)
    .returns<ThreadLedgerRow[]>();
  if (error) throw createHttpError(500, "Failed to check analysis request state");
  return data?.[0]?.fit_analysis_result_id ?? null;
};

export const createFitAnalysisAndConsumeThread = async (
  userId: string,
  idempotencyKey: string,
  prepared: PreparedFitRecommendation["persistence"]
): Promise<{
  status: AtomicFitAnalysisRow["status"];
  fitAnalysisResultId: string | null;
  availableThreads: number;
}> => {
  const { data, error } = await supabase
    .rpc("create_fit_analysis_result_and_consume_thread", {
      p_user_id: userId,
      p_idempotency_key: idempotencyKey,
      p_result: prepared
    })
    .single<AtomicFitAnalysisRow>();
  if (error || !data) throw createHttpError(500, "Failed to save fit analysis and consume thread");
  return {
    status: data.status,
    fitAnalysisResultId: data.fit_analysis_result_id,
    availableThreads: data.available_threads
  };
};
