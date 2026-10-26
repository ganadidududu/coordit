import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import type { User } from "@supabase/supabase-js";
import { app } from "../../app";
import { supabaseAdmin, supabaseAuth } from "../../config/supabase";
import { createHttpError } from "../../shared/utils/http-error";
import { appleDeviceWelcomeRegistry } from "./apple-device-check";
import { guestWelcomeRepository } from "./guest-auth.repository";
import type { GuestClaimState } from "./guest-auth.service";

const guestUser: User = {
  id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  email: "guest+aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa@guest.coordit.invalid",
  app_metadata: { provider: "anonymous", providers: ["anonymous"] },
  user_metadata: {},
  aud: "authenticated",
  created_at: "2026-10-26T00:00:00.000Z",
  is_anonymous: true
};

const stubWelcomeDependencies = (state: GuestClaimState, balance: number) => {
  const events: string[] = [];
  const bearer = vi.spyOn(supabaseAdmin.auth, "getUser").mockResolvedValue({
    data: { user: guestUser }, error: null
  });
  const prepare = vi.spyOn(guestWelcomeRepository, "prepareClaim").mockImplementation(async (userId) => {
    expect(userId).toBe(guestUser.id);
    events.push("prepare");
    return state;
  });
  const eligible = vi.spyOn(guestWelcomeRepository, "markEligible").mockImplementation(async () => { events.push("eligible"); });
  const complete = vi.spyOn(guestWelcomeRepository, "completeClaim").mockImplementation(async () => {
    events.push("complete");
    return balance;
  });
  const deny = vi.spyOn(guestWelcomeRepository, "denyClaim").mockImplementation(async () => { events.push("deny"); });
  const release = vi.spyOn(guestWelcomeRepository, "releaseLease").mockImplementation(async () => { events.push("release"); });
  const getBalance = vi.spyOn(guestWelcomeRepository, "getBalance").mockImplementation(async () => {
    events.push("balance");
    return balance;
  });
  const query = vi.spyOn(appleDeviceWelcomeRegistry, "hasClaimedWelcome").mockImplementation(async () => {
    events.push("device-query");
    return false;
  });
  const mark = vi.spyOn(appleDeviceWelcomeRegistry, "markWelcomeClaimed").mockImplementation(async () => { events.push("device-mark"); });
  return { events, bearer, prepare, eligible, complete, deny, release, getBalance, query, mark };
};

const requestWelcome = (deviceToken: string, authenticated = true): Promise<Response> => fetch(`${baseURL}/auth/guest/welcome`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    ...(authenticated ? { Authorization: "Bearer guest-http-session" } : {})
  },
  body: JSON.stringify({ deviceToken })
});

let server: Server;
let baseURL: string;

beforeAll(async () => {
  server = app.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => server.once("listening", resolve));
  const address = server.address();
  if (!address || typeof address === "string") throw new Error("Test server address is unavailable");
  baseURL = `http://127.0.0.1:${(address satisfies AddressInfo).port}`;
});

