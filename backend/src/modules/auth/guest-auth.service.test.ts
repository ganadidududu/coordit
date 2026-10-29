import { describe, expect, it } from "vitest";
import type { AuthResponse } from "./auth.service";
import {
  claimGuestWelcome,
  guestClaimStates,
  createGuestSession,
  type DeviceWelcomeRegistry,
  type GuestClaimState,
  type GuestSessionRepository,
  type GuestWelcomeRepository,
} from "./guest-auth.service";

const guestSession: AuthResponse = {
  accessToken: "guest-access-token",
  refreshToken: "guest-refresh-token",
  user: {
    id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    email: "guest+aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa@guest.coordit.invalid",
    isAnonymous: true,
  },
};

describe("guest authentication", () => {
  it("creates a server-backed anonymous session before welcome redemption", async () => {
    // Given
    const mutableProfiles: { userId: string; email: string }[] = [];
    const repository: GuestSessionRepository = {
      createAnonymousSession: async () => guestSession,
      createGuestProfile: async (userId, placeholderEmail) => {
        mutableProfiles.push({ userId, email: placeholderEmail });
      },
    };

    // When
    const created = await createGuestSession(repository);

    // Then
    expect(created).toEqual(guestSession);
    expect(mutableProfiles).toEqual([
      {
        userId: guestSession.user.id,
        email: guestSession.user.email,
      },
    ]);
  });

  it.each(guestClaimStates)("does not grant or query DeviceCheck for %s guests", async (state) => {
    const events: string[] = [];
    const result = await claimGuestWelcome(guestSession.user.id, "old-client-token", {
      repository: welcomeRepository(state, events, 0), deviceRegistry: deviceRegistry(false, events),
    });
    expect(result).toEqual({ availableThreads: 0, status: "already_claimed" });
    expect(events).toEqual(["balance"]);
  });

  it("preserves earned guest threads", async () => {
    const events: string[] = [];
    const result = await claimGuestWelcome(guestSession.user.id, "token", {
      repository: welcomeRepository("granted", events, 5), deviceRegistry: deviceRegistry(true, events),
    });
    expect(result.availableThreads).toBe(5);
    expect(events).toEqual(["balance"]);
  });
});

const welcomeRepository = (
  initialState: GuestClaimState,
  events: string[],
  balance: number
): GuestWelcomeRepository => ({
  prepareClaim: async () => {
    events.push("prepare");
    return initialState;
  },
  markEligible: async () => {
    events.push("eligible");
  },
  completeClaim: async () => {
    events.push("complete");
    return balance;
  },
  denyClaim: async () => {
    events.push("deny");
  },
  releaseLease: async () => {
    events.push("release");
  },
  getBalance: async () => {
    events.push("balance");
    return balance;
  },
});

const deviceRegistry = (
  claimed: boolean,
  events: string[]
): DeviceWelcomeRegistry => ({
  hasClaimedWelcome: async () => {
    events.push("device-query");
    return claimed;
  },
  markWelcomeClaimed: async () => {
    events.push("device-mark");
  },
});
