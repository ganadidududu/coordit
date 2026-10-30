import { describe, expect, it, vi } from "vitest";
import { createServer } from "node:http";
import { BrowserManager, browserManager, isBrowserClosedError } from "../crawler/browser-manager";
import { crawlProductPage } from "../crawler/product-page-crawler";
import * as urlValidator from "../security/url-validator";

describe("BrowserManager", () => {
  it("opens a requested product page when a separate robots preflight is unavailable", async () => {
    // Given: a reachable product document and an unavailable policy endpoint.
    const server = createServer((_request, response) => {
      response.writeHead(200, { "Content-Type": "text/html" });
      response.end("<html><body><h1>Public product</h1></body></html>");
    });
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const address = server.address();
    if (!address || typeof address === "string") throw new Error("Missing test server address");
    const publicAddress = vi.spyOn(urlValidator, "assertPublicUrl").mockResolvedValue(undefined);
    const policyFetch = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status: 503 }));
    const manager = new BrowserManager();
    try {
      const session = await manager.createSession();
      // When: the user-requested document is opened through the actual browser route.
      const response = await session.page.goto(`http://127.0.0.1:${address.port}/products/1234`);
      // Then: the product is available without a new mandatory policy prerequisite.
      expect(response?.status()).toBe(200);
      expect(await session.page.locator("h1").textContent()).toBe("Public product");
      await session.close();
    } finally {
      await manager.close();
      publicAddress.mockRestore();
      policyFetch.mockRestore();
      await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    }
  });

  it("recognizes a target-closed context creation failure as recoverable", () => {
    expect(isBrowserClosedError(new Error("Target page, context or browser has been closed"))).toBe(true);
    expect(isBrowserClosedError(new Error("Protocol error: other failure"))).toBe(false);
  });

  it("starts a fresh browser after the cached browser closes", async () => {
    const manager = new BrowserManager();
    try {
      const firstSession = await manager.createSession();
      await firstSession.close();
      await manager.close();

      const recoveredSession = await manager.createSession();
      expect(recoveredSession.page.isClosed()).toBe(false);
      await recoveredSession.close();
    } finally {
      await manager.close();
    }
  });
});

describe("crawlProductPage", () => {
  it("converts browser session startup failures into a retryable product-import error", async () => {
    const createSession = vi.spyOn(browserManager, "createSession")
      .mockRejectedValue(new Error("Target page, context or browser has been closed"));
    try {
      await expect(crawlProductPage({
        url: new URL("https://www.musinsa.com/products/6252903"),
        includeImages: false,
        includeDetailImages: false,
        crawledAt: "2026-07-31T00:00:00.000Z"
      }, "musinsa")).rejects.toMatchObject({
        code: "PRODUCT_PAGE_NOT_ACCESSIBLE",
        message: "상품 페이지에 접근할 수 없습니다.",
        retryable: true,
        statusCode: 502
      });
    } finally {
      createSession.mockRestore();
    }
  });
});
