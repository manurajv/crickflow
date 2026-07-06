import 'package:equatable/equatable.dart';

import '../../../../domain/wagon_wheel/wagon_wheel_analytics_service.dart';

/// Slideshow screen identifiers for the innings break presentation.
enum InningsBreakScreenKind {
  battingScorecard,
  bowlingFigures,
  inningsSummary,
  battingHighlights,
  bowlingHighlights,
  matchSituation,
  partnerships,
  fallOfWickets,
  analytics,
  thankYou,
}

class InningsBreakBatterRow extends Equatable {
  const InningsBreakBatterRow({
    required this.playerId,
    required this.name,
    required this.runs,
    required this.balls,
    required this.strikeRate,
    required this.dismissal,
    required this.isOut,
    this.fielderNames = '',
    this.bowlerName = '',
    this.didNotBat = false,
  });

  final String playerId;
  final String name;
  final int runs;
  final int balls;
  final double strikeRate;
  final String dismissal;
  final String fielderNames;
  final String bowlerName;
  final bool isOut;
  final bool didNotBat;

  @override
  List<Object?> get props => [
        playerId,
        name,
        runs,
        balls,
        strikeRate,
        dismissal,
        fielderNames,
        bowlerName,
        isOut,
        didNotBat,
      ];
}

class InningsBreakBowlerRow extends Equatable {
  const InningsBreakBowlerRow({
    required this.playerId,
    required this.name,
    required this.overs,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.economy,
    this.isBest = false,
  });

  final String playerId;
  final String name;
  final String overs;
  final int maidens;
  final int runs;
  final int wickets;
  final double economy;
  final bool isBest;

  @override
  List<Object?> get props =>
      [playerId, name, overs, maidens, runs, wickets, economy, isBest];
}

class InningsBreakHighlightCard extends Equatable {
  const InningsBreakHighlightCard({
    required this.title,
    required this.playerName,
    this.playerId = '',
    this.photoUrl,
    this.value = '',
    this.subtitle = '',
    this.statRuns,
    this.statBalls,
  });

  final String title;
  final String playerName;
  final String playerId;
  final String? photoUrl;
  final String value;
  final String subtitle;
  /// When set with [statBalls], shown as runs + balls like the batting scorecard.
  final int? statRuns;
  final int? statBalls;

  @override
  List<Object?> get props => [
        title,
        playerName,
        playerId,
        photoUrl,
        value,
        subtitle,
        statRuns,
        statBalls,
      ];
}

class InningsBreakPartnershipRow extends Equatable {
  const InningsBreakPartnershipRow({
    required this.batterAName,
    required this.batterBName,
    required this.runs,
    required this.balls,
    this.batterAPhotoUrl,
    this.batterBPhotoUrl,
  });

  final String batterAName;
  final String batterBName;
  final int runs;
  final int balls;
  final String? batterAPhotoUrl;
  final String? batterBPhotoUrl;

  @override
  List<Object?> get props =>
      [batterAName, batterBName, runs, balls, batterAPhotoUrl, batterBPhotoUrl];
}

class InningsBreakFallOfWicketRow extends Equatable {
  const InningsBreakFallOfWicketRow({
    required this.wicketNumber,
    required this.score,
    required this.over,
    required this.batterName,
    required this.dismissal,
    this.fielderNames = '',
    this.bowlerName = '',
  });

  final int wicketNumber;
  final int score;
  final String over;
  final String batterName;
  final String dismissal;
  final String fielderNames;
  final String bowlerName;

  @override
  List<Object?> get props => [
        wicketNumber,
        score,
        over,
        batterName,
        dismissal,
        fielderNames,
        bowlerName,
      ];
}

/// Read-only data for the first-innings break slideshow.
class InningsBreakSnapshot extends Equatable {
  const InningsBreakSnapshot({
    required this.matchTitle,
    required this.inningsTitle,
    required this.battingTeamName,
    required this.bowlingTeamName,
    required this.battingTeamLogoUrl,
    required this.bowlingTeamLogoUrl,
    required this.tournamentLogoUrl,
    required this.tournamentName,
    required this.venue,
    required this.crickflowLogoUrl,
    required this.sponsorLogoUrls,
    required this.batters,
    required this.bowlers,
    required this.extras,
    required this.extrasDetail,
    required this.totalRuns,
    required this.totalWickets,
    required this.overs,
    required this.runRate,
    required this.fours,
    required this.sixes,
    required this.dotBalls,
    required this.boundaries,
    required this.partnershipTotal,
    required this.battingHighlights,
    required this.bowlingHighlights,
    required this.partnerships,
    required this.fallOfWickets,
    required this.target,
    required this.runsRequired,
    required this.oversRemaining,
    required this.requiredRunRate,
    required this.chaseOvers,
    required this.ballsPerOver,
    required this.wagonWheelShots,
    required this.wagonWheelInsights,
    required this.hasAnalytics,
    required this.screens,
  });

