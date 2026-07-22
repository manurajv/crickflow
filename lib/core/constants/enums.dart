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

enum TournamentFormat { league, knockout, leagueKnockout, custom }

enum TournamentStatus {
  draft,
  upcoming,
  live,
  completed,
  cancelled,
}

/// Tournament access role (RBAC).
enum TournamentRole { owner, admin, scorer, viewer }

/// Round classification — use [RoundType.custom] with a display name when needed.
enum RoundType {
  groupStage,
  league,
  knockout,
  roundOf32,
  roundOf16,
  quarterFinal,
  semiFinal,
  final_,
  qualifier1,
  qualifier2,
  eliminator,
  thirdPlace,
  custom,
}

extension RoundTypeX on RoundType {
  String get firestoreName => this == RoundType.final_ ? 'final' : name;

  static RoundType fromFirestore(String? value) {
    if (value == null || value.isEmpty) return RoundType.custom;
    if (value == 'final') return RoundType.final_;
    return RoundType.values.firstWhere(
      (e) => e.firestoreName == value || e.name == value,
      orElse: () => RoundType.custom,
    );
  }

  String defaultLabel() {
    return switch (this) {
      RoundType.groupStage => 'Group Stage',
      RoundType.league => 'League',
      RoundType.knockout => 'Knockout',
      RoundType.roundOf32 => 'Round of 32',
      RoundType.roundOf16 => 'Round of 16',
      RoundType.quarterFinal => 'Quarter Final',
      RoundType.semiFinal => 'Semi Final',
      RoundType.final_ => 'Final',
      RoundType.qualifier1 => 'Qualifier 1',
      RoundType.qualifier2 => 'Qualifier 2',
      RoundType.eliminator => 'Eliminator',
      RoundType.thirdPlace => 'Third Place',
      RoundType.custom => 'Custom',
    };
  }
}

/// Tournament official assignment role.
enum TournamentOfficialRole {
  scorer,
  umpire,
  commentator,
  streamer,
  photographer,
  videographer,
}

/// Lifecycle for tournament official roster entries.
enum TournamentOfficialStatus {
  active,
  pending,
  declined,
}

enum SponsorType {
  title,
  poweredBy,
  associate,
  mediaPartner,
}

/// Tournament / series category (organizer classification).
enum TournamentCategory {
  open,
  corporate,
  community,
  school,
  other,
  series,
  college,
  university,
}

/// Extended match format labels for tournaments.
enum TournamentMatchFormat {
  limitedOvers,
  boxTurf,
  pairCricket,
  testMatch,
  theHundred,
}

enum WinningPrizeType { cash, trophies, both }

enum TournamentMatchSchedule {
  weekends,
  weekdays,
  allDays,
}

enum TournamentDayNight {
  day,
  night,
  dayAndNight,
}

enum OfficialBudgetBand {
  day500to1000,
  day1100to1500,
  day1600to2000,
  day2000plus,
  dayNotDecided,
  match100to500,
  match600to1000,
  match1100to1500,
  match1500plus,
  matchNotDecided,
}

enum OfficialContactMethod {
  inAppMessage,
  whatsApp,
  phoneCall,
  email,
  hide,
}

/// How tournament contact details appear on Community tournament cards.
enum CommunityContactVisibility {
  hide,
  phone,
  whatsapp,
  email,
  /// Message organizer via in-app CrickFlow chat.
  crickflowDm,
}

/// Aspect ratio chosen when cropping community / tournament media.
enum CommunityMediaAspect {
  square,
  landscape16x9,
  portrait9x16,
  free,
}

extension CommunityMediaAspectX on CommunityMediaAspect {
  double get displayRatio => switch (this) {
        CommunityMediaAspect.square => 1,
        CommunityMediaAspect.landscape16x9 => 16 / 9,
        CommunityMediaAspect.portrait9x16 => 9 / 16,
        CommunityMediaAspect.free => 4 / 3,
      };

  String get label => switch (this) {
        CommunityMediaAspect.square => '1:1 Square',
        CommunityMediaAspect.landscape16x9 => '16:9 Landscape',
        CommunityMediaAspect.portrait9x16 => '9:16 Portrait',
        CommunityMediaAspect.free => 'Free crop',
      };

  static CommunityMediaAspect parse(
    String? name, {
    CommunityMediaAspect fallback = CommunityMediaAspect.landscape16x9,
  }) {
    if (name == null || name.isEmpty) return fallback;
    return CommunityMediaAspect.values.firstWhere(
      (e) => e.name == name,
      orElse: () => fallback,
    );
  }
}

/// High-level post kind for create-post UX (maps onto [CommunityPostCategory]).
enum CommunityPostKind {
  general,
  tournament,
  team,
  achievement,
  match,
  image,
  video,
}

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
  team,
  achievement,
  match,
}
