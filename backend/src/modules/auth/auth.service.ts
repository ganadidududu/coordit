import {
  createSupabaseAuthClient,
  supabase,
  supabaseAdmin,
  supabaseAuth,
} from "../../config/supabase";
import { createHttpError } from "../../shared/utils/http-error";
import { upsertUserProfile } from "../users/users.service";
import {
  authenticateOrUpgradeGuest,
  type GuestUpgradeSession,
  type GuestIdentityLinkResult,
} from "./social-auth-upgrade.service";

export interface AuthResponse {
  readonly accessToken: string;
  readonly refreshToken: string;
  readonly user: {
    readonly id: string;
    readonly email: string;
    readonly isAnonymous: boolean;
  };
}

const toAuthResponse = async (
  authUser: { readonly id: string; readonly email?: string },
  session: { readonly access_token?: string; readonly refresh_token?: string } | null
): Promise<AuthResponse> => {
  if (!authUser.email) throw createHttpError(400, "Auth user email is missing");
  if (!session?.access_token || !session.refresh_token) {
    throw createHttpError(401, "Supabase did not return an active session");
  }

  await upsertUserProfile({ id: authUser.id, email: authUser.email });

  return {
    accessToken: session.access_token,
    refreshToken: session.refresh_token,
    user: { id: authUser.id, email: authUser.email, isAnonymous: false }
  };
};

export const signupWithEmail = async (
  email: string,
  password: string
): Promise<AuthResponse> => {
  const { data, error } = await supabaseAuth.auth.signUp({ email, password });
  if (error || !data.user) throw createHttpError(400, error?.message ?? "Signup failed");
  return toAuthResponse(data.user, data.session);
};

export const loginWithEmail = async (
  email: string,
  password: string
): Promise<AuthResponse> => {
  const { data, error } = await supabaseAuth.auth.signInWithPassword({ email, password });
  if (error || !data.user) throw createHttpError(401, error?.message ?? "Login failed");
  return toAuthResponse(data.user, data.session);
};

export const loginWithGoogleIdToken = async (
  idToken: string,
  nonce: string
): Promise<AuthResponse> => {
  const { data, error } = await supabaseAuth.auth.signInWithIdToken({
    provider: "google",
    token: idToken,
    nonce
  });
  if (error || !data.user) throw createHttpError(401, error?.message ?? "Google login failed");
  return toAuthResponse(data.user, data.session);
};

export const loginWithAppleIdToken = async (
  idToken: string,
  nonce: string,
  guest: GuestUpgradeSession | null = null
): Promise<AuthResponse> => {
  return loginWithSocialIdToken({ provider: "apple", idToken, nonce }, guest);
};

type SocialIdToken =
  | { readonly provider: "google"; readonly idToken: string }
  | { readonly provider: "apple"; readonly idToken: string; readonly nonce: string };

const socialCredentials = (credential: SocialIdToken) => {
  switch (credential.provider) {
    case "google":
      return { provider: "google", token: credential.idToken } as const;
    case "apple":
      return {
        provider: "apple",
        token: credential.idToken,
        nonce: credential.nonce,
      } as const;
    default: {
      const exhaustiveCredential: never = credential;
      return exhaustiveCredential;
    }
  }
};

const signInMember = async (credential: SocialIdToken): Promise<AuthResponse> => {
  const { data, error } = await supabaseAuth.auth.signInWithIdToken(socialCredentials(credential));
  if (error || !data.user) {
    throw createHttpError(401, error?.message ?? `${credential.provider} login failed`);
  }
  return toAuthResponse(data.user, data.session);
};

export const refreshAuthSession = async (refreshToken: string): Promise<AuthResponse> => {
  const { data, error } = await supabaseAuth.auth.refreshSession({
    refresh_token: refreshToken
  });
  if (error || !data.user) {
    throw createHttpError(401, error?.message ?? "Session refresh failed");
  }
  return toAuthResponse(data.user, data.session);
};
