import type { BallEvent } from "@/types/models";

const LABELS: Record<string, string> = {
  wide: "Wide",
  noBall: "No Ball",
  bye: "Bye",
  legBye: "Leg Bye",
  retiredHurt: "Retired Hurt",
  retiredOut: "Retired Out",
  runs: "Runs",
  wicket: "Wicket",
};

export function eventTypeLabel(eventType: string): string {
  return LABELS[eventType] ?? eventType;
}

export function extrasFromEvents(events: BallEvent[]) {
  return events.reduce(
    (acc, event) => {
      const type = event.eventType;
      if (type === "wide") acc.wides += event.extraRuns || event.runs;
      else if (type === "noBall") acc.noBalls += event.extraRuns || 1;
      else if (type === "bye") acc.byes += event.extraRuns || event.runs;
      else if (type === "legBye") acc.legByes += event.extraRuns || event.runs;
      return acc;
    },
    { wides: 0, noBalls: 0, byes: 0, legByes: 0 },
  );
}

export function notificationHref(item: {
  matchId?: string;
  tournamentId?: string;
  playerId?: string;
  teamId?: string;
  requestId?: string;
  chatId?: string;
  tab?: string;
  type?: string;
}): string | null {
  const type = item.type ?? "";
  if (type === "community_like" || type === "community_comment" || type === "community_mention") {
    return item.requestId ? `/community/${item.requestId}` : "/community";
  }
  if ((type === "player_follow" || type === "follower_milestone") && item.playerId) {
    return `/players/${item.playerId}`;
  }
  if (item.chatId) return `/chat/${item.chatId}`;
  if (item.matchId) {
    if (type === "stream_started") return `/matches/${item.matchId}/watch`;
    if (type === "match_result" || type === "match_drawn" || type === "match_abandoned" || type === "hero_of_match") {
      return `/matches/${item.matchId}/scorecard`;
    }
    if (
      type === "wicket" ||
      type === "hat_trick" ||
      type === "match_started" ||
      type.includes("innings") ||
      type.includes("break") ||
      type.includes("milestone")
    ) {
      return `/matches/${item.matchId}/live`;
    }
    if (item.tab === "live") return `/matches/${item.matchId}/live`;
    return `/matches/${item.matchId}`;
  }
  if (item.tournamentId) return `/tournaments/${item.tournamentId}`;
  if (item.playerId) return `/players/${item.playerId}`;
  if (item.teamId) return `/teams/${item.teamId}`;
  if (item.requestId) return `/community/${item.requestId}`;
  return null;
}

export function notificationCategoryLabel(category?: string, type?: string): string {
  const key = (category || type || "system").replace(/_/g, " ");
  const labels: Record<string, string> = {
    live_match: "Live match",
    community: "Community",
    social: "Social",
    achievement: "Achievement",
    streaming: "Streaming",
    tournament: "Tournament",
    team: "Team",
    match: "Match",
    badge: "Badge",
    system: "System",
    community_like: "Post liked",
    community_comment: "New comment",
    player_follow: "New follower",
    stream_started: "Stream",
    match_started: "Match started",
    wicket: "Wicket",
  };
  return labels[category || ""] || labels[type || ""] || key;
}

export function matchInvolvesPlayer(match: { innings: { batsmen: { playerId: string }[]; bowlers: { playerId: string }[] }[] }, playerId: string) {
  if (!playerId) return false;
  return match.innings.some(
    (inn) =>
      inn.batsmen.some((row) => row.playerId === playerId) ||
      inn.bowlers.some((row) => row.playerId === playerId),
  );
}
