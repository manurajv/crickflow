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
  /// Non-delivery wicketkeeper change (fielding team).
  wicketKeeperChange,
  /// Marks end of an over (strike rotation, no legal ball counted).
  endOver,
  /// Manual striker/non-striker position change (swap, short run, etc.).
  batterSwap,
}

/// Reason stored on [BallEventType.batterSwap] events.
enum BatterSwapReason {
  manual,
  shortRun,
  crossedBeforeWicket,
  umpireCorrection,
  other,
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

/// Extra delivery context on a run-out ball (wide / no-ball / bye / leg-bye).
enum RunOutDeliveryKind {
  normal,
  wide,
  noBall,
  bye,
  legBye,
}

enum BadgeType {
  batting,
  bowling,
  fielding,
  captaincy,
  career,
  milestone,
  special,
  team,
  matchHero,
}

enum BadgeTier { bronze, silver, gold, diamond }

/// Whether a badge can be earned multiple times or only once per career.
enum BadgeRepeatability { repeatable, oneTime }

enum BattingClusterType {
  steadyBatter,
  classicist,
  accumulator,
  hardHitter,
  destroyer,
}

enum BowlingClusterType {
  aspirant,
  wildcard,
  economist,
  spearhead,
}

enum TrophyTier { gold, silver, bronze }

enum TrophyCategory { match, tournament }

/// Match award categories shown on the profile Trophies tab.
enum PlayerTrophyKind {
  playerOfMatch('Player Of The Match', '🏆'),
  fighterOfMatch('Fighter Of The Match', '💪'),
  bestBatter('Best Batter', '🏏'),
  bestBowler('Best Bowler', '🎯'),
  bestFielder('Best Fielder', '🧤');

  const PlayerTrophyKind(this.label, this.emoji);

  final String label;
  final String emoji;

  static const profileKinds = [
    playerOfMatch,
    fighterOfMatch,
    bestBatter,
    bestBowler,
    bestFielder,
  ];
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
