import { describe, expect, it } from "vitest";
import { friendlyError } from "@/lib/friendly-error";

describe("friendlyError", () => {
  it("never shows raw Firestore permission errors", () => {
    const err = Object.assign(new Error("Missing or insufficient permissions."), { code: "permission-denied" });
    expect(friendlyError(err)).toContain("don't have access");
    expect(friendlyError(new Error("FirebaseError: Missing or insufficient permissions."))).toContain("don't have access");
  });

  it("maps storage codes", () => {
    const err = Object.assign(new Error("Firebase Storage: User does not have permission"), { code: "storage/unauthorized" });
    expect(friendlyError(err)).toContain("don't have access");
  });

  it("passes through callable messages written for users", () => {
    const err = Object.assign(new Error("Only org admins can approve requests."), { code: "functions/permission-denied" });
    expect(friendlyError(err)).toBe("Only org admins can approve requests.");
  });

  it("uses a clear offline message for connection problems", () => {
    const offline = "No internet connection. Check your connection and try again.";
    expect(friendlyError(Object.assign(new Error("UNAVAILABLE"), { code: "functions/unavailable" }))).toBe(offline);
    expect(friendlyError(Object.assign(new Error("Deadline expired"), { code: "deadline-exceeded" }))).toBe(offline);
    expect(friendlyError(new Error("Failed to fetch"))).toBe(offline);
  });

  it("keeps callable reasons and replaces internal field names with labels", () => {
    const err = Object.assign(
      new Error("Registration documents must be uploaded for this player in this organization: profilePhotoUrl"),
      { code: "functions/invalid-argument" },
    );
    expect(friendlyError(err)).toBe(
      "Registration documents must be uploaded for this player in this organization: Profile photo",
    );
  });

  it("keeps our own messages and uses the fallback for technical ones", () => {
    expect(friendlyError(new Error("Team name is required"))).toBe("Team name is required");
    expect(friendlyError(new TypeError("Cannot read properties of undefined"), "Could not send")).toBe("Could not send");
    expect(friendlyError(undefined, "Could not load")).toBe("Could not load");
  });
});
