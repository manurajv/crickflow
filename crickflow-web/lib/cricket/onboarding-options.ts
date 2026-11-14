import { isSafeNextPath, safeNextPath } from "@/lib/auth/safe-next-path";

/** Dial codes mirrored from Flutter `CricketCountry.phoneDialCodes`. */
export const PHONE_DIAL_CODES = [
  "+94",
  "+91",
  "+92",
  "+880",
  "+44",
  "+61",
  "+64",
  "+27",
  "+1",
  "+971",
] as const;

export const COMMON_COUNTRIES = [
  "Sri Lanka",
  "India",
  "Pakistan",
  "Bangladesh",
  "England",
  "Australia",
  "New Zealand",
  "South Africa",
  "United Arab Emirates",
  "United States",
  "Other",
] as const;

export type PlayerGender = "male" | "female" | "other";

export const PLAYER_GENDERS: PlayerGender[] = ["male", "female", "other"];

export const PLAYER_GENDER_LABELS: Record<PlayerGender, string> = {
  male: "Male",
  female: "Female",
  other: "Other",
};

export function phoneNumberHint(dial: string): string {
  switch (dial) {
    case "+94":
      return "771234567";
    case "+91":
      return "9876543210";
    case "+92":
      return "3001234567";
    case "+880":
      return "1712345678";
    case "+44":
      return "7911123456";
    case "+61":
      return "412345678";
    case "+64":
      return "211234567";
    case "+27":
      return "821234567";
    case "+1":
      return "2025551234";
    case "+971":
      return "501234567";
    default:
      return "771234567";
  }
}

export function dialCodeForCountry(country: string): string {
  const map: Record<string, string> = {
    "Sri Lanka": "+94",
    India: "+91",
    Pakistan: "+92",
    Bangladesh: "+880",
    England: "+44",
    Australia: "+61",
    "New Zealand": "+64",
    "South Africa": "+27",
    "United Arab Emirates": "+971",
    "United States": "+1",
  };
  return map[country] ?? "+94";
}

const PENDING_NEXT_KEY = "cf_pending_next";

export function stashPendingNext(next: string | null | undefined) {
  if (typeof window === "undefined") return;
  try {
    if (next && isSafeNextPath(next) && !safeNextPath(next).startsWith("/register")) {
      sessionStorage.setItem(PENDING_NEXT_KEY, safeNextPath(next));
    }
  } catch {
    /* ignore */
  }
}

export function takePendingNext(fallback = "/"): string {
  if (typeof window === "undefined") return fallback;
  try {
    const v = sessionStorage.getItem(PENDING_NEXT_KEY);
    sessionStorage.removeItem(PENDING_NEXT_KEY);
    if (v && isSafeNextPath(v) && !safeNextPath(v).startsWith("/register")) {
      const path = safeNextPath(v);
      return path.endsWith("/") || path.includes("?") || path.includes("#") ? path : `${path}/`;
    }
  } catch {
    /* ignore */
  }
  return fallback === "/" ? "/" : fallback;
}
