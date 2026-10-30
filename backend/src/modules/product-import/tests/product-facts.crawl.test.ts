import { expect, it, vi } from "vitest";
import { browserManager } from "../crawler/browser-manager";
import { crawlProductPage } from "../crawler/product-page-crawler";
import { productImportPreviewSchema } from "../product-import.schemas";
import { toFitLabUrlPrefill } from "../fit-lab-prefill.mapper";

vi.mock("../security/url-validator", async (original) => ({ ...await original<typeof import("../security/url-validator")>(), assertPublicUrl: vi.fn(async () => undefined) }));

it("crawls a rendered product document through schema and mobile mapper with size and seller facts", async () => {
  const session = await browserManager.createSession();
  const html = `<html><head><meta property="og:title" content="리넨 셔츠"><script type="application/ld+json">{"@type":"Product","name":"리넨 셔츠","material":"리넨 55%, 면 45%","additionalProperty":[{"name":"핏","value":"루즈핏"}]}</script></head><body><section id="product-detail"><button>사이즈 정보</button><table><tr><th>사이즈</th><th>가슴 단면(cm)</th><th>총장</th></tr><tr><td>M</td><td>56</td><td>70</td></tr><tr><td>L</td><td>58</td><td>72</td></tr></table><dl><dt>안감</dt><dd>없음</dd><dt>모델 정보</dt><dd>178cm / M 사이즈 착용</dd></dl></section></body></html>`;
  // Page routing is a deterministic extraction fixture; independent policy tests cover real fetch decisions.
  await session.page.route("https://shop.example/**", (route) => route.fulfill({ body: html, contentType: "text/html; charset=utf-8" }));
  const create = vi.spyOn(browserManager, "createSession").mockResolvedValue(session);
  try {
    const preview = productImportPreviewSchema.parse(await crawlProductPage({ url: new URL("https://shop.example/products/linen-shirt"), includeImages: false, includeDetailImages: false, crawledAt: "2026-10-30T03:00:00.000Z" }, "generic"));
    const response = toFitLabUrlPrefill(preview);
    expect(response.sizes.map((size) => [size.sizeLabel, size.chestWidth, size.totalLength])).toEqual([["M", 56, 70], ["L", 58, 72]]);
    expect(response.productFacts?.items).toEqual([{ kind: "material", value: "리넨 55%, 면 45%" }, { kind: "fit", value: "루즈핏" }, { kind: "lining", value: "없음" }, { kind: "model", value: "178cm · M 착용" }]);
    expect(response.productFacts?.sourceUrl).toBe(response.productUrl);
  } finally { create.mockRestore(); await browserManager.close(); }
}, 20_000);
