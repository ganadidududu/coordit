import type { ConsentVersionRow, UserConsentRow } from "../../shared/types/database";
import { createHttpError } from "../../shared/utils/http-error";
import { OPTIONAL_CONSENT_KEYS, type OptionalConsentKey } from "../auth/auth-onboarding.types";

export type OptionalConsentState = {
  readonly accepted: boolean;
  readonly version: string | null;
  readonly updatedAt: string | null;
};

export type OptionalConsentsResponse = {
  readonly consents: Record<OptionalConsentKey, OptionalConsentState>;
};

export type SaveOptionalConsentInput = {
  readonly userId: string;
  readonly consentKey: OptionalConsentKey;
  readonly consentVersion: string;
  readonly accepted: boolean;
  readonly acceptedAt: string | null;
  readonly revokedAt: string | null;
  readonly nowIso: string;
  readonly ipAddress: string | null;
  readonly userAgent: string | null;
};

export type UserConsentRepository = {
  readonly findLatestConsentVersion: (
    key: OptionalConsentKey,
    nowIso: string
  ) => Promise<ConsentVersionRow | null>;
  readonly findUserConsents: (
    userId: string,
    keys: readonly OptionalConsentKey[]
  ) => Promise<readonly UserConsentRow[]>;
  readonly saveOptionalConsent: (input: SaveOptionalConsentInput) => Promise<UserConsentRow>;
};

export type UpdateOptionalConsentsOptions = {
  readonly now?: Date;
  readonly ipAddress?: string | null;
  readonly userAgent?: string | null;
};

const isOptionalConsentKey = (key: string): key is OptionalConsentKey =>
  (OPTIONAL_CONSENT_KEYS as readonly string[]).includes(key);

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const loadLatestVersions = async (
  repository: UserConsentRepository,
  nowIso: string
): Promise<Map<OptionalConsentKey, ConsentVersionRow | null>> => {
  const versions = new Map<OptionalConsentKey, ConsentVersionRow | null>();
  for (const key of OPTIONAL_CONSENT_KEYS) {
    versions.set(key, await repository.findLatestConsentVersion(key, nowIso));
  }
  return versions;
};

// A consent only counts for the version currently in effect; agreeing to an older text is not consent to the new one.
const findCurrentRow = (
  rows: readonly UserConsentRow[],
  key: OptionalConsentKey,
  latest: ConsentVersionRow | null
): UserConsentRow | undefined =>
  latest ? rows.find((row) => row.consent_key === key && row.consent_version === latest.version) : undefined;

const toState = (latest: ConsentVersionRow | null, row: UserConsentRow | undefined): OptionalConsentState => ({
  accepted: row !== undefined && row.accepted && row.revoked_at === null,
  version: latest?.version ?? null,
  updatedAt: row?.updated_at ?? null
});

const buildResponse = (
  versions: Map<OptionalConsentKey, ConsentVersionRow | null>,
  rows: readonly UserConsentRow[]
): OptionalConsentsResponse => {
  const consents = {} as Record<OptionalConsentKey, OptionalConsentState>;
  for (const key of OPTIONAL_CONSENT_KEYS) {
    const latest = versions.get(key) ?? null;
    consents[key] = toState(latest, findCurrentRow(rows, key, latest));
  }
  return { consents };
};

export const parseOptionalConsentUpdates = (body: unknown): ReadonlyMap<OptionalConsentKey, boolean> => {
  if (!isRecord(body) || !isRecord(body.consents)) {
    throw createHttpError(400, "consents object is required");
  }

  const updates = new Map<OptionalConsentKey, boolean>();
  for (const [key, value] of Object.entries(body.consents)) {
    if (!isOptionalConsentKey(key)) throw createHttpError(400, `${key} is not an optional consent`);
    if (!isRecord(value) || typeof value.accepted !== "boolean") {
      throw createHttpError(400, `${key} consent accepted must be a boolean`);
    }
    updates.set(key, value.accepted);
  }

  if (updates.size === 0) throw createHttpError(400, "At least one consent is required");
  return updates;
};

export const getOptionalConsentsWithRepository = async (
  repository: UserConsentRepository,
  userId: string,
  now: Date = new Date()
): Promise<OptionalConsentsResponse> => {
  const versions = await loadLatestVersions(repository, now.toISOString());
  const rows = await repository.findUserConsents(userId, OPTIONAL_CONSENT_KEYS);
  return buildResponse(versions, rows);
};

export const updateOptionalConsentsWithRepository = async (
  repository: UserConsentRepository,
  userId: string,
  body: unknown,
  options: UpdateOptionalConsentsOptions = {}
): Promise<OptionalConsentsResponse> => {
  const updates = parseOptionalConsentUpdates(body);
  const nowIso = (options.now ?? new Date()).toISOString();
  const versions = await loadLatestVersions(repository, nowIso);
  const rows = await repository.findUserConsents(userId, OPTIONAL_CONSENT_KEYS);

  for (const [key, accepted] of updates) {
    const latest = versions.get(key) ?? null;
    if (!latest) throw createHttpError(409, `${key} consent version is not available`);
    const existing = findCurrentRow(rows, key, latest);
    const wasAccepted = existing !== undefined && existing.accepted && existing.revoked_at === null;
    if (wasAccepted === accepted) continue;

    // Withdrawal keeps the original acceptance time and records when it was revoked.
    await repository.saveOptionalConsent({
      userId,
      consentKey: key,
      consentVersion: latest.version,
      accepted,
      acceptedAt: accepted ? nowIso : existing?.accepted_at ?? null,
      revokedAt: accepted || !existing?.accepted_at ? null : nowIso,
      nowIso,
      ipAddress: options.ipAddress ?? null,
      userAgent: options.userAgent ?? null
    });
  }

  return getOptionalConsentsWithRepository(repository, userId, options.now);
};

export const getOptionalConsents = async (userId: string): Promise<OptionalConsentsResponse> => {
  const { supabaseUserConsentRepository } = await import("./user-consents.repository");
  return getOptionalConsentsWithRepository(supabaseUserConsentRepository, userId);
};

export const updateOptionalConsents = async (
  userId: string,
  body: unknown,
  options: UpdateOptionalConsentsOptions = {}
): Promise<OptionalConsentsResponse> => {
  const { supabaseUserConsentRepository } = await import("./user-consents.repository");
  return updateOptionalConsentsWithRepository(supabaseUserConsentRepository, userId, body, options);
};
