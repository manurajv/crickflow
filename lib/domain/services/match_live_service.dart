import '../../core/constants/enums.dart';
import '../../core/utils/cricket_math.dart';
import '../../data/models/innings_model.dart';import '../../data/models/match_model.dart';
import '../../data/models/match_revision_model.dart';import '../../data/models/match_target_state_model.dart';
import '../../domain/scoring/match_lifecycle.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';
import 'commentary_feed_models.dart';
import 'commentary_feed_service.dart';
import 'match_analytics_models.dart';
import 'match_insights_service.dart';
import 'match_live_models.dart';
import 'match_phase_service.dart';

/// Read-only live match snapshot for the Live tab.
class MatchLiveService {
  MatchLiveService({MatchInsightsService? insightsService})
      : _insights = insightsService ?? MatchInsightsService();

  final MatchInsightsService _insights;

  MatchLiveSnapshot build({
    required MatchModel match,
    required CommentaryFeed feed,
    List<MatchRevisionModel> revisions = const [],
    int totalViews = 0,
    int liveViewers = 0,
  }) {
    final isBreak = match.status == MatchStatus.inningsBreak;
    final isLive = MatchLifecycle.isActivelyLive(match) && !isBreak;
    if (!isLive && !isBreak) return MatchLiveSnapshot.empty;

    final innings = match.currentInnings;
    if (innings == null || match.innings.isEmpty) {
      return MatchLiveSnapshot(
        hasData: false,
        isInningsBreak: isBreak,
        statusLabel: isBreak ? 'INNINGS BREAK' : 'LIVE',
        battingTeamName: match.teamAName,
      );
    }

    final rules = match.rules;
    final chase = ScoringDisplayUtils.chaseDisplay(match, innings, rules);
    final crr = ScoringDisplayUtils.currentRunRate(innings, rules);
    final oversText =
        '${ScoringDisplayUtils.inningsOversDisplay(innings, rules)} Ov';
    final battingTeam = ScoringDisplayUtils.battingTeamName(match, innings);
    final targetState = match.targetState;

    final dlsPar = targetState.dlsApplied
        ? (targetState.effectiveRevisedTarget ?? chase?.target)
        : null;

    final chaseLine = _chaseStatusLine(
      match: match,
      innings: innings,
      chase: chase,
      dlsPar: dlsPar,
    );

    final insight = _insightBanner(
      match: match,
      innings: innings,
      battingTeam: battingTeam,
      chase: chase,
      targetState: targetState,
    );

    final milestones = _insights.build(match: match).milestones;

    final batters = _currentBatters(innings);
    final bowlers = _currentBowlers(innings, rules.ballsPerOver);

    final feedItems = feed.filtered(
      inningsNumber: innings.inningsNumber,
      filter: CommentaryFilter.full,
    );
    final lastOver = _lastOverCommentary(feedItems);

    return MatchLiveSnapshot(
      hasData: true,
      isInningsBreak: isBreak,
      battingTeamName: battingTeam,
      scoreLine: '${innings.totalRuns}/${innings.totalWickets}',
      oversLine: oversText,
      statusLabel: isBreak ? 'INNINGS BREAK' : 'LIVE',
      currentRunRate: crr,
      requiredRunRate:
          chase != null && chase.isChasing ? chase.requiredRunRate : null,
      target: chase?.target,
      runsNeeded: chase?.runsNeeded,
      ballsRemaining: chase?.ballsRemaining,
      dlsParScore: dlsPar,
      dlsApplied: targetState.dlsApplied,
      chaseStatusLine: chaseLine,
      insightBanner: insight,
      batters: batters,
      bowlers: bowlers,
      partnershipRuns:
          innings.partnershipRuns > 0 ? innings.partnershipRuns : null,
      partnershipBalls:
          innings.partnershipBalls > 0 ? innings.partnershipBalls : null,
      milestones: milestones,
      powerplayLabel: _powerplayLabel(match, innings),
      targetRevision: _targetRevision(match, revisions),
      totalViews: totalViews,
      liveViewers: liveViewers,
      overSummary: lastOver.overSummary,
      recentCommentary: lastOver.balls,
      contextLine: CommentaryFeedService.primaryContextLine(match, innings),
    );
  }

