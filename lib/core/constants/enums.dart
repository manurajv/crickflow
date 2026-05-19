enum UserRole { player, scorer, umpire, organizer, viewer }

enum MatchFormat { standard, tennis, custom }

enum MatchType { single, tournament }

enum MatchStatus {
  draft,
  scheduled,
  live,
  inningsBreak,
  completed,
  abandoned,
}

enum InningsStatus { notStarted, inProgress, completed }

enum TournamentFormat { league, knockout, leagueKnockout }

enum TournamentStatus { draft, upcoming, live, completed }

enum BallEventType {
  runs,
  wide,
  noBall,
  bye,
  legBye,
  wicket,
  penalty,
}

enum WicketType {
  bowled,
  caught,
  lbw,
  runOut,
  stumped,
  hitWicket,
  retired,
  other,
}

enum BadgeType {
  batting,
  bowling,
  fielding,
  milestone,
  team,
  matchHero,
}

enum StreamStatus { idle, connecting, live, ended, error }

enum StreamDestination { youtube, customRtmp }

/// Recruitment / marketplace posts on the Community tab.
enum CommunityPostCategory {
  lookingForPlayer,
  lookingForScorer,
  lookingForUmpire,
  lookingForStreamer,
  lookingForCommentator,
  practiceMatch,
  groundAvailable,
  tournamentNeed,
  general,
}
