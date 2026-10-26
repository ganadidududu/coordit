import { supabase } from "../../config/supabase";
import { createHttpError } from "../../shared/utils/http-error";

export const requireThreadPurchaseMember = async (userId: string): Promise<void> => {
  const { error } = await supabase.rpc("assert_thread_purchase_member", { p_user_id: userId });
  if (error?.code === "42501") {
    throw createHttpError(403, "실타래를 구매하려면 먼저 계정을 연결해 주세요.");
  }
  if (error) throw createHttpError(503, "구매 계정을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.");
};
