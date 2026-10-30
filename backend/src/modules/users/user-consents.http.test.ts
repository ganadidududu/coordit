import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { app } from "../../app";
import { supabaseAdmin } from "../../config/supabase";
import type { UserConsentRow } from "../../shared/types/database";

const userId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const onboardedAt = "2026-07-08T00:00:00.000Z";

let server: Server;
let baseURL: string;
let consentRows: UserConsentRow[];
let upserts: Record<string, unknown>[];

const consentRow = (key: string, accepted: boolean): UserConsentRow => ({
  id: `${key}-row`,
  user_id: userId,
  consent_key: key,
  consent_version: "2026-07-07",
  accepted,
  accepted_at: accepted ? onboardedAt : null,
  revoked_at: null,
  required: false,
  ip_address: null,
  user_agent: null,
  created_at: onboardedAt,
  updated_at: onboardedAt
});

const consentVersionsTable = () => {
  let key = "";
  const query = {
    select: () => query,
    eq: (_column: string, value: string) => {
      key = value;
      return query;
    },
    lte: () => query,
    order: () => query,
    limit: () => query,
    maybeSingle: async () => ({
      data: {
        key,
        version: "2026-07-07",
        title: key,
        description: null,
        required: false,
        effective_from: "2026-07-07T00:00:00.000Z",
        created_at: "2026-07-07T00:00:00.000Z"
      },
      error: null
    })
  };
  return query;
};

const userConsentsTable = () => {
  const query = {
    select: () => query,
    eq: () => query,
    in: () => query,
    returns: async () => ({ data: consentRows, error: null }),
    upsert: (payload: Record<string, unknown>) => {
      upserts.push(payload);
      const saved = { ...consentRow(String(payload.consent_key), false), ...payload } as UserConsentRow;
      consentRows = [...consentRows.filter((row) => row.consent_key !== saved.consent_key), saved];
      return { select: () => ({ single: async () => ({ data: saved, error: null }) }) };
    }
  };
  return query;
};

const request = (method: string, body?: unknown) =>
  fetch(`${baseURL}/users/me/consents`, {
    method,
    headers: {
      authorization: "Bearer user-token",
      "content-type": "application/json",
      "user-agent": "coordit-ios-test",
      "x-forwarded-for": "203.0.113.7"
    },
    body: body === undefined ? undefined : JSON.stringify(body)
  });

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

beforeEach(() => {
  consentRows = [consentRow("fit_data_improvement", true), consentRow("marketing", false)];
  upserts = [];
  vi.spyOn(supabaseAdmin.auth, "getUser").mockResolvedValue({
    data: { user: { id: userId, email: "member@example.com" } },
    error: null
  } as never);
  vi.spyOn(supabaseAdmin, "from").mockImplementation(((table: string) => {
    if (table === "consent_versions") return consentVersionsTable();
    if (table === "user_consents") return userConsentsTable();
    throw new Error(`Unexpected table ${table}`);
  }) as never);
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("/users/me/consents", () => {
  it("returns the optional consents chosen during onboarding", async () => {
    // When
    const response = await request("GET");

    // Then
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      consents: {
        fit_data_improvement: { accepted: true, version: "2026-07-07", updatedAt: onboardedAt },
        marketing: { accepted: false, version: "2026-07-07", updatedAt: onboardedAt }
      }
    });
  });

  it("withdraws a consent, records the forwarded client address, and keeps it withdrawn on the next read", async () => {
    // When
    const response = await request("PATCH", { consents: { fit_data_improvement: { accepted: false } } });
    const reread = await request("GET");

    // Then
    expect(response.status).toBe(200);
    expect((await response.json()).consents.fit_data_improvement.accepted).toBe(false);
    expect(upserts).toHaveLength(1);
    expect(upserts[0]).toMatchObject({
      user_id: userId,
      consent_key: "fit_data_improvement",
      accepted: false,
      accepted_at: onboardedAt,
      required: false,
      ip_address: "203.0.113.7",
      user_agent: "coordit-ios-test"
    });
    expect(upserts[0]?.revoked_at).toEqual(expect.any(String));
    expect((await reread.json()).consents.fit_data_improvement.accepted).toBe(false);
  });

  it("rejects attempts to change required consents", async () => {
    // When
    const response = await request("PATCH", { consents: { terms_of_service: { accepted: false } } });

    // Then
    expect(response.status).toBe(400);
    expect(upserts).toHaveLength(0);
  });

  it("requires authentication", async () => {
    // When
    const response = await fetch(`${baseURL}/users/me/consents`);

    // Then
    expect(response.status).toBe(401);
  });
});
