import 'package:equatable/equatable.dart';

import '../../domain/services/commentary_feed_models.dart';
import '../../domain/services/match_summary_models.dart';

class LivePlayerLine extends Equatable {
  const LivePlayerLine({
    required this.name,
    required this.isStriker,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.strikeRate,
    this.playerId,
    this.photoUrl,
  });

  final String? playerId;
  final String name;
  final bool isStriker;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final double strikeRate;
  final String? photoUrl;

  String get scoreLine => '$runs ($balls)';

  @override
  List<Object?> get props => [playerId, runs, balls];
}

class LiveBowlerLine extends Equatable {
  const LiveBowlerLine({
    required this.name,
    required this.overs,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.economy,
    this.playerId,
  });

  final String? playerId;
  final String name;
  final String overs;
  final int maidens;
  final int runs;
  final int wickets;
  final double economy;

  String get figuresLine => '$overs-$maidens-$runs-$wickets';

  @override
  List<Object?> get props => [playerId, wickets, runs];
}

class LiveTargetRevisionInfo extends Equatable {
  const LiveTargetRevisionInfo({
    this.originalTarget,
    this.revisedTarget,
    this.reason,
    this.dlsApplied = false,
    this.penaltyRuns,
  });

  final int? originalTarget;
  final int? revisedTarget;
  final String? reason;
  final bool dlsApplied;
  final int? penaltyRuns;

  bool get hasData =>
      originalTarget != null ||
      revisedTarget != null ||
      (reason != null && reason!.isNotEmpty) ||
      penaltyRuns != null;

  @override
  List<Object?> get props => [originalTarget, revisedTarget];
}

class LiveAlertChip extends Equatable {
  const LiveAlertChip({
    required this.label,
    required this.kind,
  });

  final String label;
  final LiveAlertKind kind;

  @override
  List<Object?> get props => [label, kind];
}

enum LiveAlertKind {
  wicket,
  boundary,
  partnership,
  chase,
  revision,
  general,
}

class MatchLiveSnapshot {
  const MatchLiveSnapshot({
    this.hasData = false,
    this.isInningsBreak = false,
    this.battingTeamName = '',
    this.scoreLine = '0/0',
    this.oversLine = '0.0 Ov',
    this.statusLabel = 'LIVE',
    this.currentRunRate,
    this.requiredRunRate,
    this.target,
    this.runsNeeded,
    this.ballsRemaining,
    this.dlsParScore,
    this.dlsApplied = false,
    this.chaseStatusLine,
    this.insightBanner,
    this.batters = const [],
    this.bowlers = const [],
    this.partnershipRuns,
    this.partnershipBalls,
    this.projectedScore,
    this.projectedChase,
    this.milestones = const [],
    this.heroes = const [],
    this.awards = const [],
    this.alerts = const [],
    this.powerplayLabel,
    this.targetRevision,
    this.totalViews,
    this.liveViewers,
    this.overSummary,
    this.recentCommentary = const [],
    this.contextLine,
  });

  final bool hasData;
  final bool isInningsBreak;
  final String battingTeamName;
  final String scoreLine;
  final String oversLine;
  final String statusLabel;
  final double? currentRunRate;
  final double? requiredRunRate;
  final int? target;
  final int? runsNeeded;
  final int? ballsRemaining;
  final int? dlsParScore;
  final bool dlsApplied;
  final String? chaseStatusLine;
  final String? insightBanner;
  final List<LivePlayerLine> batters;
  final List<LiveBowlerLine> bowlers;
  final int? partnershipRuns;
  final int? partnershipBalls;
  final int? projectedScore;
  final int? projectedChase;
  final List<String> milestones;
  final List<SummaryHeroCard> heroes;
  final List<MatchSummaryAward> awards;
  final List<LiveAlertChip> alerts;
  final String? powerplayLabel;
  final LiveTargetRevisionInfo? targetRevision;
  final int? totalViews;
  final int? liveViewers;
  final OverSummaryCommentaryItem? overSummary;
  final List<CommentaryFeedItem> recentCommentary;
  final String? contextLine;

  static const empty = MatchLiveSnapshot();

  bool get hasPlayerStats => batters.isNotEmpty || bowlers.isNotEmpty;

  bool get hasMilestones => milestones.isNotEmpty;

  bool get hasHeroes => heroes.isNotEmpty || awards.isNotEmpty;

  bool get hasCommentary =>
      overSummary != null || recentCommentary.isNotEmpty;
}
