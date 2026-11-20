import {
  BATTING_STYLE_LABELS,
  BOWLING_STYLE_LABELS,
  PLAYING_ROLE_LABELS,
  labelForStoredBattingStyle,
  labelForStoredBowlingStyle,
  type BattingStyle,
  type BowlingStyle,
  type PlayingRole,
} from "@/lib/cricket/player-profile";

const PLAYING_ROLE_KEYS = Object.keys(PLAYING_ROLE_LABELS) as PlayingRole[];

/** Email, phone, and date of birth stay on the owner's account profile only. */
export function canViewPrivateProfileFields(
  viewerUserId: string | null | undefined,
  profileUserId: string | null | undefined,
): boolean {
  if (!viewerUserId || !profileUserId) return false;
  return viewerUserId === profileUserId;
}

export function displayCfPlayerId(raw?: string | null): string {
  const id = raw?.trim();
  return id ? id : "";
}

export function cfPlayerIdLabel(raw?: string | null): string {
  const id = displayCfPlayerId(raw);
  return id ? `ID: ${id}` : "";
}

export function displayPlayingRole(raw?: string | null): string {
  if (!raw?.trim()) return "";
  const key = raw.trim();
  if ((PLAYING_ROLE_KEYS as string[]).includes(key)) {
    return PLAYING_ROLE_LABELS[key as PlayingRole];
  }
  const lower = key.toLowerCase();
  for (const role of PLAYING_ROLE_KEYS) {
    if (PLAYING_ROLE_LABELS[role].toLowerCase() === lower) return PLAYING_ROLE_LABELS[role];
  }
  return key;
}

export function displayBattingStyle(raw?: string | null): string {
  const style = labelForStoredBattingStyle(raw);
  if (style) return BATTING_STYLE_LABELS[style as BattingStyle];
  return raw?.trim() ?? "";
}

export function displayBowlingStyle(raw?: string | null): string {
  const style = labelForStoredBowlingStyle(raw);
  if (style) return BOWLING_STYLE_LABELS[style as BowlingStyle];
  return raw?.trim() ?? "";
}

/** Role, batting, and bowling — same order as the mobile cricket profile header. */
export function roleStylesLine(input: {
  role?: string | null;
  battingStyle?: string | null;
  bowlingStyle?: string | null;
}): string {
  const parts = [
    displayPlayingRole(input.role),
    displayBattingStyle(input.battingStyle),
    displayBowlingStyle(input.bowlingStyle),
  ].filter(Boolean);
  return parts.join(" · ");
}

export function initialsForName(name?: string | null): string {
  const parts = (name ?? "").trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return "?";
  if (parts.length === 1) return parts[0]!.slice(0, 1).toUpperCase();
  return `${parts[0]!.slice(0, 1)}${parts[parts.length - 1]!.slice(0, 1)}`.toUpperCase();
}

export function formatProfileDate(value?: string | Date | null): string {
  if (!value) return "";
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    const raw = String(value).trim();
    return raw.length >= 10 ? raw.slice(0, 10) : raw;
  }
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
}

export function joinedLabel(value?: string | Date | null): string {
  const formatted = formatProfileDate(value);
  return formatted ? `Joined ${formatted}` : "";
}
