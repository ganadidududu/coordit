import express, { type RequestHandler } from "express";
import type { Server } from "node:http";
import { afterEach, describe, expect, it, vi } from "vitest";
import { garmentLandmarksRouter, forwardLandmarks, type LandmarkForward } from "./garment-landmarks.gateway";
import { errorMiddleware } from "../../middleware/error.middleware";

let server: Server | undefined;
afterEach(async () => {
  vi.unstubAllEnvs();
  if (server) await new Promise<void>((resolve, reject) => server?.close(error => error ? reject(error) : resolve()));
});
const authenticate: RequestHandler = (req, res, next) => {
  if (req.headers.authorization !== "Bearer user-session") { res.sendStatus(401); return; }
  next();
};
const input = { image_base64: "cGhvdG8=", processing_consent: true, training_consent: false } as const;
async function start(forward: LandmarkForward): Promise<string> {
  const app = express();
  app.use("/garment-landmarks", garmentLandmarksRouter(authenticate, forward));
  app.get("/existing-fit", (_req, res) => { res.json({ ok: true }); });
  app.use(errorMiddleware);
  server = app.listen(0, "127.0.0.1");
  await new Promise<void>(resolve => server?.once("listening", resolve));
  const address = server.address();
  if (!address || typeof address === "string") throw new Error("No test listener");
  return `http://127.0.0.1:${address.port}`;
}
const headers = { "content-type": "application/json", authorization: "Bearer user-session" };
describe("isolated garment inference gateway", () => {
  it("is disabled by default and cannot enable research in production", async () => {
    vi.stubEnv("COORDIT_LANDMARKS_RESEARCH_ENABLED", "false");
    await expect(forwardLandmarks(input)).rejects.toMatchObject({ statusCode: 503 });
    vi.stubEnv("COORDIT_LANDMARKS_RESEARCH_ENABLED", "true");
    vi.stubEnv("NODE_ENV", "production");
    await expect(forwardLandmarks(input)).rejects.toMatchObject({ statusCode: 503 });
  });
  it("requires a user session and explicit processing consent; refuses training consent", async () => {
    const forward = vi.fn<LandmarkForward>();
    const base = await start(forward);
    expect((await fetch(`${base}/garment-landmarks`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(input) })).status).toBe(401);
    for (const payload of [{ ...input, processing_consent: false }, { ...input, training_consent: true }, { ...input, endpoint: "https://untrusted.invalid" }]) {
      expect((await fetch(`${base}/garment-landmarks`, { method: "POST", headers, body: JSON.stringify(payload) })).status).toBe(400);
    }
    expect(forward).not.toHaveBeenCalled();
  });
  it("contains upstream errors and leaves existing analysis routes working", async () => {
    const forward = vi.fn<LandmarkForward>().mockRejectedValue(new Error("private token must not escape"));
    const base = await start(forward);
    const response = await fetch(`${base}/garment-landmarks`, { method: "POST", headers, body: JSON.stringify(input) });
    expect(response.status).toBe(503);
    expect(await response.text()).not.toContain("private token");
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect((await fetch(`${base}/existing-fit`)).status).toBe(200);
    expect(forward).toHaveBeenCalledWith(input);
  });
  it("uses only the private service credential and rejects upstream attempts to claim deployment approval", async () => {
    const upstream = express();
    upstream.use(express.json());
    let approved = false;
    let credential: string | undefined;
    upstream.post("/v1/landmarks", (req, res) => {
      credential = req.headers.authorization;
      res.json({ schema_version: 1, status: "failed", reason: "test", model_version: "v2",
        coordinate_system: "upright_rgb_normalized_top_left", method: "development_landmarks", category: "skirt",
        category_confidence: .9, confidence_calibrated: false, image_quality: "unverified", width: 100, height: 100,
        landmarks: [], segmentation_polygon: [], segmentation_mask_base64: "", segmentation_mask_width: 64,
        segmentation_mask_height: 64, centimeter_values: {}, deployment_approved: approved });
    });
    const service = upstream.listen(0, "127.0.0.1");
    await new Promise<void>(resolve => service.once("listening", resolve));
    try {
      const address = service.address();
      if (!address || typeof address === "string") throw new Error("No test upstream");
      vi.stubEnv("NODE_ENV", "test");
      vi.stubEnv("COORDIT_LANDMARKS_RESEARCH_ENABLED", "true");
      vi.stubEnv("COORDIT_ML_URL", `http://127.0.0.1:${address.port}/v1/landmarks`);
      vi.stubEnv("COORDIT_ML_API_TOKEN", "private-service-credential-at-least-32-chars");
      const base = await start(forwardLandmarks);
      const response = await fetch(`${base}/garment-landmarks`, { method: "POST", headers, body: JSON.stringify(input) });
      expect(response.status).toBe(200);
      expect(credential).toBe("Bearer private-service-credential-at-least-32-chars");
      approved = true;
      expect((await fetch(`${base}/garment-landmarks`, { method: "POST", headers, body: JSON.stringify(input) })).status).toBe(503);
    } finally { await new Promise<void>(resolve => service.close(() => resolve())); }
  });
  it("rejects oversized authenticated images before forwarding", async () => {
    const forward = vi.fn<LandmarkForward>();
    const base = await start(forward);
    const response = await fetch(`${base}/garment-landmarks`, { method: "POST", headers,
      body: JSON.stringify({ ...input, image_base64: "a".repeat(4_100_001) }) });
    expect(response.status).toBe(413);
    expect(forward).not.toHaveBeenCalled();
  });
});
