import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ paid: vi.fn(), prepare: vi.fn(), stored: vi.fn(), replay: vi.fn(), balance: vi.fn(), upsert: vi.fn() }));
vi.mock("../../config/supabase", () => ({ supabase: { from: () => ({ upsert: mocks.upsert }) } }));
vi.mock("../fit-report/fit-report.comparison-bundle", async (importOriginal) => {
  const original = await importOriginal<typeof import("../fit-report/fit-report.comparison-bundle")>();
  return { ...original, loadPaidComparisonBundle: mocks.paid };
});
vi.mock("./fit.service", () => ({ prepareFitRecommendation: mocks.prepare, getFitAnalysisResult: mocks.stored, replayFitRecommendation: mocks.replay }));
vi.mock("../thread-wallet/thread-wallet.service", () => ({ getThreadBalance: mocks.balance }));

import { remeasureCameraComparison } from "./fit.camera-remeasurement";

const original = { user_id: "owner", external_product_id: "product", reference_clothing_id: "reference", result_details: { referenceClothingIds: ["reference"] } };
const request = { userId: "owner", bundleAnalysisId: "paid-bundle", idempotencyKey: "retry-key", externalProductId: "product", referenceClothingIds: ["reference"] };

describe("camera remeasurement", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    mocks.paid.mockResolvedValue(original);
    mocks.balance.mockResolvedValue(0);
    mocks.upsert.mockResolvedValue({ error: null });
    mocks.stored.mockResolvedValue({ ...original, result_details: { ...original.result_details, cameraComparisonBundleAnalysisId: "paid-bundle" } });
    mocks.prepare.mockResolvedValue({ persistence: {
      referenceClothingId: "reference", externalProductId: "product", recommendedExternalProductSizeId: "size",
      recommendedSizeLabel: "M", fitScore: 90, fitLabel: "good_fit", fitComment: "measured", weightedFitDistance: 1,
      algorithmVersion: "current", recommendationConfidence: "medium", resultDetails: { referenceClothingIds: ["reference"] }
    } });
    mocks.replay.mockReturnValue({ fitAnalysisResultId: "new-result", fitScore: 90 });
  });

  it("recomputes at zero balance and preserves the same row on a repeated request", async () => {
    expect(await remeasureCameraComparison(request)).toMatchObject({ fitScore: 90, availableThreads: 0 });
    const first = mocks.upsert.mock.calls[0]?.[0] as Record<string, unknown>;
    await remeasureCameraComparison(request);
    expect(mocks.upsert.mock.calls[1]?.[0]).toEqual(first);
    expect(mocks.upsert).toHaveBeenCalledWith(expect.objectContaining({ user_id: "owner" }), { onConflict: "id", ignoreDuplicates: true });
    await remeasureCameraComparison({ ...request, idempotencyKey: "another-key" });
    expect(mocks.upsert.mock.calls[2]?.[0]?.id).not.toEqual(first.id);
  });

  it("rejects a different product or reference before computation or insertion", async () => {
    await expect(remeasureCameraComparison({ ...request, externalProductId: "other" })).rejects.toThrow("같은 상품과 기준 의류");
    await expect(remeasureCameraComparison({ ...request, referenceClothingIds: ["other"] })).rejects.toThrow("같은 상품과 기준 의류");
    expect(mocks.prepare).not.toHaveBeenCalled();
    expect(mocks.upsert).not.toHaveBeenCalled();
  });

  it("rejects unpaid bundles and an idempotency collision with another bundle", async () => {
    mocks.paid.mockRejectedValueOnce(new Error("unpaid"));
    await expect(remeasureCameraComparison(request)).rejects.toThrow("unpaid");
    expect(mocks.upsert).not.toHaveBeenCalled();
    mocks.stored.mockResolvedValueOnce(original);
    await expect(remeasureCameraComparison(request)).rejects.toThrow("다른 분석 묶음");
  });
});
