import { describe, expect, it } from "vitest";
import { reportReasonValue } from "@/lib/report";

describe("report reasons", () => {
  it("includes details when provided", () => {
    expect(reportReasonValue("spam")).toBe("Spam");
    expect(reportReasonValue("other", "copied listing")).toBe("Other: copied listing");
  });
});
