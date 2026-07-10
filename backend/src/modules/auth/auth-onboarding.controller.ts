import type { NextFunction, Response } from "express";
import { supabase } from "../../config/supabase";
import type { AuthenticatedRequest } from "../../shared/types/http";
import { createHttpError } from "../../shared/utils/http-error";
import { completeOnboarding } from "./auth-onboarding.service";
import {
  REQUIRED_CONSENT_KEYS,
  type CompleteOnboardingOptions,
  type CompleteOnboardingPayload,
  type CompleteOnboardingResult,
  type ConsentKey,
  type OnboardingAuthUser,
  type OptionalConsentKey
} from "./auth-onboarding.types";

type ConsentStatusSummary = {
  readonly savedConsentKeys: readonly ConsentKey[];
  readonly requiredAccepted: boolean;
  readonly optionalAccepted: readonly ConsentKey[];
};

type CompleteOnboardingResponse = {
  readonly onboardingComplete: true;
  readonly user: CompleteOnboardingResult["user"];
  readonly consentStatus: ConsentStatusSummary;
  readonly bodyMeasurementsSaved: boolean;
};

export type CompleteOnboardingHandlerDependencies = {
  readonly verifySupabaseBearer: (token: string) => Promise<OnboardingAuthUser | null>;
  readonly completeOnboarding: (
    authUser: OnboardingAuthUser,
    payload: CompleteOnboardingPayload,
    options: CompleteOnboardingOptions
  ) => Promise<CompleteOnboardingResult>;
};

const extractBearerToken = (req: AuthenticatedRequest): string => {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    throw createHttpError(401, "Missing bearer token");
  }
  return header.slice("Bearer ".length);
};

const verifySupabaseBearer = async (token: string): Promise<OnboardingAuthUser | null> => {
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) return null;
  return { id: data.user.id, email: data.user.email };
};

const toConsentKey = (key: string): ConsentKey | null => {
  switch (key) {
    case "terms_of_service":
    case "privacy_policy":
    case "fit_data_improvement":
    case "marketing":
      return key;
    default:
      return null;
  }
};

const toOptionalConsentKey = (key: string): OptionalConsentKey | null => {
  switch (key) {
    case "fit_data_improvement":
    case "marketing":
      return key;
    default:
      return null;
  }
};

const toConsentStatus = (result: CompleteOnboardingResult): ConsentStatusSummary => {
  const savedConsentKeys = result.consentRows.flatMap((row) => {
    const consentKey = toConsentKey(row.consent_key);
    return consentKey ? [consentKey] : [];
  });
  const optionalAccepted = result.consentRows
    .filter((row) => row.accepted)
    .flatMap((row) => {
      const consentKey = toOptionalConsentKey(row.consent_key);
      return consentKey ? [consentKey] : [];
    });

  return {
    savedConsentKeys,
    requiredAccepted: REQUIRED_CONSENT_KEYS.every((requiredKey) => {
      return result.consentRows.some((row) => row.consent_key === requiredKey && row.accepted);
    }),
    optionalAccepted
  };
};

const toResponse = (result: CompleteOnboardingResult): CompleteOnboardingResponse => {
  return {
    onboardingComplete: true,
    user: result.user,
    consentStatus: toConsentStatus(result),
    bodyMeasurementsSaved: result.bodyMeasurementsSaved
  };
};

export const createCompleteOnboardingController = (
  dependencies: CompleteOnboardingHandlerDependencies
) => {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const authUser = await dependencies.verifySupabaseBearer(extractBearerToken(req));
      if (!authUser) throw createHttpError(401, "Supabase bearer token is required");

      const result = await dependencies.completeOnboarding(authUser, req.body, {
        ipAddress: req.ip ?? null,
        userAgent: req.headers["user-agent"] ?? null
      });
      res.status(200).json(toResponse(result));
    } catch (error) {
      next(error);
    }
  };
};

export const completeOnboardingController = createCompleteOnboardingController({
  verifySupabaseBearer,
  completeOnboarding
});
