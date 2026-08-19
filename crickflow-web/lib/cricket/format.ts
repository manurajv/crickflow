import { format, formatDistanceToNow } from "date-fns";

export function formatOvers(legalBalls: number, ballsPerOver = 6): string {
  const bpo = ballsPerOver > 0 ? ballsPerOver : 6;
  const overs = Math.floor(legalBalls / bpo);
  const balls = legalBalls % bpo;
  return `${overs}.${balls}`;
}

export function formatMatchWhen(date?: Date | null): string {
  if (!date) return "Yet to start";
  return format(date, "d MMM yyyy, h:mm a");
}

export function formatRelativeTime(date?: Date | null): string {
  if (!date) return "";
  return formatDistanceToNow(date, { addSuffix: true });
}

export function strikeRate(runs: number, balls: number): string {
  if (balls <= 0) return "—";
  return ((runs / balls) * 100).toFixed(1);
}

export function economy(runs: number, balls: number, ballsPerOver = 6): string {
  if (balls <= 0) return "—";
  const overs = balls / (ballsPerOver || 6);
  return (runs / overs).toFixed(2);
}

export function battingAverage(runs: number, dismissals: number): string {
  if (dismissals <= 0) return runs > 0 ? runs.toString() : "—";
  return (runs / dismissals).toFixed(2);
}

export function matchStatusLabel(status: string): string {
  switch (status) {
    case "live":
      return "Live";
    case "inningsBreak":
      return "Innings break";
    case "scheduled":
    case "tossCompleted":
      return "Upcoming";
    case "completed":
      return "Completed";
    case "abandoned":
      return "Abandoned";
    case "draft":
      return "Draft";
    default:
      return status;
  }
}

export function locationLabel(location?: {
  placeName?: string;
  city?: string;
  district?: string;
  stateProvince?: string;
  country?: string;
}): string {
  if (!location) return "";
  const parts = [
    location.placeName,
    location.city,
    location.district,
    location.stateProvince,
    location.country,
  ].filter((part) => part && part.trim().length > 0);
  const unique: string[] = [];
  for (const part of parts) {
    if (!unique.some((item) => item.toLowerCase() === part!.toLowerCase())) {
      unique.push(part!);
    }
  }
  return unique.join(", ");
}

export function currentScore(match: {
  innings: Array<{ totalRuns: number; totalWickets: number; legalBalls: number }>;
  currentInningsIndex: number;
  rules: { ballsPerOver: number };
}): { runs: number; wickets: number; overs: string } | null {
  const innings = match.innings[match.currentInningsIndex];
  if (!innings) return null;
  return {
    runs: innings.totalRuns,
    wickets: innings.totalWickets,
    overs: formatOvers(innings.legalBalls, match.rules.ballsPerOver || 6),
  };
}
