import { load } from "cheerio";

import { PRODUCT_FACT_KINDS, type ProductFact, type ProductFactKind } from "../product-import.types";

const labels: Readonly<Record<ProductFactKind, RegExp>> = {
  material: /^(소재|제품소재|제품의소재|혼용률|섬유혼용률|겉감|material|materials|fabric|composition)$/i,
  fit: /^(핏|실루엣|fit|fittype|silhouette)$/i,
  lining: /^(안감|lining)$/i,
  stretch: /^(신축성|신축|stretch|elasticity)$/i,
  thickness: /^(두께|두께감|thickness)$/i,
  sheerness: /^(비침|비침정도|sheerness|transparency)$/i,
  care: /^(세탁|세탁방법|세탁방법및취급시주의사항|취급주의사항|관리방법|care|washing|careinstructions)$/i,
  model: /^(모델|모델정보|모델착용|모델착용정보|model|modelinfo)$/i
};
const clean = (value: string): string => value.replace(/\s+/g, " ").trim();
const record = (value: unknown): value is Record<string, unknown> => typeof value === "object" && value !== null && !Array.isArray(value);

export const factFromLabel = (label: string, raw: unknown): ProductFact | null => {
  const kind = PRODUCT_FACT_KINDS.find((key) => labels[key].test(label.replace(/[\s_():·]/g, "")));
  if (!kind || typeof raw !== "string") return null;
  const value = clean(load(raw).text());
  if (!value || value.length > 80 || /https?:|@|확인불가|상세\s*(페이지|설명)\s*(참고|참조)|해당\s*없음|정보\s*없음/i.test(value)) return null;
  if (kind === "model") {
    // Keep garment-relevant measurements only; never reproduce a model's identity.
    const height = value.match(/\b(1[4-9]\d|20\d)\s*cm\b/i)?.[1];
    const size = value.match(/(?:착용\s*(?:사이즈)?|size)\s*[:：]?\s*([a-z0-9-]{1,8})(?:\s|$|사이즈)/i)?.[1]
      ?? value.match(/\b([a-z0-9-]{1,8})\s*(?:사이즈\s*)?착용/i)?.[1];
    return height && size ? { kind, value: `${height}cm · ${size.toUpperCase()} 착용` } : null;
  }
  return { kind, value };
};

type ProductFactRecord = { readonly name: string | null; readonly productId: string | null; readonly facts: readonly ProductFact[] };
type ProductPageIdentity = { readonly pageName: string | null; readonly productId: string | null };
type ProductFactIdentity = ProductPageIdentity & { readonly name: string };

export const matchesProductPage = (product: ProductFactRecord | null, identity: ProductPageIdentity): boolean => {
  if (!product?.name) return false;
  const samePageName = identity.pageName !== null && clean(product.name) === clean(identity.pageName);
  const sameId = identity.productId !== null && product.productId === identity.productId;
  return samePageName || sameId;
};

export const factsForIdentity = (product: ProductFactRecord | null, identity: ProductFactIdentity): readonly ProductFact[] =>
  product?.name === identity.name && matchesProductPage(product, identity) ? product.facts : [];

export const mergeProductFacts = (...sources: readonly (readonly ProductFact[])[]): readonly ProductFact[] => {
  const all = sources.flat();
  return PRODUCT_FACT_KINDS.flatMap((kind) => {
    const values = [...new Set(all.filter((fact) => fact.kind === kind).map((fact) => fact.value))];
    const value = values[0];
    return values.length === 1 && value ? [{ kind, value }] : [];
  });
};

export const factsFromDescription = (description: string): readonly ProductFact[] => {
  const text = load(description.replace(/<br\s*\/?\s*>|<\/p>|<\/li>/gi, "\n")).text();
  return text.split(/[\n;]+/).slice(0, 100).flatMap((line) => {
    const match = line.match(/^\s*([^:：]{1,25})\s*[:：]\s*(.+)$/);
    const fact = match?.[1] && match[2] ? factFromLabel(match[1], match[2]) : null;
    return fact ? [fact] : [];
  });
};

export const factsFromRecord = (product: Readonly<Record<string, unknown>>): readonly ProductFact[] => {
  const direct = Object.entries(product).flatMap(([key, value]) => {
    const fact = factFromLabel(key, Array.isArray(value) && value.every((item) => typeof item === "string") ? value.join(", ") : value);
    return fact ? [fact] : [];
  });
  const properties = Array.isArray(product.additionalProperty) ? product.additionalProperty : [product.additionalProperty];
  const additional = properties.flatMap((property) => {
    const fact = record(property) && typeof property.name === "string" ? factFromLabel(property.name, property.value) : null;
    return fact ? [fact] : [];
  });
  const nested = ["attributes", "specifications", "productInfo", "productInformation", "information", "notice"].flatMap((key) => {
    const value = product[key];
    const entries = Array.isArray(value) ? value.slice(0, 100) : [value];
    return entries.flatMap((item): readonly ProductFact[] => {
      if (!record(item)) return [];
      const label = item.label ?? item.title ?? item.name;
      const labeled = typeof label === "string" ? factFromLabel(label, item.value ?? item.content) : null;
      const fields = Object.entries(item).flatMap(([name, content]) => {
        const fact = factFromLabel(name, content);
        return fact ? [fact] : [];
      });
      return [...fields, ...(labeled ? [labeled] : [])];
    });
  });
  const description = typeof product.description === "string" ? factsFromDescription(product.description) : [];
  return mergeProductFacts(direct, additional, nested, description);
};

export const factsFromHtml = (html: string, productName: string): readonly ProductFact[] => {
  const $ = load(html);
  $("script,style,nav,footer,[itemprop='review'],[class*='review'],[id*='review'],[class*='recommend'],[id*='recommend'],[class*='related'],[id*='related']").remove();
  const productScopes = $("[itemscope][itemtype]").filter((_index, element) => /(?:\/|^)Product(?:\s|$)/.test($(element).attr("itemtype") ?? ""));
  const matching = productScopes.filter((_index, element) => {
    const name = $(element).find("[itemprop='name']").filter((_unused, item) => $(item).closest("[itemscope][itemtype]")[0] === element).first().text();
    return clean(name) === clean(productName);
  });
  // Never borrow attributes from a sibling/nested product, even without a related/review class.
  productScopes.not(matching).remove();
  const pageName = clean($("meta[property='og:title']").attr("content") ?? $("h1").first().text());
  const explicit = $("#product-detail,#product-details,[data-testid='product-details'],#product-description,.product-description,[itemprop='description']");
  const scopes = productScopes.length > 0 ? matching : pageName === clean(productName) ? explicit : $([]);
  const scoped = load(scopes.toArray().map((element) => $.html(element)).join("\n"));
  const facts: ProductFact[] = [];
  scoped("tr").each((_index, row) => {
    const cells = scoped(row).children("th,td");
    if (cells.length !== 2) return;
    const fact = factFromLabel(cells.eq(0).text(), cells.eq(1).text());
    if (fact) facts.push(fact);
  });
  scoped("dt").each((_index, element) => {
    const fact = factFromLabel(scoped(element).text(), scoped(element).next("dd").text());
    if (fact) facts.push(fact);
  });
  scoped("[itemprop='description'],[data-testid='product-description'],#product-description,.product-description").each((_index, element) => {
    facts.push(...factsFromDescription(scoped(element).html() ?? ""));
  });
  return mergeProductFacts(facts);
};
