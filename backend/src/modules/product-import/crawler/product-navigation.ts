import { errors as playwrightErrors } from "playwright";
import { env } from "../../../config/env";
import type { ProductSite } from "../product-import.types";
export const productIdFromUrl = (url: URL): string | null => {
  const pathSegments = url.pathname.split("/");
  for (let index = pathSegments.length - 1; index >= 0; index -= 1) {
    const value = pathSegments[index];
    if (value && /^\d{4,}$/.test(value)) return value;
  }

  const productIDParameterNames = new Set([
    "productid", "product_id", "productno", "product_no",
    "goodsid", "goods_id", "goodsno", "goods_no"
  ]);
  for (const [name, value] of url.searchParams) {
    if (productIDParameterNames.has(name.toLowerCase()) && /^\d{4,}$/.test(value)) {
      return value;
    }
  }
  return null;
};

export const fetchMusinsaSizeCandidate = async (
  page: import("playwright").Page,
  productUrl: URL
): Promise<unknown | null> => {
  const productId = productIdFromUrl(productUrl);
  if (!productId) return null;
  try {
    const sizeUrl = new URL(`https://goods-detail.musinsa.com/api2/goods/${productId}/actual-size`);
    const response = await page.context().request.get(
      sizeUrl.href,
      { timeout: Math.min(env.crawlTimeoutMs, 10_000), maxRedirects: 0 }
    );
    if (!response.ok()) return null;
    return await response.json();
  } catch {
    return null;
  }
};

export const navigationWaitUntil = (site: ProductSite): "commit" | "domcontentloaded" =>
  site === "musinsa" ? "commit" : "domcontentloaded";

export const shouldRevealSizeContent = (site: ProductSite): boolean => site !== "musinsa";

export const effectiveCrawlerSite = (requestedSite: ProductSite, resolvedUrl: URL): ProductSite => {
  if (requestedSite !== "generic") return requestedSite;
  const hostname = resolvedUrl.hostname.toLowerCase();
  const isMusinsaProduct = (hostname === "musinsa.com" || hostname.endsWith(".musinsa.com"))
    && resolvedUrl.pathname.includes("/products/");
  return isMusinsaProduct ? "musinsa" : requestedSite;
};

export const revealSizeContent = async (page: import("playwright").Page): Promise<void> => {
  const controls = page.locator("button:visible, [role='button']:visible, [role='tab']:visible, a:visible").filter({
    hasText: /사이즈\s*(정보|표|가이드)?|실측|상품\s*정보|상세\s*정보|SIZE\s*(INFO|GUIDE|CHART)?|MEASUREMENTS?/i
  });
  try {
    await controls.first().waitFor({ state: "visible", timeout: Math.min(env.pageLoadTimeoutMs, 15_000) });
  } catch (error) {
    if (error instanceof playwrightErrors.TimeoutError) return;
    throw error;
  }
  const count = Math.min(await controls.count(), 3);
  for (let index = 0; index < count; index += 1) {
    const control = controls.nth(index);
    if (await control.isVisible()) {
      try {
        await control.click({ timeout: 1_000 });
      } catch (error) {
        if (!(error instanceof playwrightErrors.TimeoutError)) throw error;
      }
    }
  }
  try {
    await page.locator("table:visible").first().waitFor({ state: "visible", timeout: 5_000 });
  } catch (error) {
    if (!(error instanceof playwrightErrors.TimeoutError)) throw error;
  }
};
