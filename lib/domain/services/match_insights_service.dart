import '../../core/constants/enums.dart';
import '../../core/utils/cricket_math.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import 'badge_service.dart';
import 'fantasy_points_service.dart';

class PerformerInsight {
  const PerformerInsight({
    required this.playerId,
    required this.playerName,
    required this.teamName,
    required this.statLine,
    required this.impactScore,
    this.isBatter = true,
  });

  final String playerId;
  final String playerName;
  final String teamName;
  final String statLine;
  final double impactScore;
  final bool isBatter;
}

class MatchInsightsSnapshot {
  const MatchInsightsSnapshot({
    this.hero,
    this.topBatters = const [],
    this.topBowlers = const [],
    this.milestones = const [],
    this.mvpRankings = const [],
    this.resultLine,
    this.isLive = false,
  });

  final MatchHeroModel? hero;
  final List<PerformerInsight> topBatters;
  final List<PerformerInsight> topBowlers;
  final List<String> milestones;
  final List<PerformerInsight> mvpRankings;
  final String? resultLine;
  final bool isLive;
}

/// Client-side match insights from innings + ball events (no ML).
class MatchInsightsService {
  MatchInsightsService({
    BadgeService? badges,
    FantasyPointsService? fantasy,
  })  : _badges = badges ?? BadgeService(),
        _fantasy = fantasy ?? const FantasyPointsService();

  final BadgeService _badges;
  final FantasyPointsService _fantasy;

  MatchInsightsSnapshot build({
    required MatchModel match,
    List<BallEventModel> ballEvents = const [],
  }) {
    final hero = match.matchHero ?? _badges.pickMatchHero(match);
    final batters = _aggregateBatters(match);
    final bowlers = _aggregateBowlers(match);
    final milestones = _milestonesFromMatch(match);
    final mvp = _mvpFromEvents(match, ballEvents);

    return MatchInsightsSnapshot(
      hero: hero,
      topBatters: batters.take(5).toList(),
      topBowlers: bowlers.take(5).toList(),
      milestones: milestones,
      mvpRankings: mvp.take(8).toList(),
      resultLine: match.resultSummary.isNotEmpty
          ? match.resultSummary
          : _liveLine(match),
      isLive: match.status == MatchStatus.live ||
          match.status == MatchStatus.inningsBreak,
    );
  }

  String? _liveLine(MatchModel match) {
    final inn = match.currentInnings;
    if (inn == null) return null;
    final rr = CricketMath.runRate(
      inn.totalRuns,
      inn.legalBalls,
      match.rules.ballsPerOver,
    );
    return '${match.teamAName} vs ${match.teamBName} · RR ${rr.toStringAsFixed(2)}';
  }

  List<PerformerInsight> _aggregateBatters(MatchModel match) {
    final map = <String, ({String name, int runs, int balls, int fours, int sixes, String team})>{};

    for (final inn in match.innings) {
      final team = _teamName(match, inn.battingTeamId);
      for (final b in inn.batsmen) {
        if (b.playerId.isEmpty) continue;
        final cur = map[b.playerId];
        map[b.playerId] = (
          name: b.playerName.isNotEmpty ? b.playerName : b.playerId,
          runs: (cur?.runs ?? 0) + b.runs,
          balls: (cur?.balls ?? 0) + b.balls,
          fours: (cur?.fours ?? 0) + b.fours,
          sixes: (cur?.sixes ?? 0) + b.sixes,
          team: team,
        );
      }
    }

    final list = map.entries.map((e) {
      final sr = CricketMath.strikeRate(e.value.runs, e.value.balls);
      return PerformerInsight(
        playerId: e.key,
        playerName: e.value.name,
        teamName: e.value.team,
        statLine:
            '${e.value.runs}(${e.value.balls}) · ${e.value.fours}×4 ${e.value.sixes}×6 · SR ${sr.toStringAsFixed(0)}',
        impactScore: e.value.runs + e.value.fours + e.value.sixes * 2.0,
        isBatter: true,
      );
    }).toList();

    list.sort((a, b) => b.impactScore.compareTo(a.impactScore));
    return list;
  }

  List<PerformerInsight> _aggregateBowlers(MatchModel match) {
    final map = <String, ({String name, int wkts, int runs, int balls, String team})>{};

    for (final inn in match.innings) {
      final team = _teamName(match, inn.bowlingTeamId);
      for (final b in inn.bowlers) {
        if (b.playerId.isEmpty) continue;
        final cur = map[b.playerId];
        map[b.playerId] = (
          name: b.playerName.isNotEmpty ? b.playerName : b.playerId,
          wkts: (cur?.wkts ?? 0) + b.wickets,
          runs: (cur?.runs ?? 0) + b.runsConceded,
          balls: (cur?.balls ?? 0) + b.oversBowledBalls,
          team: team,
        );
      }
    }

    final list = map.entries.map((e) {
      final overs = CricketMath.formatOvers(
        e.value.balls,
        match.rules.ballsPerOver,
      );
      return PerformerInsight(
        playerId: e.key,
        playerName: e.value.name,
        teamName: e.value.team,
        statLine: '$overs-${e.value.runs}-${e.value.wkts}',
        impactScore: e.value.wkts * 25 + (e.value.wkts > 0 ? 10 : 0),
        isBatter: false,
      );
    }).toList();

    list.sort((a, b) => b.impactScore.compareTo(a.impactScore));
    return list;
  }

  List<String> _milestonesFromMatch(MatchModel match) {
    final lines = <String>[];
    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.runs >= 50) {
          lines.add('${b.playerName} — ${b.runs} runs');
        }
        if (b.sixes >= 3) {
          lines.add('${b.playerName} — ${b.sixes} sixes');
        }
      }
      for (final bw in inn.bowlers) {
        if (bw.wickets >= 3) {
          lines.add('${bw.playerName} — ${bw.wickets} wickets');
        }
      }
    }
    return lines;
  }

  List<PerformerInsight> _mvpFromEvents(
    MatchModel match,
    List<BallEventModel> events,
  ) {
    if (events.isEmpty) return [];

    final raw = _fantasy.rawPlayerPoints(events);
    final names = <String, String>{};
    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        names[b.playerId] = b.playerName;
      }
      for (final b in inn.bowlers) {
        names[b.playerId] = b.playerName;
      }
    }

    final list = raw.entries.map((e) {
      return PerformerInsight(
        playerId: e.key,
        playerName: names[e.key] ?? e.key,
        teamName: '',
        statLine: '${e.value.toStringAsFixed(1)} pts',
        impactScore: e.value,
        isBatter: true,
      );
    }).toList();

    list.sort((a, b) => b.impactScore.compareTo(a.impactScore));
    return list;
  }

  String _teamName(MatchModel match, String? teamId) {
    if (teamId == match.teamAId) return match.teamAName;
    if (teamId == match.teamBId) return match.teamBName;
    return '';
  }
}
