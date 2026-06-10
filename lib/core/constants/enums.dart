enum UserRole { player, scorer, umpire, organizer, viewer }

enum MatchFormat { standard, tennis, custom }

/// Start-match “Match type” (reference-style).
enum CricketMatchType {
  limitedOvers,
  indoor,
  testMatch,
}

enum PitchType { rough, cement, turf, astroturf, matting }

enum MatchOfficialRole { umpires, scorers, liveStreamer, others }

/// Ball / game type for stats breakdown (Sri Lankan formats).
enum CricketBallType { leather, tennis, indoor }

enum MatchType { single, tournament }

enum MatchStatus {
  draft,
  scheduled,
  /// Toss recorded; first innings not yet started.
  tossCompleted,
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
  /// Non-delivery crease/bowler update (new batter, bowler change).
  lineupChange,
}

/// How runs off a no-ball are scored (from bat, bye, or leg bye).
enum NoBallRunsMode { bat, bye, legBye }

enum WicketType {
  bowled,
  caught,
  caughtBehind,
  caughtAndBowled,
  lbw,
  runOut,
  /// UI-only; persisted on BallEvent as [runOut] with [isMankad].
  mankad,
  stumped,
  hitWicket,
  retiredHurt,
  retiredOut,
  obstructingField,
  timedOut,
  handledBall,
  hitBallTwice,
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
