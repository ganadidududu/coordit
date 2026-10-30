import type { AuthResponse } from "./auth.service";

export const guestClaimStates = ["pending", "eligible", "granted", "denied", "legacy"] as const;
export type GuestClaimState = (typeof guestClaimStates)[number];

export interface GuestSessionRepository {
  readonly createAnonymousSession: () => Promise<AuthResponse>;
  readonly createGuestProfile: (userId: string, placeholderEmail: string) => Promise<void>;
}

export interface GuestWelcomeRepository {
  readonly prepareClaim: (userId: string, leaseId: string) => Promise<GuestClaimState>;
  readonly markEligible: (userId: string, leaseId: string) => Promise<void>;
  readonly completeClaim: (userId: string, leaseId: string) => Promise<number>;
  readonly denyClaim: (userId: string, leaseId: string) => Promise<void>;
  readonly releaseLease: (leaseId: string) => Promise<void>;
  readonly getBalance: (userId: string) => Promise<number>;
}

export interface DeviceWelcomeRegistry {
  readonly hasClaimedWelcome: (deviceToken: string) => Promise<boolean>;
  readonly markWelcomeClaimed: (deviceToken: string) => Promise<void>;
}

export type GuestWelcomeResult = {
  readonly availableThreads: number;
  readonly status: "already_claimed" | "granted";
};

export type GuestWelcomeDependencies = {
  readonly repository: GuestWelcomeRepository;
  readonly deviceRegistry: DeviceWelcomeRegistry;
};

export const createGuestSession = async (
  repository: GuestSessionRepository
): Promise<AuthResponse> => {
  const session = await repository.createAnonymousSession();
  await repository.createGuestProfile(session.user.id, session.user.email);
  return session;
};

// Keep the endpoint compatible with older clients without granting guest credit.
export const claimGuestWelcome = async (
  userId: string,
  _deviceToken: string,
  dependencies: GuestWelcomeDependencies
): Promise<GuestWelcomeResult> => ({
  availableThreads: await dependencies.repository.getBalance(userId),
  status: "already_claimed",
});
