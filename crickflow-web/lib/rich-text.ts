/**
 * Conservative announcement rich text: a markdown subset rendered as React
 * nodes (never innerHTML). HTML is stripped on input so mobile plain-text
 * views stay readable and XSS cannot land in stored bodies.
 */

const ALLOWED_URL = /^(https?:\/\/|\/)[^\s]*$/i;

export function stripHtml(input: string): string {
  return String(input ?? "")
    .replace(/<\s*br\s*\/?\s*>/gi, "\n")
    .replace(/<\s*\/p\s*>/gi, "\n")
    .replace(/<[^>]*>/g, "")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'");
}

export function sanitizeAnnouncementText(input: string, maxLength: number): string {
  let text = stripHtml(input).replace(/\u0000/g, "").replace(/\r\n?/g, "\n");
  // Neutralize leftover scheme-based payloads after tag stripping.
  text = text.replace(/javascript\s*:/gi, "").replace(/vbscript\s*:/gi, "").replace(/data\s*:/gi, "");
  text = text.trim();
  if (text.length > maxLength) text = text.slice(0, maxLength);
  return text;
}

export function isSafeHref(href: string): boolean {
  const value = href.trim();
  if (!value || value.startsWith("//")) return false;
  if (!ALLOWED_URL.test(value)) return false;
  const lower = value.toLowerCase();
  return !lower.includes("javascript:") && !lower.includes("data:") && !lower.includes("vbscript:");
}

export type RichNode =
  | { type: "text"; text: string }
  | { type: "strong"; children: RichNode[] }
  | { type: "em"; children: RichNode[] }
  | { type: "link"; href: string; children: RichNode[] }
  | { type: "p"; children: RichNode[] }
  | { type: "li"; children: RichNode[] }
  | { type: "ul"; children: RichNode[] }
  | { type: "ol"; children: RichNode[] };

function parseInline(text: string): RichNode[] {
  const nodes: RichNode[] = [];
  const pattern =
    /(\[([^\]]+)\]\(([^)]+)\)|\*\*([^*]+)\*\*|\*([^*]+)\*|_([^_]+)_)/g;
  let last = 0;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(text))) {
    if (match.index > last) {
      nodes.push({ type: "text", text: text.slice(last, match.index) });
    }
    if (match[2] != null && match[3] != null) {
      const href = match[3].trim();
      if (isSafeHref(href)) {
        nodes.push({ type: "link", href, children: [{ type: "text", text: match[2] }] });
      } else {
        nodes.push({ type: "text", text: match[2] });
      }
    } else if (match[4] != null) {
      nodes.push({ type: "strong", children: [{ type: "text", text: match[4] }] });
    } else if (match[5] != null || match[6] != null) {
      nodes.push({ type: "em", children: [{ type: "text", text: match[5] ?? match[6] ?? "" }] });
    }
    last = match.index + match[0].length;
  }
  if (last < text.length) nodes.push({ type: "text", text: text.slice(last) });
  return nodes.length ? nodes : [{ type: "text", text: "" }];
}

export function parseAnnouncementBody(raw: string): RichNode[] {
  const text = sanitizeAnnouncementText(raw, 20000);
  if (!text) return [];
  const lines = text.split("\n");
  const blocks: RichNode[] = [];
  let list: { type: "ul" | "ol"; children: RichNode[] } | null = null;

  const flushList = () => {
    if (list) {
      blocks.push(list);
      list = null;
    }
  };

  for (const line of lines) {
    const ul = line.match(/^\s*[-*]\s+(.+)$/);
    const ol = line.match(/^\s*\d+\.\s+(.+)$/);
    if (ul) {
      if (!list || list.type !== "ul") {
        flushList();
        list = { type: "ul", children: [] };
      }
      list.children.push({ type: "li", children: parseInline(ul[1]) });
      continue;
    }
    if (ol) {
      if (!list || list.type !== "ol") {
        flushList();
        list = { type: "ol", children: [] };
      }
      list.children.push({ type: "li", children: parseInline(ol[1]) });
      continue;
    }
    flushList();
    if (!line.trim()) continue;
    blocks.push({ type: "p", children: parseInline(line) });
  }
  flushList();
  return blocks;
}

/** Insert markdown wrapper around the current selection in a textarea value. */
export function wrapMarkdownSelection(
  value: string,
  start: number,
  end: number,
  prefix: string,
  suffix = prefix,
): { value: string; start: number; end: number } {
  const selected = value.slice(start, end) || "text";
  const next = value.slice(0, start) + prefix + selected + suffix + value.slice(end);
  return {
    value: next,
    start: start + prefix.length,
    end: start + prefix.length + selected.length,
  };
}
