/**
 * Same-origin relative paths only. Rejects protocol-relative URLs,
 * backslashes, schemes, and encoded-slash open redirects.
 */
export function safeNextPath(raw: string | null | undefined, fallback = "/"): string {
  if (raw == null) return fallback;
  let value = String(raw).trim();
  if (!value) return fallback;

  for (let i = 0; i < 3; i += 1) {
    try {
      const decoded = decodeURIComponent(value);
      if (decoded === value) break;
      value = decoded;
    } catch {
      return fallback;
    }
  }

  value = value.replace(/\\/g, "/").replace(/[\u0000-\u001f\u007f]/g, "");
  if (!value.startsWith("/")) return fallback;
  if (value.startsWith("//")) return fallback;
  if (value.includes("://")) return fallback;

  const lower = value.toLowerCase();
  if (
    lower.includes("javascript:") ||
    lower.includes("data:") ||
    lower.includes("vbscript:")
  ) {
    return fallback;
  }

  const pathOnly = value.split(/[?#]/)[0] ?? "";
  if (!pathOnly.startsWith("/") || pathOnly.startsWith("//") || pathOnly.includes("://")) {
    return fallback;
  }
  if (value.length > 512) return fallback;
  return value;
}

/** Whether the raw value is an in-app path we may redirect to. */
export function isSafeNextPath(raw: string | null | undefined): boolean {
  if (raw == null) return false;
  const trimmed = String(raw).trim();
  if (!trimmed) return false;
  const resolved = safeNextPath(trimmed, "");
  return resolved !== "";
}
