import { afterEach, describe, expect, it, vi } from "vitest";
import { productCrawlerAdapters } from "../adapters/product-crawler-adapters";
import { ProductImportError } from "../product-import.error";
import { previewProductImport } from "../product-import.service";
import type { ProductImportPreview } from "../product-import.types";
import * as urlValidator from "../security/url-validator";

const adapterNamed = (name: string) => {
  const adapter = productCrawlerAdapters.find((candidate) => candidate.name === name);
  if (!adapter) throw new Error(`Missing adapter ${name}`);
  return adapter;
};

// Each outcome is a single JSON line so the log backend can index its fields.
const loggedFields = (call: readonly unknown[] | undefined): Record<string, unknown> => {
  expect(call).toHaveLength(1);
  return JSON.parse(String(call?.[0])) as Record<string, unknown>;
};

const request = (url: string) => ({ url, includeImages: true, includeDetailImages: false });

describe("product import outcome log", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("records the seller host and error code when the seller blocks the request", async () => {
    // Given: a seller that rejects the crawler.
    vi.spyOn(urlValidator, "assertPublicUrl").mockResolvedValue(undefined);
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const blocked = new ProductImportError("SITE_BLOCKED_REQUEST", "쇼핑몰이 페이지 요청을 차단했습니다.", true, 502);
    vi.spyOn(adapterNamed("zigzag"), "extract").mockRejectedValue(blocked);

    // When: the import is attempted with a share link carrying tracking parameters.
    const attempt = previewProductImport(
      "outcome-log-user-blocked",
      request("https://zigzag.kr/catalog/products/172202019?client_id=secret-tracking-id")
    );

    // Then: the original error still reaches the caller and one privacy-safe line is logged.
    await expect(attempt).rejects.toBe(blocked);
    expect(warn).toHaveBeenCalledTimes(1);
    const fields = loggedFields(warn.mock.calls[0]);
    expect(fields).toMatchObject({
      severity: "WARNING",
      message: "product_import_outcome",
      outcome: "failed",
      host: "zigzag.kr",
      site: "zigzag",
      code: "SITE_BLOCKED_REQUEST",
      statusCode: 502,
      retryable: true
    });
    expect(typeof fields.elapsedMs).toBe("number");
    expect(JSON.stringify(fields)).not.toContain("secret-tracking-id");
    expect(JSON.stringify(fields)).not.toContain("172202019");
  });

  it("records unexpected failures without an import error code", async () => {
    // Given: a crawler failure that is not a product import error.
    vi.spyOn(urlValidator, "assertPublicUrl").mockResolvedValue(undefined);
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    vi.spyOn(adapterNamed("29cm"), "extract").mockRejectedValue(new TypeError("boom"));

    // When / Then
    await expect(previewProductImport("outcome-log-user-unexpected", request("https://www.29cm.co.kr/products/123456")))
      .rejects.toBeInstanceOf(TypeError);
    expect(loggedFields(warn.mock.calls[0])).toMatchObject({
      outcome: "failed",
      host: "www.29cm.co.kr",
      site: "29cm",
      code: "UNEXPECTED",
      errorName: "TypeError"
    });
  });

  it("records the seller host when the import succeeds", async () => {
    // Given: a seller page that is crawled successfully.
    vi.spyOn(urlValidator, "assertPublicUrl").mockResolvedValue(undefined);
    const warn = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    const info = vi.spyOn(console, "info").mockImplementation(() => undefined);
    const preview = { success: true, partial: true } as unknown as ProductImportPreview;
    vi.spyOn(adapterNamed("musinsa"), "extract").mockResolvedValue(preview);

    // When
    const result = await previewProductImport("outcome-log-user-success", request("https://www.musinsa.com/products/5219138"));

    // Then
    expect(result).toBe(preview);
    expect(warn).not.toHaveBeenCalled();
    expect(info).toHaveBeenCalledTimes(1);
    expect(loggedFields(info.mock.calls[0])).toMatchObject({
      severity: "INFO",
      message: "product_import_outcome",
      outcome: "succeeded",
      host: "www.musinsa.com",
      site: "musinsa",
      partial: true
    });
  });
});
