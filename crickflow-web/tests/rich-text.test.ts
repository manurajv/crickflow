import { describe, expect, it } from "vitest";
import {
  isSafeHref,
  parseAnnouncementBody,
  sanitizeAnnouncementText,
  stripHtml,
} from "@/lib/rich-text";

describe("announcement sanitizer", () => {
  it("strips script and tags", () => {
    expect(stripHtml('<script>alert(1)</script>Hello')).toBe("alert(1)Hello");
    expect(sanitizeAnnouncementText("<img src=x onerror=alert(1)>Safe", 2000)).toBe("Safe");
    expect(sanitizeAnnouncementText("javascript:alert(1) hi", 2000)).not.toMatch(/javascript/i);
  });

  it("parses markdown without raw HTML", () => {
    const nodes = parseAnnouncementBody("**Bold** and *italic*\n- item\n[ok](https://crickflow.web.app/)\n[bad](javascript:alert(1))");
    const flat = JSON.stringify(nodes);
    expect(flat).toContain('"type":"strong"');
    expect(flat).toContain('"type":"em"');
    expect(flat).toContain('"type":"ul"');
    expect(flat).toContain("https://crickflow.web.app/");
    expect(flat).not.toContain("javascript:");
    expect(flat).toContain('"text":"bad"');
  });

  it("rejects unsafe hrefs", () => {
    expect(isSafeHref("https://example.com")).toBe(true);
    expect(isSafeHref("/series/abc")).toBe(true);
    expect(isSafeHref("//evil.com")).toBe(false);
    expect(isSafeHref("javascript:alert(1)")).toBe(false);
    expect(isSafeHref("data:text/html,hi")).toBe(false);
  });
});
