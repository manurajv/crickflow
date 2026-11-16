import { describe, expect, it } from "vitest";
import { mergePendingApprovalLists } from "@/features/series/repository";
import type { SeriesApproval } from "@/features/series/types";

function item(id: string, extra: Partial<SeriesApproval> = {}): SeriesApproval {
  return {
    id,
    targetType: "clubRegistration",
    targetId: id,
    requestedBy: "u1",
    metadata: {},
    ...extra,
  };
}

describe("mergePendingApprovalLists", () => {
  it("unions by id and lets later lists win", () => {
    const merged = mergePendingApprovalLists(
      [item("a", { requestedBy: "old" }), item("b")],
      [item("a", { requestedBy: "new" })],
      null,
    );
    expect(merged.map((x) => x.id).sort()).toEqual(["a", "b"]);
    expect(merged.find((x) => x.id === "a")?.requestedBy).toBe("new");
  });

  it("returns the first available queue when the other is missing", () => {
    expect(mergePendingApprovalLists(undefined, [item("only")])).toEqual([
      item("only"),
    ]);
  });
});
