import { describe, expect, it } from "vitest";
import { communityImagePath, opportunityImagePath, userProfileImagePath } from "@/lib/media-upload";

describe("storage paths", () => {
  it("matches mobile community and opportunity folders", () => {
    expect(communityImagePath("uid1", 1700000000000)).toBe("community/uid1/1700000000000.jpg");
    expect(opportunityImagePath("uid1", 1700000000000)).toBe("opportunities/uid1/1700000000000.jpg");
    expect(userProfileImagePath("uid1")).toBe("users/uid1/profile.jpg");
  });
});