  ({OverSummaryCommentaryItem? overSummary, List<BallCommentaryItem> balls})
      _lastOverCommentary(List<CommentaryFeedItem> feedItems) {
    int? lastOver;
    for (final item in feedItems) {
      if (item is BallCommentaryItem) {
        lastOver = item.event.overNumber;
        break;
      }
    }

    OverSummaryCommentaryItem? overSummary;
    for (final item in feedItems) {
      if (item is OverSummaryCommentaryItem) {
        lastOver ??= item.overNumber;
        if (item.overNumber == lastOver) {
          overSummary = item;
        }
        break;
      }
    }

    if (lastOver == null) {
      return (overSummary: null, balls: const []);
    }

    final balls = <BallCommentaryItem>[];
    for (final item in feedItems) {
      if (item is BallCommentaryItem && item.event.overNumber == lastOver) {
        balls.add(item);
      }
    }
    return (overSummary: overSummary, balls: balls);
  }

  List<LivePlayerLine> _currentBatters(InningsModel innings) {
    final lines = <LivePlayerLine>[];
    for (final id in [innings.strikerId, innings.nonStrikerId]) {
      if (id == null || id.isEmpty) continue;
      final b = ScoringDisplayUtils.batsman(innings, id);
      if (b == null) continue;
      lines.add(
        LivePlayerLine(
          playerId: b.playerId,
          name: b.playerName,
          isStriker: id == innings.strikerId,
          runs: b.runs,
          balls: b.balls,
          fours: b.fours,
          sixes: b.sixes,
          strikeRate: CricketMath.strikeRate(b.runs, b.balls),
        ),
      );
    }
    return lines;
  }

  List<LiveBowlerLine> _currentBowlers(InningsModel innings, int ballsPerOver) {
    LiveBowlerLine? lineFor(BowlerInningsModel b) {
      if (b.playerId.isEmpty) return null;
      final overs = CricketMath.formatOvers(b.oversBowledBalls, ballsPerOver);
      return LiveBowlerLine(
        playerId: b.playerId,
        name: b.playerName,
        overs: overs,
        maidens: 0,
        runs: b.runsConceded,
        wickets: b.wickets,
        economy: CricketMath.economyRate(
          b.runsConceded,
          b.oversBowledBalls,
          ballsPerOver,
        ),
      );
    }

    final lines = <LiveBowlerLine>[];
    final seen = <String>{};

    final currentId = innings.currentBowlerId;
    if (currentId != null && currentId.isNotEmpty) {
      final current = ScoringDisplayUtils.bowler(innings, currentId);
      final line = current != null ? lineFor(current) : null;
      if (line != null) {
        lines.add(line);
        seen.add(currentId);
      }
    }

    final others = [...innings.bowlers]
      ..sort((a, b) => b.oversBowledBalls.compareTo(a.oversBowledBalls));
    for (final b in others) {
      if (seen.contains(b.playerId)) continue;
      if (b.oversBowledBalls == 0 && b.wickets == 0) continue;
      final line = lineFor(b);
      if (line == null) continue;
      lines.add(line);
      if (lines.length >= 2) break;
    }

    return lines;
  }

