import robotsParser from "robots-parser";
import { env } from "../../../config/env";
import { ProductImportError } from "../product-import.error";
import { assertPublicUrl } from "./url-validator";

type RobotsPolicy = ReturnType<typeof robotsParser>;
type CachedPolicy = { readonly expiresAt: number; readonly policy: Promise<RobotsPolicy> };
const policies = new Map<string, CachedPolicy>();
const lastVisit = new Map<string, number>();
const blocked = () => new ProductImportError("SITE_BLOCKED_REQUEST", "판매처의 수집 정책을 확인할 수 없거나 자동 수집이 허용되지 않아요. 직접 입력을 이용해 주세요.", false, 422);

export const assertRobotsAllowed = (target: URL, text: string): RobotsPolicy => {
  const policy = robotsParser(new URL("/robots.txt", target).href, text);
  if (policy.isAllowed(target.href, env.crawlerUserAgent) === false) throw blocked();
  return policy;
};

const fetchPolicy = async (target: URL): Promise<RobotsPolicy> => {
  let url = new URL("/robots.txt", target);
  for (let redirects = 0; redirects <= 3; redirects += 1) {
    await assertPublicUrl(url);
    const response = await fetch(url, { redirect: "manual", headers: { "User-Agent": env.crawlerUserAgent }, signal: AbortSignal.timeout(5_000) });
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get("location");
      await response.body?.cancel();
      if (!location) throw blocked();
      url = new URL(location, url);
      continue;
    }
    if (response.status === 404 || response.status === 410) {
      await response.body?.cancel();
      return robotsParser(new URL("/robots.txt", target).href, "");
    }
    if (!response.ok || !response.body) { await response.body?.cancel(); throw blocked(); }
    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let bytes = 0;
    try {
      while (true) {
        const chunk = await reader.read();
        if (chunk.done) break;
        bytes += chunk.value.byteLength;
        if (bytes > 512_000) throw blocked();
        chunks.push(chunk.value);
      }
    } finally { await reader.cancel(); }
    const text = Buffer.concat(chunks).toString("utf8");
    // A 200 login/CAPTCHA/SPA document is not a successfully retrieved policy.
    if (/<(?:!doctype|html|head|body|script|form)\b/i.test(text)) throw blocked();
    return robotsParser(new URL("/robots.txt", target).href, text);
  }
  throw blocked();
};

export const assertCrawlAllowed = async (target: URL, enforceDelay = true): Promise<void> => {
  try {
    let cached = policies.get(target.origin);
    if (!cached || cached.expiresAt < Date.now()) {
      if (policies.size >= 128) { policies.clear(); lastVisit.clear(); }
      cached = { expiresAt: Date.now() + 300_000, policy: fetchPolicy(target) };
      policies.set(target.origin, cached);
    }
    const policy = await cached.policy;
    if (policy.isAllowed(target.href, env.crawlerUserAgent) === false) throw blocked();
    const delay = policy.getCrawlDelay(env.crawlerUserAgent) ?? 0;
    if (enforceDelay && Date.now() - (lastVisit.get(target.origin) ?? 0) < delay * 1_000) {
      throw new ProductImportError("RATE_LIMITED", "판매처의 수집 간격에 따라 잠시 후 다시 시도해 주세요.", true, 429);
    }
    if (enforceDelay) lastVisit.set(target.origin, Date.now());
  } catch (error) {
    if (error instanceof ProductImportError) throw error;
    throw blocked();
  }
};
