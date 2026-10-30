import { describe, expect, it, vi, afterEach } from "vitest";
import { factsFromHtml, factsFromRecord, factsForIdentity, mergeProductFacts } from "../crawler/product-facts";
import { extractProductFromUnknown } from "../crawler/structured-data-parser";
import { toFitLabUrlPrefill } from "../fit-lab-prefill.mapper";
import { assertCrawlAllowed, assertRobotsAllowed } from "../security/robots-policy";

vi.mock("../security/url-validator", () => ({ assertPublicUrl: vi.fn(async () => undefined) }));
afterEach(() => vi.unstubAllGlobals());

describe("confirmed product facts", () => {
  it("extracts labeled facts without inventing fabric properties or a default fit", () => {
    const facts = factsFromRecord({ material: "면 100%", additionalProperty: [{ name: "안감", value: "없음" }], review: { fit: "슬림핏" } });
    expect(facts).toEqual([{ kind: "material", value: "면 100%" }, { kind: "lining", value: "없음" }]);
    expect(factsFromRecord({ name: "cotton shirt", description: "가볍고 멋진 상품입니다." })).toEqual([]);
  });
  it("handles structured attributes and strips model identities", () => {
    const product = extractProductFromUnknown({ "@type": "Product", name: "리넨 셔츠", material: "리넨 55%, 면 45%", specifications: [{ title: "핏", content: "루즈핏" }, { label: "모델 정보", value: "홍길동 178cm / M 사이즈 착용" }] });
    expect(product?.facts).toEqual([{ kind: "material", value: "리넨 55%, 면 45%" }, { kind: "fit", value: "루즈핏" }, { kind: "model", value: "178cm · M 착용" }]);
  });
  it("excludes reviews and related product metadata while reading product tables and description labels", () => {
    const facts = factsFromHtml(`<meta property="og:title" content="검증 상품"><div id="product-detail"><section class="reviews"><table><tr><th>핏</th><td>슬림핏</td></tr></table></section><section class="related"><dl><dt>소재</dt><dd>가죽</dd></dl></section><table><tr><th>제품 소재</th><td>면 100%</td></tr></table><dl><dt>안감</dt><dd>없음</dd></dl><div itemprop="description">핏: 오버핏 아님<br>세탁방법: 단독 손세탁</div></div>`, "검증 상품");
    expect(facts).toEqual([{ kind: "material", value: "면 100%" }, { kind: "fit", value: "오버핏 아님" }, { kind: "lining", value: "없음" }, { kind: "care", value: "단독 손세탁" }]);
  });
  it("requires page-name or product-ID ownership before using network/structured facts", () => {
    const product = { name: "함께 본 재킷", productId: null, facts: factsFromRecord({ material: "가죽" }) };
    expect(factsForIdentity(product, { name: product.name, pageName: "면 셔츠", productId: "1234" })).toEqual([]);
    expect(factsForIdentity({ ...product, name: "면 셔츠" }, { name: "면 셔츠", pageName: "면 셔츠", productId: "1234" })).toHaveLength(1);
    expect(factsForIdentity({ ...product, productId: "1234" }, { name: product.name, pageName: null, productId: "1234" })).toHaveLength(1);
  });
  it("never attributes sibling or nested Product facts to the primary item", () => {
    const sibling = `<section itemscope itemtype="https://schema.org/Product"><h1 itemprop="name">면 셔츠</h1></section><aside itemscope itemtype="https://schema.org/Product"><h2 itemprop="name">가죽 재킷</h2><table><tr><th>소재</th><td>양가죽 100%</td></tr></table></aside>`;
    expect(factsFromHtml(sibling, "면 셔츠")).toEqual([]);
    expect(factsFromHtml(`<h1>면 셔츠</h1><table><tr><th>소재</th><td>양가죽 100%</td></tr></table>`, "면 셔츠")).toEqual([]);
    const primary = `<section itemscope itemtype="https://schema.org/Product"><h1 itemprop="name">면 셔츠</h1><dl><dt>소재</dt><dd>면 100%</dd></dl>${sibling}</section>`;
    expect(factsFromHtml(primary, "면 셔츠")).toEqual([{ kind: "material", value: "면 100%" }]);
  });
  it("omits conflicting values, paragraphs and unlabelled/private content", () => {
    expect(mergeProductFacts(factsFromRecord({ fit: "루즈핏" }), factsFromRecord({ fit: "슬림핏" }))).toEqual([]);
    expect(factsFromRecord({ material: "a".repeat(81), model: "홍길동 instagram@example.com 178cm 착용 M", care: "상세 페이지 참고" })).toEqual([]);
    expect(extractProductFromUnknown({ reviews: [{ productName: "리뷰 상품", material: "면" }] })).toBeNull();
  });
  it("passes facts and final source provenance through the actual URL prefill mapper, preserving size-only compatibility", () => {
    const base = { partial: false, source: { site: "generic", url: "https://shop.example/final", crawledAt: "2026-10-30T03:00:00.000Z" }, product: { name: "리넨 셔츠", brand: null, normalizedCategory: "SHIRT", facts: factsFromRecord({ material: "리넨 55%, 면 45%", fit: "루즈핏" }) }, sizeChart: { normalizedRows: [] } } as const;
    const result = toFitLabUrlPrefill(base);
    expect(result.productFacts).toEqual({ productName: base.product.name, sourceUrl: base.source.url, capturedAt: base.source.crawledAt, items: base.product.facts });
    expect(result.fitType).toBe("regular"); // Existing paid analysis default is never a seller fact.
    expect(toFitLabUrlPrefill({ ...base, product: { ...base.product, facts: [] } })).not.toHaveProperty("productFacts");
  });
});

describe("crawler site policy", () => {
  it("respects wildcard denials and the more specific allowed path", () => {
    expect(() => assertRobotsAllowed(new URL("https://shop.example/private/1"), "User-agent: *\nDisallow: /private/\nAllow: /private/public/")).toThrow();
    expect(() => assertRobotsAllowed(new URL("https://shop.example/private/public/1"), "User-agent: *\nDisallow: /private/\nAllow: /private/public/")).not.toThrow();
  });
  it("applies redirected robots rules to the original product origin", async () => {
    const fetch = vi.fn().mockResolvedValueOnce(new Response(null, { status: 302, headers: { location: "https://policy.example/robots.txt" } })).mockResolvedValueOnce(new Response("User-agent: *\nDisallow: /"));
    vi.stubGlobal("fetch", fetch);
    await expect(assertCrawlAllowed(new URL("https://redirect-policy.example/product"))).rejects.toMatchObject({ code: "SITE_BLOCKED_REQUEST" });
    expect(fetch).toHaveBeenCalledTimes(2);
  });
  it("does not interpret an HTTP 200 HTML challenge as permission", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("<!doctype html><html><body>CAPTCHA</body></html>", { status: 200 })));
    await expect(assertCrawlAllowed(new URL("https://challenge-policy.example/product"))).rejects.toMatchObject({ code: "SITE_BLOCKED_REQUEST" });
  });
  it("fails closed on unavailable robots and enforces declared crawl delays", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 503 })));
    await expect(assertCrawlAllowed(new URL("https://unavailable-policy.example/product"))).rejects.toMatchObject({ code: "SITE_BLOCKED_REQUEST" });
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("User-agent: *\nCrawl-delay: 60")));
    await assertCrawlAllowed(new URL("https://delayed-policy.example/1"));
    await expect(assertCrawlAllowed(new URL("https://delayed-policy.example/2"))).rejects.toMatchObject({ code: "RATE_LIMITED" });
  });
});
