import { supabase } from "../../config/supabase";
import { createHttpError } from "../../shared/utils/http-error";

export const listLogsForUser = async (userId: string) => {
  const { data, error } = await supabase
    .from("recommendation_logs")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
  if (error) throw createHttpError(500, "Failed to load recommendation logs");
  return data ?? [];
};

export const markLogClicked = async (userId: string, id: string) => {
  const { data, error } = await supabase
    .from("recommendation_logs")
    .update({ clicked_at: new Date().toISOString(), event_type: "clicked" })
    .eq("user_id", userId)
    .eq("id", id)
    .select("*")
    .single();
  if (error || !data) throw createHttpError(500, "Failed to mark recommendation as clicked");
  return data;
};

export const markLogPurchased = async (userId: string, id: string) => {
  const { data, error } = await supabase
    .from("recommendation_logs")
    .update({ purchased_at: new Date().toISOString(), event_type: "purchased" })
    .eq("user_id", userId)
    .eq("id", id)
    .select("*")
    .single();
  if (error || !data) throw createHttpError(500, "Failed to mark recommendation as purchased");
  return data;
};
