export type UserRole = "player" | "scorer" | "umpire" | "organizer" | "viewer";

export type MatchStatus =
  | "draft"
  | "scheduled"
  | "tossCompleted"
  | "live"
  | "inningsBreak"
  | "completed"
  | "abandoned";

export type MatchType = "single" | "tournament";

export type CricketBallType = "leather" | "tennis" | "indoor";

export type CricketMatchType = "limitedOvers" | "indoor" | "testMatch" | "boxTurf";

export type TournamentFormat = "league" | "knockout" | "leagueKnockout" | "custom";

export type TournamentStatus =
  | "draft"
  | "upcoming"
  | "live"
  | "completed"
  | "cancelled";

export type StreamStatus = "idle" | "live" | "ended" | "error";

export type ChatStatus = "active" | "request" | "declined";

export type OpportunityStatus = "active" | "expired" | "removed";

export const LIVE_STATUSES: MatchStatus[] = ["live", "inningsBreak"];

export const UPCOMING_STATUSES: MatchStatus[] = [
  "scheduled",
  "tossCompleted",
  "draft",
];

export const COMMUNITY_CATEGORIES = [
  "lookingForPlayer",
  "lookingForScorer",
  "lookingForUmpire",
  "lookingForStreamer",
  "lookingForCommentator",
  "practiceMatch",
  "groundAvailable",
  "tournamentNeed",
  "general",
  "team",
  "achievement",
  "match",
] as const;

export type CommunityCategory = (typeof COMMUNITY_CATEGORIES)[number];

export const COMMUNITY_LABELS: Record<CommunityCategory, string> = {
  lookingForPlayer: "Looking for a player",
  lookingForScorer: "Looking for a scorer",
  lookingForUmpire: "Looking for an umpire",
  lookingForStreamer: "Looking for a streamer",
  lookingForCommentator: "Looking for a commentator",
  practiceMatch: "Practice match",
  groundAvailable: "Ground available",
  tournamentNeed: "Tournament need",
  general: "General",
  team: "Team",
  achievement: "Achievement",
  match: "Match",
};

export const OPPORTUNITY_CATEGORIES = [
  "findPlayer",
  "findTeam",
  "findUmpire",
  "findScorer",
  "findCoach",
  "findGround",
  "findTournament",
  "findSponsor",
  "findCommentator",
  "findStreamingCrew",
  "findPhotographer",
  "findVideographer",
] as const;

export type OpportunityCategory = (typeof OPPORTUNITY_CATEGORIES)[number];

export const OPPORTUNITY_LABELS: Record<OpportunityCategory, string> = {
  findPlayer: "Find a Player",
  findTeam: "Find a Team",
  findUmpire: "Find an Umpire",
  findScorer: "Find Scorer",
  findCoach: "Find a Coach",
  findGround: "Find Ground",
  findTournament: "Find Tournament",
  findSponsor: "Find Sponsor",
  findCommentator: "Find Commentator",
  findStreamingCrew: "Find Streaming Crew",
  findPhotographer: "Find Photographer",
  findVideographer: "Find Videographer",
};

export type RankingsSection = "batting" | "bowling" | "fielding";

export type RankingsCategory =
  | "mostRuns"
  | "highestScore"
  | "mostFifties"
  | "mostHundreds"
  | "mostWickets"
  | "bestBowlingFigures"
  | "mostCatches"
  | "mostRunOuts"
  | "mostStumpings";

export const RANKING_CATEGORY_LABELS: Record<RankingsCategory, string> = {
  mostRuns: "Most Runs",
  highestScore: "Highest Individual Scores",
  mostFifties: "Fifties",
  mostHundreds: "Centuries",
  mostWickets: "Most Wickets",
  bestBowlingFigures: "Best Bowling",
  mostCatches: "Most Catches",
  mostRunOuts: "Most Run Outs",
  mostStumpings: "Best Fielding",
};

export type OversFilter = "all" | "overs1to12" | "overs13to20" | "overs21to99" | "testMatch";
