import { supabase } from "../../config/supabase";
import type { UserConsentRow } from "../../shared/types/database";
import { createHttpError } from "../../shared/utils/http-error";
import { supabaseOnboardingRepository } from "../auth/auth-onboarding.repository";
import type { UserConsentRepository } from "./user-consents.service";

export const supabaseUserConsentRepository: UserConsentRepository = {
  findLatestConsentVersion: (key, nowIso) => supabaseOnboardingRepository.findLatestConsentVersion(key, nowIso),

  async findUserConsents(userId, keys) {
    const { data, error } = await supabase
      .from("user_consents")
      .select("*")
      .eq("user_id", userId)
      .in("consent_key", [...keys])
      .returns<UserConsentRow[]>();

    if (error) throw createHttpError(500, "Failed to load user consents");
    return data ?? [];
  },

  async saveOptionalConsent(input) {
    const { data, error } = await supabase
      .from("user_consents")
      .upsert(
        {
          user_id: input.userId,
          consent_key: input.consentKey,
          consent_version: input.consentVersion,
          accepted: input.accepted,
          accepted_at: input.acceptedAt,
          revoked_at: input.revokedAt,
          required: false,
          ip_address: input.ipAddress,
          user_agent: input.userAgent,
          updated_at: input.nowIso
        },
        { onConflict: "user_id,consent_key,consent_version" }
      )
      .select("*")
      .single<UserConsentRow>();

    if (error || !data) throw createHttpError(500, "Failed to save user consent");
    return data;
  }
};