afterAll(async () => {
  await new Promise<void>((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("POST /auth/guest", () => {
  it("creates an anonymous authenticated session without collecting personal information", async () => {
    // Given
    const userId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
    vi.spyOn(supabaseAuth.auth, "signInAnonymously").mockResolvedValue({
      data: {
        user: { id: userId, is_anonymous: true },
        session: {
          access_token: "guest-access-token",
          refresh_token: "guest-refresh-token",
        },
      },
      error: null,
    } as never);
    const single = vi.fn().mockResolvedValue({ data: { id: userId }, error: null });
    const select = vi.fn().mockReturnValue({ single });
    const upsert = vi.fn().mockReturnValue({ select });
    vi.spyOn(supabaseAdmin, "from").mockReturnValue({ upsert } as never);

    // When
    const response = await fetch(`${baseURL}/auth/guest`, { method: "POST" });

    // Then
    expect(response.status).toBe(201);
    expect(await response.json()).toEqual({
      accessToken: "guest-access-token",
      refreshToken: "guest-refresh-token",
      user: {
        id: userId,
        email: `guest+${userId}@guest.coordit.invalid`,
        isAnonymous: true,
      },
    });
    expect(upsert).toHaveBeenCalledOnce();
  });
});

describe("POST /auth/guest/welcome", () => {
  it("rejects a missing bearer before welcome verification", async () => {
    // Given: the mounted app has observable authentication and welcome boundaries.
    const spies = stubWelcomeDependencies("pending", 3);
    // When: a caller supplies a device token without a session.
    const response = await requestWelcome("device-token", false);
    // Then: authentication rejects it before any Apple or wallet operation.
    expect(response.status).toBe(401);
    expect(spies.bearer).not.toHaveBeenCalled();
    expect(spies.events).toEqual([]);
  });

  it("returns two remaining threads for an already granted guest without a new credit", async () => {
    // Given: a returning guest has already spent one welcome thread.
    const spies = stubWelcomeDependencies("granted", 2);
    // When: the authenticated guest retries welcome redemption after login.
    const response = await requestWelcome("new-device-token");
    // Then: the existing balance is preserved without querying Apple or topping up.
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ availableThreads: 2, status: "already_claimed" });
    expect(spies.events).toEqual(["prepare", "balance"]);
    expect(spies.complete).not.toHaveBeenCalled();
    expect(spies.query).not.toHaveBeenCalled();
    expect(spies.mark).not.toHaveBeenCalled();
  });

  it("credits three threads only after a fresh device is marked redeemed", async () => {
    // Given: neither the guest nor the device has redeemed the welcome grant.
    const spies = stubWelcomeDependencies("pending", 3);
    // When: the guest sends a valid current DeviceCheck token.
    const response = await requestWelcome("fresh-device-token");
    // Then: marking the device precedes one atomic credit and the gate is released.
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ availableThreads: 3, status: "granted" });
    expect(spies.events).toEqual(["prepare", "device-query", "eligible", "device-mark", "complete", "release"]);
    expect(spies.complete).toHaveBeenCalledOnce();
    expect(spies.query).toHaveBeenCalledWith("fresh-device-token");
    expect(spies.mark).toHaveBeenCalledWith("fresh-device-token");
  });

  it.each([" ", "x".repeat(8193)])("rejects a blank or oversized token before Apple verification", async (token) => {
    // Given: welcome dependencies would grant if reached.
    const spies = stubWelcomeDependencies("pending", 3);
    // When: the authenticated request carries an invalid token boundary value.
    const response = await requestWelcome(token);
    // Then: the controller rejects it before obtaining a claim lease or calling Apple.
    expect(response.status).toBe(400);
    expect(spies.events).toEqual([]);
    expect(spies.prepare).not.toHaveBeenCalled();
    expect(spies.query).not.toHaveBeenCalled();
  });

  it.each(["query", "mark"] as const)("returns 5xx and releases the gate when Apple %s fails", async (failurePoint) => {
    // Given: Apple becomes unavailable at one of the two verification operations.
    const spies = stubWelcomeDependencies("pending", 3);
    const failure = async (): Promise<never> => {
      spies.events.push(failurePoint === "query" ? "device-query" : "device-mark");
      throw createHttpError(502, "DeviceCheck is unavailable");
    };
    if (failurePoint === "query") spies.query.mockImplementation(failure);
    else spies.mark.mockImplementation(failure);
    // When: the valid authenticated request reaches the failing Apple operation.
    const response = await requestWelcome("device-token");
    // Then: no credit is created and the lease is released for a safe retry.
    expect(response.status).toBe(502);
    expect(spies.complete).not.toHaveBeenCalled();
    expect(spies.release).toHaveBeenCalledOnce();
    expect(spies.events).toEqual(failurePoint === "query"
      ? ["prepare", "device-query", "release"]
      : ["prepare", "device-query", "eligible", "device-mark", "release"]);
  });
});
