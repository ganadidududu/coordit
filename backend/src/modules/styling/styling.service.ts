import Anthropic from "@anthropic-ai/sdk";
import { supabase } from "../../config/supabase";
import { env } from "../../config/env";
import { createHttpError } from "../../shared/utils/http-error";
import type {
  ClosetItemContext,
  GeneratedLook,
  GenerateStylingInput,
  StylingLookRow,
} from "./styling.types";

const getAnthropic = () => {
  if (!env.anthropicApiKey) throw createHttpError(503, "AI styling is not configured on this server");
  return new Anthropic({ apiKey: env.anthropicApiKey });
};

// ─── Generate ─────────────────────────────────────────────────────────

const SYSTEM_PROMPT = `You are Coordit's AI stylist. Given a user's wardrobe and a TPO prompt, create 3 outfit recommendations.

Return ONLY a valid JSON array (no markdown, no explanation) with this exact shape:
[
  {
    "name": "English look name (2-3 words)",
    "name_ko": "Korean look name",
    "mood": "short mood label (e.g. 비즈니스 · 비 예보)",
    "palette": ["#hex1", "#hex2", "#hex3"],
    "ai_reasoning": "2-3 sentence Korean explanation of why these items work together for the occasion",
    "fit_score": 88,
    "item_ids": ["uuid1", "uuid2"]
  }
]

Rules:
- palette must be 3 hex colors that reflect the overall look
- fit_score is 70–98 (higher = better match for the TPO)
- item_ids must reference actual IDs from the wardrobe provided
- Select 2–4 items per look that form a complete outfit
- If wardrobe is empty, create looks with empty item_ids and use generic reasoning`;

export const generateStylingLooks = async ({
  userId,
  prompt,
  closetItems,
}: GenerateStylingInput): Promise<{ looks: GeneratedLook[]; closetItems: ClosetItemContext[] }> => {
  const wardrobeText =
    closetItems.length > 0
      ? closetItems
          .map(
            (i) =>
              `- id: ${i.id}, name: "${i.name}", category: ${i.category}${i.brand ? `, brand: ${i.brand}` : ""}${i.size_label ? `, size: ${i.size_label}` : ""}`
          )
          .join("\n")
      : "(no items in wardrobe)";

  const userMessage = `TPO 컨텍스트: "${prompt}"\n\nWardrobe:\n${wardrobeText}`;

  const anthropic = getAnthropic();
  const message = await anthropic.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 1024,
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: userMessage }],
  });

  const raw = message.content[0].type === "text" ? message.content[0].text.trim() : "[]";

  let looks: GeneratedLook[];
  try {
    looks = JSON.parse(raw) as GeneratedLook[];
    if (!Array.isArray(looks)) throw new Error("not an array");
  } catch {
    throw createHttpError(500, "AI returned an unexpected response format");
  }

  const validItemIds = new Set(closetItems.map((i) => i.id));
  const sanitized = looks.map((look) => ({
    ...look,
    item_ids: Array.isArray(look.item_ids)
      ? look.item_ids.filter((id) => typeof id === "string" && validItemIds.has(id))
      : [],
    fit_score: Number.isFinite(Number(look.fit_score)) ? Number(look.fit_score) : 85,
    palette: Array.isArray(look.palette) ? look.palette.slice(0, 3) : ["#8F6F45", "#F5F0E6", "#2D2A27"],
  }));

  return { looks: sanitized, closetItems };
};

// ─── Save ─────────────────────────────────────────────────────────────

export const saveStylingLook = async (
  userId: string,
  lookId: string
): Promise<StylingLookRow> => {
  const { data, error } = await supabase
    .from("styling_looks")
    .select("*")
    .eq("id", lookId)
    .eq("user_id", userId)
    .single<StylingLookRow>();

  if (error || !data) throw createHttpError(404, "Styling look not found");
  return data;
};

export const createStylingLook = async (
  userId: string,
  look: GeneratedLook,
  prompt: string
): Promise<StylingLookRow> => {
  const { data, error } = await supabase
    .from("styling_looks")
    .insert({
      user_id: userId,
      name: look.name,
      name_ko: look.name_ko,
      mood: look.mood,
      palette: look.palette,
      ai_reasoning: look.ai_reasoning,
      fit_score: look.fit_score ?? null,
      item_ids: look.item_ids,
      prompt,
    })
    .select("*")
    .single<StylingLookRow>();

  if (error || !data) throw createHttpError(500, "Failed to save styling look");
  return data;
};

// ─── List saved ───────────────────────────────────────────────────────

export const listSavedStylingLooks = async (userId: string): Promise<StylingLookRow[]> => {
  const { data, error } = await supabase
    .from("styling_looks")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(20);

  if (error) throw createHttpError(500, "Failed to load styling looks");
  return (data ?? []) as StylingLookRow[];
};
