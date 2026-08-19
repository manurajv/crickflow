import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function asRecord(value: unknown): Record<string, unknown> | null {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

export function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

export function asNumber(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

export function asBoolean(value: unknown, fallback = false): boolean {
  return typeof value === "boolean" ? value : fallback;
}

export function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === "string");
}

export function parseDate(value: unknown): Date | null {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value === "object") {
    const record = value as { toDate?: () => Date; seconds?: number };
    if (typeof record.toDate === "function") return record.toDate();
    if (typeof record.seconds === "number") {
      return new Date(record.seconds * 1000);
    }
  }
  return null;
}

export function firstGrapheme(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return "?";
  if (typeof Intl !== "undefined" && "Segmenter" in Intl) {
    const parts = new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(trimmed);
    return [...parts][0]?.segment ?? "?";
  }
  return Array.from(trimmed)[0] ?? "?";
}

export function slugify(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80);
}

export function haversineKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const toRad = (n: number) => (n * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function searchScore(haystack: string, query: string): number {
  const h = haystack.trim().toLowerCase();
  const q = query.trim().toLowerCase();
  if (!h || !q) return 0;
  if (h === q) return 1000;
  if (h.startsWith(q)) return 800;
  if (h.includes(q)) return 500;
  return 0;
}

export function searchHaystack(query: string, parts: Array<string | undefined | null>) {
  const q = query.trim();
  if (!q) return 1;
  return Math.max(0, ...parts.map((part) => searchScore(part ?? "", q)));
}

export function youtubeEmbedId(url?: string): string | null {
  if (!url) return null;
  const match = url.match(
    /(?:v=|\/live\/|youtu\.be\/|\/embed\/)([A-Za-z0-9_-]{6,})/,
  );
  return match?.[1] ?? null;
}
