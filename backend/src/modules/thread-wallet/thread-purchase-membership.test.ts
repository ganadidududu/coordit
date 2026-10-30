import type { Server } from "node:http";
import express from "express";
import { describe, expect, it } from "vitest";
import { errorMiddleware } from "../../middleware/error.middleware";
import { createAppleIapPurchaseController } from "./thread-wallet.controller";

describe("paid purchase membership boundary", () => {
  it.each([true, undefined])("rejects guest or unclassified bearer identity (%s), ignoring forged body membership", async (isAnonymous) => {
    let creditCalls = 0;
    const app = express();
    app.use(express.json());
    app.use((req, _res, next) => {
      Object.assign(req, { user: { id: "845628bf-1362-4f64-937d-e947aa1d017f", isAnonymous } });
      next();
    });
    app.post("/thread-wallet/iap/verify", createAppleIapPurchaseController({
      submitAppleIapPurchase: async () => {
        creditCalls += 1;
        return { availableThreads: 12, status: "credited" };
      },
    }));
    app.use(errorMiddleware);
    const server: Server = app.listen(0, "127.0.0.1");
    await new Promise<void>((resolve) => server.once("listening", resolve));
    const address = server.address();
    if (!address || typeof address === "string") throw new TypeError("HTTP address unavailable");
    try {
      const response = await fetch(`http://127.0.0.1:${address.port}/thread-wallet/iap/verify`, {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ signedTransaction: "guest-signed-transaction", isAnonymous: false }),
      });
      expect(response.status).toBe(403);
      expect(creditCalls).toBe(0);
      expect(await response.json()).toEqual({ message: "실타래를 구매하려면 먼저 계정을 연결해 주세요." });
    } finally {
      await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    }
  });
});
