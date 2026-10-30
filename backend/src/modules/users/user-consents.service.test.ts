import assert from "node:assert/strict";
import type { ConsentVersionRow, UserConsentRow } from "../../shared/types/database";
import type { OptionalConsentKey } from "../auth/auth-onboarding.types";
import type { SaveOptionalConsentInput, UserConsentRepository } from "./user-consents.service";

process.env.SUPABASE_URL = process.env.SUPABASE_URL ?? "http://localhost:54321";
process.env.SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY ?? "anon-key";
process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "service-role-key";

const onboardedAt = "2026-07-08T00:00:00.000Z";
const now = new Date("2026-10-29T03:00:00.000Z");

const version = (key: OptionalConsentKey, value = "2026-07-07"): ConsentVersionRow => ({
  key,
  version: value,
  title: key,
  description: null,
  required: false,
  effective_from: "2026-07-07T00:00:00.000Z",
  created_at: "2026-07-07T00:00:00.000Z"
});

const row = (key: OptionalConsentKey, values: Partial<UserConsentRow> = {}): UserConsentRow => ({
  id: `${key}-row`,
  user_id: "user-1",
  consent_key: key,
  consent_version: "2026-07-07",
  accepted: true,
  accepted_at: onboardedAt,
  revoked_at: null,
  required: false,
  ip_address: null,
  user_agent: null,
  created_at: onboardedAt,
  updated_at: onboardedAt,
  ...values
});

const createFakeRepository = (
  initialRows: readonly UserConsentRow[],
  versions: readonly ConsentVersionRow[] = [version("fit_data_improvement"), version("marketing")]
) => {
  const rows = [...initialRows];
  const saves: SaveOptionalConsentInput[] = [];
  const repository: UserConsentRepository = {
    findLatestConsentVersion: async (key) => versions.find((candidate) => candidate.key === key) ?? null,
    findUserConsents: async (userId, keys) =>
      rows.filter((candidate) => candidate.user_id === userId && (keys as readonly string[]).includes(candidate.consent_key)),
    saveOptionalConsent: async (input) => {
      saves.push(input);
      const saved = row(input.consentKey, {
        consent_version: input.consentVersion,
        accepted: input.accepted,
        accepted_at: input.acceptedAt,
        revoked_at: input.revokedAt,
        ip_address: input.ipAddress,
        user_agent: input.userAgent,
        updated_at: input.nowIso
      });
      const index = rows.findIndex(
        (candidate) => candidate.consent_key === input.consentKey && candidate.consent_version === input.consentVersion
      );
      if (index >= 0) rows[index] = saved;
      else rows.push(saved);
      return saved;
    }
  };
  return { repository, saves };
};

const expectHttpError = async (promise: Promise<unknown>, statusCode: number, message: string) => {
  await assert.rejects(promise, (error: unknown) => {
    assert.equal((error as { statusCode?: number }).statusCode, statusCode);
    assert.equal((error as Error).message, message);
    return true;
  });
};

