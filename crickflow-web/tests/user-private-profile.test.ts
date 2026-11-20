import { describe, expect, it } from "vitest";
import {
  mergePrivateUserProfile,
  privateUserProfilePayload,
} from "@/lib/firebase/user-private-profile";
import {
  DEFAULT_NOTIFICATION_PREFERENCES,
  parseNotificationPreferences,
} from "@/features/settings/notification-preferences";

describe("mergePrivateUserProfile", () => {
  it("prefers private email, phone, and date of birth", () => {
    const merged = mergePrivateUserProfile(
      {
        email: "old@example.com",
        phoneNumber: "+94000000000",
        dob: "1990-01-01",
      },
      {
        email: "new@example.com",
        phoneNumber: "+94711111111",
        dob: "1991-02-02",
      },
    );
    expect(merged.email).toBe("new@example.com");
    expect(merged.phoneNumber).toBe("+94711111111");
    expect(merged.mobile).toBe("+94711111111");
    expect(merged.dob).toBe("1991-02-02");
  });

  it("falls back to parent when private values are empty", () => {
    const merged = mergePrivateUserProfile(
      { email: "keep@example.com", phoneNumber: "+94700000000" },
      { email: "  ", phoneNumber: null },
    );
    expect(merged.email).toBe("keep@example.com");
    expect(merged.phoneNumber).toBe("+94700000000");
  });
});

describe("privateUserProfilePayload", () => {
  it("mirrors phone aliases", () => {
    const payload = privateUserProfilePayload({
      email: "a@b.c",
      phoneNumber: "+94701036188",
      dateOfBirth: "1990-05-05",
    });
    expect(payload.phoneNumber).toBe("+94701036188");
    expect(payload.mobile).toBe("+94701036188");
    expect(payload.dob).toBe("1990-05-05");
  });
});

describe("parseNotificationPreferences", () => {
  it("defaults both toggles to true", () => {
    expect(parseNotificationPreferences({})).toEqual(DEFAULT_NOTIFICATION_PREFERENCES);
  });

  it("reads notificationPrefs from a user document", () => {
    expect(
      parseNotificationPreferences({
        notificationPrefs: {
          receiveTeamMatchNotifications: false,
          receiveFollowerNotifications: true,
        },
      }),
    ).toEqual({
      receiveTeamMatchNotifications: false,
      receiveFollowerNotifications: true,
    });
  });
});