  String? _chaseStatusLine({
    required MatchModel match,
    required InningsModel innings,
    required InningsChaseDisplay? chase,
    required int? dlsPar,
  }) {
    if (chase == null) return null;
    if (chase.runsNeeded <= 0 && chase.ballsRemaining <= 0) {
      return 'Target achieved';
    }
    if (chase.runsNeeded > 0 && chase.ballsRemaining > 0) {
      final base =
          'Need ${chase.runsNeeded} runs from ${chase.ballsRemaining} balls';
      if (match.targetState.dlsApplied && dlsPar != null) {
        return '$base\n(DLS Par Score: $dlsPar)';
      }
      return base;
    }
    if (innings.legalBalls == 0) return null;
    return 'CRR ${chase.currentRunRate.toStringAsFixed(2)}';
  }

  String? _insightBanner({
    required MatchModel match,
    required InningsModel innings,
    required String battingTeam,
    required InningsChaseDisplay? chase,
    required MatchTargetStateModel targetState,
  }) {
    if (match.status == MatchStatus.inningsBreak) {
      return 'Innings break — next innings starting soon.';
    }

    if (chase != null && chase.isChasing && chase.ballsRemaining > 0) {
      if (chase.runsNeeded > 0) {
        if (targetState.dlsApplied) {
          final defending = _defendingTeamName(match, innings);
          if (defending.isNotEmpty &&
              chase.runsNeeded > chase.ballsRemaining * 2) {
            return '$defending are ahead by DLS.';
          }
        }
        if (chase.requiredRunRate > chase.currentRunRate + 0.01) {
          return 'Required run rate exceeds current run rate.';
        }
        return '$battingTeam need ${chase.runsNeeded} runs from ${chase.ballsRemaining} balls.';
      }
    }

    if (innings.partnershipRuns >= 50) {
      return 'Partnership worth ${innings.partnershipRuns} runs.';
    }

    return null;
  }

  String _defendingTeamName(MatchModel match, InningsModel inn) {
    final defId = inn.bowlingTeamId;
    if (defId == match.teamAId) return match.teamAName;
    if (defId == match.teamBId) return match.teamBName;
    return '';
  }

  String? _powerplayLabel(MatchModel match, InningsModel inn) {
    final rules = match.rules;
    final overNum =
        ScoringDisplayUtils.currentOverNumber(inn, rules.ballsPerOver);
    if (overNum < 1) return null;

    if (rules.powerplaySlots.any((s) => s.isNotEmpty)) {
      for (var i = 0; i < rules.powerplaySlots.length; i++) {
        if (rules.powerplaySlots[i].contains(overNum)) {
          if (i < rules.powerplayLabels.length &&
              rules.powerplayLabels[i].isNotEmpty) {
            return rules.powerplayLabels[i];
          }
          return 'Powerplay ${i + 1}';
        }
      }
    }

    final kind = MatchPhaseService.classifyOver(overNum, rules);
    final ranges = MatchPhaseService.forRules(rules);
    return switch (kind) {
      OverPhaseKind.powerplay => ranges.powerplayLabel,
      OverPhaseKind.death => ranges.deathLabel,
      OverPhaseKind.middle => ranges.middleLabel,
      _ => null,
    };
  }

  LiveTargetRevisionInfo? _targetRevision(
    MatchModel match,
    List<MatchRevisionModel> revisions,
  ) {
    final state = match.targetState;
    MatchRevisionModel? latest;
    for (final rev in revisions) {
      final t = rev.type.toLowerCase();
      if (t == 'dls' || t == 'target' || t == 'penalty') {
        latest = rev;
      }
    }

    final original = state.originalTarget ?? latest?.oldTarget;
    final revised = state.effectiveRevisedTarget ?? latest?.newTarget;
    final reason = latest?.reason.isNotEmpty == true
        ? latest!.reason
        : state.liveBannerMessage;

    if (original == null &&
        revised == null &&
        reason == null &&
        latest?.penaltyRuns == null &&
        !state.dlsApplied) {
      return null;
    }

    return LiveTargetRevisionInfo(
      originalTarget: original,
      revisedTarget: revised,
      reason: reason,
      dlsApplied: state.dlsApplied,
      penaltyRuns: latest?.penaltyRuns,
    );
  }
}
