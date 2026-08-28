export const PLAYING_ROLES = [
  "batsman",
  "bowler",
  "allRounder",
  "wicketKeeper",
  "wicketKeeperBatter",
  "bowlingAllRounder",
  "battingAllRounder",
] as const;

export type PlayingRole = (typeof PLAYING_ROLES)[number];

export const PLAYING_ROLE_LABELS: Record<PlayingRole, string> = {
  batsman: "Batsman",
  bowler: "Bowler",
  allRounder: "All Rounder",
  wicketKeeper: "Wicket Keeper",
  wicketKeeperBatter: "Wicket Keeper Batter",
  bowlingAllRounder: "Bowling All Rounder",
  battingAllRounder: "Batting All Rounder",
};

export const BATTING_STYLES = ["rightHandBatsman", "leftHandBatsman"] as const;
export type BattingStyle = (typeof BATTING_STYLES)[number];

export const BATTING_STYLE_LABELS: Record<BattingStyle, string> = {
  rightHandBatsman: "Right Hand Batsman",
  leftHandBatsman: "Left Hand Batsman",
};

export const BOWLING_CATEGORIES = [
  "fast",
  "mediumFast",
  "medium",
  "spin",
  "doNotBowl",
] as const;

export type BowlingCategory = (typeof BOWLING_CATEGORIES)[number];

export const BOWLING_CATEGORY_LABELS: Record<BowlingCategory, string> = {
  fast: "Fast",
  mediumFast: "Medium Fast",
  medium: "Medium",
  spin: "Spin",
  doNotBowl: "Do Not Bowl",
};

export const BOWLING_ARMS = ["rightArm", "leftArm"] as const;
export type BowlingArm = (typeof BOWLING_ARMS)[number];

export const BOWLING_ARM_LABELS: Record<BowlingArm, string> = {
  rightArm: "Right Arm",
  leftArm: "Left Arm",
};

export const BOWLING_STYLES = [
  "rightArmFast",
  "leftArmFast",
  "rightArmMediumFast",
  "leftArmMediumFast",
  "rightArmMedium",
  "leftArmMedium",
  "rightArmOffSpin",
  "rightArmLegSpin",
  "rightArmLegBreak",
  "rightArmGoogly",
  "leftArmOrthodoxSpin",
  "leftArmChinaman",
  "leftArmWristSpin",
  "doNotBowl",
] as const;

export type BowlingStyle = (typeof BOWLING_STYLES)[number];

export const BOWLING_STYLE_LABELS: Record<BowlingStyle, string> = {
  rightArmFast: "Right Arm Fast",
  leftArmFast: "Left Arm Fast",
  rightArmMediumFast: "Right Arm Medium Fast",
  leftArmMediumFast: "Left Arm Medium Fast",
  rightArmMedium: "Right Arm Medium",
  leftArmMedium: "Left Arm Medium",
  rightArmOffSpin: "Right Arm Off Spin",
  rightArmLegSpin: "Right Arm Leg Spin",
  rightArmLegBreak: "Right Arm Leg Break",
  rightArmGoogly: "Right Arm Googly",
  leftArmOrthodoxSpin: "Left Arm Orthodox Spin",
  leftArmChinaman: "Left Arm Chinaman",
  leftArmWristSpin: "Left Arm Wrist Spin",
  doNotBowl: "Do Not Bowl",
};

const SPIN_STYLES_RIGHT: BowlingStyle[] = [
  "rightArmOffSpin",
  "rightArmLegSpin",
  "rightArmLegBreak",
  "rightArmGoogly",
];

const SPIN_STYLES_LEFT: BowlingStyle[] = [
  "leftArmOrthodoxSpin",
  "leftArmChinaman",
  "leftArmWristSpin",
];

export function bowlingStyleFromCategoryAndArm(
  category: BowlingCategory,
  arm: BowlingArm,
): BowlingStyle | null {
  if (category === "doNotBowl") return "doNotBowl";
  if (category === "spin") return null;
  if (category === "fast") return arm === "rightArm" ? "rightArmFast" : "leftArmFast";
  if (category === "mediumFast") {
    return arm === "rightArm" ? "rightArmMediumFast" : "leftArmMediumFast";
  }
  return arm === "rightArm" ? "rightArmMedium" : "leftArmMedium";
}

export function spinStylesForArm(arm: BowlingArm): BowlingStyle[] {
  return arm === "rightArm" ? SPIN_STYLES_RIGHT : SPIN_STYLES_LEFT;
}

export function formatCfPlayerId(sequence: number) {
  return `CF${String(sequence).padStart(6, "0")}`;
}

export function labelForStoredBowlingStyle(raw?: string | null): BowlingStyle | null {
  if (!raw) return null;
  if ((BOWLING_STYLES as readonly string[]).includes(raw)) return raw as BowlingStyle;
  const normalized = raw.trim().toLowerCase();
  for (const style of BOWLING_STYLES) {
    if (BOWLING_STYLE_LABELS[style].toLowerCase() === normalized) return style;
  }
  return null;
}

export function labelForStoredBattingStyle(raw?: string | null): BattingStyle | null {
  if (!raw) return null;
  if ((BATTING_STYLES as readonly string[]).includes(raw)) return raw as BattingStyle;
  const normalized = raw.trim().toLowerCase();
  for (const style of BATTING_STYLES) {
    if (BATTING_STYLE_LABELS[style].toLowerCase() === normalized) return style;
  }
  return null;
}
