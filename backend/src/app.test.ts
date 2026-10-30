import { afterEach, describe, expect, it, vi } from "vitest";

const loadApp = async (trustProxyHops?: string) => {
  if (trustProxyHops === undefined) delete process.env.TRUST_PROXY_HOPS;
  else process.env.TRUST_PROXY_HOPS = trustProxyHops;
  vi.resetModules();
  return (await import("./app")).app;
};

afterEach(() => {
  delete process.env.TRUST_PROXY_HOPS;
  vi.resetModules();
});

describe("trust proxy", () => {
  it("trusts exactly the one Cloud Run front-end hop by default", async () => {
    const app = await loadApp();
    const trust = app.get("trust proxy fn") as (address: string, hop: number) => boolean;

    expect(trust("169.254.1.1", 0)).toBe(true);
    expect(trust("198.51.100.20", 1)).toBe(false);
  });

  it("trusts no forwarded address when TRUST_PROXY_HOPS is 0", async () => {
    const app = await loadApp("0");
    const trust = app.get("trust proxy fn") as (address: string, hop: number) => boolean;

    expect(trust("169.254.1.1", 0)).toBe(false);
  });

  it("refuses to start with an invalid hop count", async () => {
    await expect(loadApp("-1")).rejects.toThrow("TRUST_PROXY_HOPS must be a non-negative integer");
  });
});