const tests: readonly { readonly name: string; readonly run: () => Promise<void> }[] = [
  {
    name: "reads the onboarding choices for the current consent versions",
    run: async () => {
      const { getOptionalConsentsWithRepository } = await import("./user-consents.service");
      const fake = createFakeRepository([row("fit_data_improvement"), row("marketing", { accepted: false, accepted_at: null })]);
      const result = await getOptionalConsentsWithRepository(fake.repository, "user-1", now);
      assert.deepEqual(result.consents, {
        fit_data_improvement: { accepted: true, version: "2026-07-07", updatedAt: onboardedAt },
        marketing: { accepted: false, version: "2026-07-07", updatedAt: onboardedAt }
      });
    }
  },
  {
    name: "a user without consent rows is reported as not consenting",
    run: async () => {
      const { getOptionalConsentsWithRepository } = await import("./user-consents.service");
      const result = await getOptionalConsentsWithRepository(createFakeRepository([]).repository, "user-1", now);
      assert.equal(result.consents.fit_data_improvement.accepted, false);
      assert.equal(result.consents.fit_data_improvement.updatedAt, null);
    }
  },
  {
    name: "acceptance of an older consent text does not count for a newer version",
    run: async () => {
      const { getOptionalConsentsWithRepository } = await import("./user-consents.service");
      const fake = createFakeRepository(
        [row("fit_data_improvement")],
        [version("fit_data_improvement", "2026-11-01"), version("marketing")]
      );
      const result = await getOptionalConsentsWithRepository(fake.repository, "user-1", now);
      assert.deepEqual(result.consents.fit_data_improvement, { accepted: false, version: "2026-11-01", updatedAt: null });
    }
  },
  {
    name: "withdrawing keeps the acceptance time, records revocation, and persists for the next read",
    run: async () => {
      const { getOptionalConsentsWithRepository, updateOptionalConsentsWithRepository } = await import("./user-consents.service");
      const fake = createFakeRepository([row("fit_data_improvement")]);
      const result = await updateOptionalConsentsWithRepository(
        fake.repository,
        "user-1",
        { consents: { fit_data_improvement: { accepted: false } } },
        { now, ipAddress: "203.0.113.7", userAgent: "coordit-ios" }
      );
      assert.equal(result.consents.fit_data_improvement.accepted, false);
      assert.deepEqual(fake.saves, [
        {
          userId: "user-1",
          consentKey: "fit_data_improvement",
          consentVersion: "2026-07-07",
          accepted: false,
          acceptedAt: onboardedAt,
          revokedAt: now.toISOString(),
          nowIso: now.toISOString(),
          ipAddress: "203.0.113.7",
          userAgent: "coordit-ios"
        }
      ]);
      const reread = await getOptionalConsentsWithRepository(fake.repository, "user-1", now);
      assert.equal(reread.consents.fit_data_improvement.accepted, false);
    }
  },
  {
    name: "re-accepting a withdrawn consent clears the revocation",
    run: async () => {
      const { updateOptionalConsentsWithRepository } = await import("./user-consents.service");
      const fake = createFakeRepository([
        row("fit_data_improvement", { accepted: false, revoked_at: "2026-09-01T00:00:00.000Z" })
      ]);
      const result = await updateOptionalConsentsWithRepository(
        fake.repository,
        "user-1",
        { consents: { fit_data_improvement: { accepted: true } } },
        { now }
      );
      assert.equal(result.consents.fit_data_improvement.accepted, true);
      assert.equal(fake.saves[0]?.acceptedAt, now.toISOString());
      assert.equal(fake.saves[0]?.revokedAt, null);
    }
  },
  {
    name: "declining a consent that was never accepted stores no revocation time",
    run: async () => {
      const { updateOptionalConsentsWithRepository } = await import("./user-consents.service");
      const fake = createFakeRepository([], [version("fit_data_improvement"), version("marketing")]);
      await updateOptionalConsentsWithRepository(
        fake.repository,
        "user-1",
        { consents: { marketing: { accepted: true } } },
        { now }
      );
      await updateOptionalConsentsWithRepository(
        fake.repository,
        "user-1",
        { consents: { fit_data_improvement: { accepted: false } } },
        { now }
      );
      assert.equal(fake.saves.length, 1, "An unchanged state must not write a new consent record.");
      assert.equal(fake.saves[0]?.consentKey, "marketing");
    }
  },
  {
    name: "rejects required, unknown, and malformed consent updates",
    run: async () => {
      const { updateOptionalConsentsWithRepository } = await import("./user-consents.service");
      const fake = createFakeRepository([]);
      const update = (body: unknown) => updateOptionalConsentsWithRepository(fake.repository, "user-1", body, { now });
      await expectHttpError(update({}), 400, "consents object is required");
      await expectHttpError(update({ consents: {} }), 400, "At least one consent is required");
      await expectHttpError(
        update({ consents: { privacy_policy: { accepted: false } } }),
        400,
        "privacy_policy is not an optional consent"
      );
      await expectHttpError(
        update({ consents: { marketing: { accepted: "false" } } }),
        400,
        "marketing consent accepted must be a boolean"
      );
      assert.equal(fake.saves.length, 0);
    }
  },
  {
    name: "fails clearly when the consent catalog has no version in effect",
    run: async () => {
      const { updateOptionalConsentsWithRepository } = await import("./user-consents.service");
      const fake = createFakeRepository([], [version("marketing")]);
      await expectHttpError(
        updateOptionalConsentsWithRepository(fake.repository, "user-1", { consents: { fit_data_improvement: { accepted: true } } }, { now }),
        409,
        "fit_data_improvement consent version is not available"
      );
    }
  }
];

const run = async (): Promise<void> => {
  for (const test of tests) {
    await test.run();
    console.log(`PASS ${test.name}`);
  }
};

void run().then(
  () => console.log("user-consents.service tests passed"),
  (error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  }
);