  static const empty = InningsBreakSnapshot(
    matchTitle: '',
    inningsTitle: '',
    battingTeamName: '',
    bowlingTeamName: '',
    battingTeamLogoUrl: '',
    bowlingTeamLogoUrl: '',
    tournamentLogoUrl: '',
    tournamentName: '',
    venue: '',
    crickflowLogoUrl: '',
    sponsorLogoUrls: [],
    batters: [],
    bowlers: [],
    extras: 0,
    extrasDetail: '',
    totalRuns: 0,
    totalWickets: 0,
    overs: '',
    runRate: 0,
    fours: 0,
    sixes: 0,
    dotBalls: 0,
    boundaries: 0,
    partnershipTotal: 0,
    battingHighlights: [],
    bowlingHighlights: [],
    partnerships: [],
    fallOfWickets: [],
    target: 0,
    runsRequired: 0,
    oversRemaining: 0,
    requiredRunRate: 0,
    chaseOvers: 0,
    ballsPerOver: 6,
    wagonWheelShots: [],
    wagonWheelInsights: null,
    hasAnalytics: false,
    screens: InningsBreakScreenKind.values,
  );

  final String matchTitle;
  final String inningsTitle;
  final String battingTeamName;
  final String bowlingTeamName;
  final String? battingTeamLogoUrl;
  final String? bowlingTeamLogoUrl;
  final String? tournamentLogoUrl;
  final String tournamentName;
  final String venue;
  final String crickflowLogoUrl;
  final List<String> sponsorLogoUrls;
  final List<InningsBreakBatterRow> batters;
  final List<InningsBreakBowlerRow> bowlers;
  final int extras;
  final String extrasDetail;
  final int totalRuns;
  final int totalWickets;
  final String overs;
  final double runRate;
  final int fours;
  final int sixes;
  final int dotBalls;
  final int boundaries;
  final int partnershipTotal;
  final List<InningsBreakHighlightCard> battingHighlights;
  final List<InningsBreakHighlightCard> bowlingHighlights;
  final List<InningsBreakPartnershipRow> partnerships;
  final List<InningsBreakFallOfWicketRow> fallOfWickets;
  final int target;
  final int runsRequired;
  final int oversRemaining;
  final double requiredRunRate;
  final int chaseOvers;
  final int ballsPerOver;
  final List<WagonWheelShotPoint> wagonWheelShots;
  final WagonWheelInsights? wagonWheelInsights;
  final bool hasAnalytics;
  final List<InningsBreakScreenKind> screens;

  bool get isValid => batters.isNotEmpty && matchTitle.isNotEmpty;

  @override
  List<Object?> get props => [matchTitle, inningsNumberHash];

  int get inningsNumberHash => totalRuns + totalWickets;
}

/// Chase opening pair after second-innings lineup is confirmed.
class ChaseOpeningBatsmenSnapshot extends Equatable {
  const ChaseOpeningBatsmenSnapshot({
    required this.strikerId,
    required this.strikerName,
    required this.nonStrikerId,
    required this.nonStrikerName,
    required this.battingTeamName,
    required this.battingTeamLogoUrl,
    required this.matchTitle,
    required this.firstInningsScore,
    required this.target,
    required this.requiredRunRate,
    required this.crickflowLogoUrl,
  });

  final String strikerId;
  final String strikerName;
  final String nonStrikerId;
  final String nonStrikerName;
  final String battingTeamName;
  final String? battingTeamLogoUrl;
  final String matchTitle;
  final String firstInningsScore;
  final int target;
  final double requiredRunRate;
  final String crickflowLogoUrl;

  bool get isValid =>
      strikerId.isNotEmpty &&
      nonStrikerId.isNotEmpty &&
      battingTeamName.isNotEmpty;

  @override
  List<Object?> get props =>
      [strikerId, nonStrikerId, target, firstInningsScore];
}

/// Opening bowler for the chase innings.
class ChaseOpeningBowlerSnapshot extends Equatable {
  const ChaseOpeningBowlerSnapshot({
    required this.playerId,
    required this.fallbackName,
    required this.inningsBestFigures,
    required this.inningsEconomy,
  });

  final String playerId;
  final String fallbackName;
  final String inningsBestFigures;
  final double inningsEconomy;

  bool get isValid => playerId.isNotEmpty;

  @override
  List<Object?> get props => [playerId, fallbackName];
}
