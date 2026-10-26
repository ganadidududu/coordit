import { describe, expect, it } from "vitest";
import type { AuthResponse } from "./auth.service";
import {
  claimGuestWelcome,
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

  it("grants exactly three threads when a device has not redeemed the welcome offer", async () => {
    // Given
    const events: string[] = [];
    const repository = welcomeRepository("pending", events, 3);
    const registry = deviceRegistry(false, events);

    // When
    const result = await claimGuestWelcome(
      guestSession.user.id,
      "device-token",
      { repository, deviceRegistry: registry }
    );

    // Then
    expect(result).toEqual({ availableThreads: 3, status: "granted" });
    expect(events).toEqual(["prepare", "device-query", "eligible", "device-mark", "complete", "release"]);
  });

  it("does not grant more threads when the device already redeemed the offer", async () => {
    // Given
    const events: string[] = [];
    const repository = welcomeRepository("pending", events, 0);
    const registry = deviceRegistry(true, events);

    // When
    const result = await claimGuestWelcome(
      guestSession.user.id,
      "device-token",
      { repository, deviceRegistry: registry }
    );

    // Then
    expect(result).toEqual({ availableThreads: 0, status: "already_claimed" });
    expect(events).toEqual(["prepare", "device-query", "deny", "balance", "release"]);
  });

  it("rechecks an interrupted eligible claim instead of granting after another device redemption", async () => {
    // Given
    const events: string[] = [];
    const repository = welcomeRepository("eligible", events, 0);
    const registry = deviceRegistry(true, events);

    // When
    const result = await claimGuestWelcome(
      guestSession.user.id,
      "device-token",
      { repository, deviceRegistry: registry }
    );

    // Then
    expect(result).toEqual({ availableThreads: 0, status: "already_claimed" });
    expect(events).toEqual(["prepare", "device-query", "deny", "balance", "release"]);
  });

  it("returns the spent balance without calling Apple or topping up on guest reentry", async () => {
    const events: string[] = [];
    const result = await claimGuestWelcome(guestSession.user.id, "device-token", {
      repository: welcomeRepository("granted", events, 2), deviceRegistry: deviceRegistry(true, events),
    });
    expect(result).toEqual({ availableThreads: 2, status: "already_claimed" });
    expect(events).toEqual(["prepare", "balance"]);
  });

  it("never credits on Apple failure and releases the global gate", async () => {
    const events: string[] = [];
    await expect(claimGuestWelcome(guestSession.user.id, "device-token", {
      repository: welcomeRepository("pending", events, 0),
      deviceRegistry: {
        ...deviceRegistry(false, events),
        markWelcomeClaimed: async () => { throw new TypeError("Apple unavailable"); },
      },
    })).rejects.toThrow("Apple unavailable");
    expect(events).toEqual(["prepare", "device-query", "eligible", "release"]);
  });

  it("marks a legacy device as redeemed while preserving its spent balance", async () => {
    const events: string[] = [];
    const result = await claimGuestWelcome(guestSession.user.id, "device-token", {
      repository: welcomeRepository("legacy", events, 2), deviceRegistry: deviceRegistry(false, events),
    });
    expect(result).toEqual({ availableThreads: 2, status: "already_claimed" });
    expect(events).toEqual(["prepare", "device-mark", "complete", "release"]);
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
