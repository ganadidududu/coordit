import { supabase, supabaseAuth } from "../../config/supabase";
import { createHttpError } from "../../shared/utils/http-error";
import { upsertUserProfile } from "../users/users.service";
import type { AuthResponse } from "./auth.service";
import { getThreadBalance } from "../thread-wallet/thread-wallet.service";
import type {
  GuestClaimState,
  GuestSessionRepository,
  GuestWelcomeRepository,
} from "./guest-auth.service";

type ClaimStateRow = {
  readonly status: GuestClaimState;
};

type ThreadBalanceRow = {
  readonly available_threads: number;
};

const guestEmail = (userId: string): string =>
  `guest+${userId}@guest.coordit.invalid`;

export const guestSessionRepository: GuestSessionRepository = {
  createAnonymousSession: async (): Promise<AuthResponse> => {
    const { data, error } = await supabaseAuth.auth.signInAnonymously();
    if (error || !data.user || !data.session) {
      throw createHttpError(503, error?.message ?? "Guest session could not be created");
    }
    return {
      accessToken: data.session.access_token,
      refreshToken: data.session.refresh_token,
      user: {
        id: data.user.id,
        email: guestEmail(data.user.id),
        isAnonymous: true,
      },
    };
  },
  createGuestProfile: async (userId, placeholderEmail): Promise<void> => {
    await upsertUserProfile({
      id: userId,
      email: placeholderEmail,
      isGuest: true,
    });
  },
};

const completeClaim = async (
  userId: string,
  leaseId: string
): Promise<number> => {
  const { data, error } = await supabase
    .rpc("complete_guest_welcome_claim", { p_user_id: userId, p_lease_id: leaseId })
    .single<ThreadBalanceRow>();
  if (error || !data) {
    throw createHttpError(500, error?.message ?? "Guest welcome balance could not be updated");
  }
  return data.available_threads;
};

export const guestWelcomeRepository: GuestWelcomeRepository = {
  prepareClaim: async (userId, leaseId): Promise<GuestClaimState> => {
    const { data, error } = await supabase
      .rpc("prepare_guest_welcome_claim", { p_user_id: userId, p_lease_id: leaseId })
      .single<ClaimStateRow>();
    if (error || !data) {
      throw createHttpError(error?.code === "55P03" ? 503 : 500, error?.message ?? "Guest welcome claim could not be prepared");
    }
    return data.status;
  },
  markEligible: async (userId, leaseId): Promise<void> => {
    const { error } = await supabase.rpc("mark_guest_welcome_eligible", {
      p_user_id: userId,
      p_lease_id: leaseId,
    });
    if (error) throw createHttpError(500, error.message);
  },
  completeClaim,
  denyClaim: async (userId, leaseId): Promise<void> => {
    const { error } = await supabase.rpc("deny_guest_welcome_claim", { p_user_id: userId, p_lease_id: leaseId });
    if (error) throw createHttpError(500, error.message);
  },
  releaseLease: async (leaseId): Promise<void> => {
    const { error } = await supabase.rpc("release_guest_welcome_lease", { p_lease_id: leaseId });
    if (error) throw createHttpError(503, "Welcome verification release failed; retry shortly");
  },
  getBalance: getThreadBalance,
};
