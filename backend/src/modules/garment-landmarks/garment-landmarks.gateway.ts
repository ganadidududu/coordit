import express, { Router, type RequestHandler } from "express";
import ky from "ky";
import { z } from "zod";
import { createHttpError } from "../../shared/utils/http-error";

const inputSchema = z.object({
  image_base64: z.string().min(4).max(4_000_000).regex(/^[A-Za-z0-9+/]+={0,2}$/),
  processing_consent: z.literal(true),
  training_consent: z.literal(false),
}).strict();
const landmarkSchema = z.object({
  landmark_type: z.string().min(1).max(48), x: z.number().min(0).max(1), y: z.number().min(0).max(1),
  visibility: z.union([z.literal(0), z.literal(1), z.literal(2)]), confidence: z.number().min(0).max(1),
  source: z.string().max(80), correction_status: z.string().max(32),
});
const responseSchema = z.object({
  schema_version: z.literal(1), status: z.enum(["needs_calibration", "failed"]), reason: z.string(),
  model_version: z.string().min(1), coordinate_system: z.literal("upright_rgb_normalized_top_left"),
  method: z.literal("development_landmarks"), category: z.string(), category_confidence: z.number().min(0).max(1),
  confidence_calibrated: z.literal(false), image_quality: z.literal("unverified"),
  width: z.number().int().positive(), height: z.number().int().positive(),
  landmarks: z.array(landmarkSchema).max(32), segmentation_polygon: z.array(z.array(z.number())).max(4096),
  segmentation_mask_base64: z.string().max(300_000), segmentation_mask_width: z.number().int().positive().max(1024),
  segmentation_mask_height: z.number().int().positive().max(1024), centimeter_values: z.record(z.string(), z.number()).refine(v => Object.keys(v).length === 0),
  deployment_approved: z.literal(false),
}).strict();
type LandmarkInput = z.infer<typeof inputSchema>;
type LandmarkResponse = z.infer<typeof responseSchema>;
export type LandmarkForward = (input: LandmarkInput) => Promise<LandmarkResponse>;

/** Only server configuration selects the upstream. User bearer credentials never leave this backend. */
export const forwardLandmarks: LandmarkForward = async input => {
  const endpoint = process.env.COORDIT_ML_URL;
  const secret = process.env.COORDIT_ML_API_TOKEN;
  if (process.env.NODE_ENV === "production" || process.env.COORDIT_LANDMARKS_RESEARCH_ENABLED !== "true" ||
      !endpoint || !secret || secret.length < 32) throw createHttpError(503, "landmarks_disabled");
  const url = new URL(endpoint);
  const local = url.protocol === "http:" && ["127.0.0.1", "localhost", "[::1]"].includes(url.hostname);
  if (url.protocol !== "https:" && !local) throw createHttpError(503, "landmarks_transport_unavailable");
  if (url.username || url.password) throw createHttpError(503, "landmarks_configuration_invalid");
  const response = await ky.post(url, { json: input, headers: { authorization: `Bearer ${secret}` },
    signal: AbortSignal.timeout(8_000), timeout: 8_000, retry: 0, redirect: "error", throwHttpErrors: false });
  if (!response.ok || !response.body) throw createHttpError(503, "landmarks_unavailable");
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    for (;;) {
      const next = await reader.read();
      if (next.done) break;
      size += next.value.length;
      if (size > 1_000_000) throw createHttpError(503, "landmarks_response_too_large");
      chunks.push(next.value);
    }
  } finally { await reader.cancel(); }
  return responseSchema.parse(JSON.parse(Buffer.concat(chunks).toString("utf8")));
};

/** Mounted before the default JSON parser: the larger image limit affects only this authenticated route. */
export function garmentLandmarksRouter(authenticate: RequestHandler, forward: LandmarkForward = forwardLandmarks): Router {
  const router = Router();
  let active = 0;
  router.post("/", authenticate, express.json({ limit: 4_100_000 }), async (req, res, next) => {
    res.setHeader("Cache-Control", "no-store");
    const parsed = inputSchema.safeParse(req.body);
    if (!parsed.success) return next(createHttpError(400, "invalid_landmarks_or_consent"));
    if (active >= 2) return next(createHttpError(429, "landmarks_busy"));
    active++;
    try { res.json(await forward(parsed.data)); }
    catch { next(createHttpError(503, "landmarks_unavailable")); }
    finally { active--; }
  });
  return router;
}
