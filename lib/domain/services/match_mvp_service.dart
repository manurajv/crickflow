import 'package:flutter/foundation.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/cricket_math.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_player_snapshot.dart';
import '../../data/models/match_rules_model.dart';
import '../scoring/ball_event_aggregator.dart';
import 'match_mvp_models.dart';
import 'match_analytics_models.dart';
import 'match_phase_service.dart';

export 'match_mvp_models.dart' show MvpFormatContext;

/// Format-aware MVP scoring from ball events (read-only).
class MatchMvpService {
  MatchMvpService({BallEventAggregator? aggregator})
      : _aggregator = aggregator ?? BallEventAggregator();

  final BallEventAggregator _aggregator;

  MatchMvpSnapshot build({
    required MatchModel match,
    required List<BallEventModel> ballEvents,
  }) {
    if (ballEvents.isEmpty) {
      return MatchMvpSnapshot(
        isLive: match.status == MatchStatus.live,
      );
    }

    final rules = match.rules;
    final format = _formatContext(match, rules);
    final registry = _buildRegistry(match);
    final accum = <String, _PlayerAccum>{};

    void ensurePlayer(
      String playerId,
      String name,
      String teamId,
      String teamName,
    ) {
      if (playerId.isEmpty) return;
      final existing = accum[playerId];
      if (existing != null) {
        if (existing.playerName.isEmpty && name.isNotEmpty) {
          existing.playerName = name;
        }
        if (existing.teamId.isEmpty && teamId.isNotEmpty) {
          existing.teamId = teamId;
          existing.teamName = teamName;
        }
        return;
      }
      final meta = registry[playerId];
      accum[playerId] = _PlayerAccum(
        playerId: playerId,
        playerName: name.isNotEmpty ? name : (meta?.name ?? 'Player'),
        teamId: teamId.isNotEmpty ? teamId : (meta?.teamId ?? ''),
        teamName: teamName.isNotEmpty ? teamName : (meta?.teamName ?? ''),
        photoUrl: meta?.photoUrl,
      );
    }

    String teamNameFor(String? teamId) {
      if (teamId == null || teamId.isEmpty) return '';
      if (teamId == match.teamAId) return match.teamAName;
      if (teamId == match.teamBId) return match.teamBName;
      return '';
    }

    final winnerId = match.winnerTeamId;
    final losingId = _losingTeamId(match);

    for (final lineupInnings in match.innings) {
      final projection = _aggregator.projectInnings(
        match: match,
        lineupInnings: lineupInnings,
        allEvents: ballEvents,
      );
      final innings = projection.innings;
      final events = projection.events;
      if (events.isEmpty) continue;

      final battingTeamId = innings.battingTeamId;
      final bowlingTeamId = innings.bowlingTeamId;
      final battingTeamName = teamNameFor(battingTeamId);
      final bowlingTeamName = teamNameFor(bowlingTeamId);
      final isChaseInnings = innings.inningsNumber >= 2;
      final battingWon = winnerId != null && winnerId == battingTeamId;
      final bowlingWon = winnerId != null && winnerId == bowlingTeamId;

      final battingOrder = _battingOrderMap(projection.fallOfWickets);
      final maidens = projection.bowlerMaidens;

      for (final b in innings.batsmen) {
        if (b.playerId.isEmpty) continue;
        ensurePlayer(b.playerId, b.playerName, battingTeamId, battingTeamName);
        final p = accum[b.playerId]!;
        p.runs += b.runs;
        p.balls += b.balls;
        p.fours += b.fours;
        p.sixes += b.sixes;
      }

      for (final b in innings.bowlers) {
        if (b.playerId.isEmpty) continue;
        ensurePlayer(b.playerId, b.playerName, bowlingTeamId, bowlingTeamName);
        final p = accum[b.playerId]!;
        p.runsConceded += b.runsConceded;
        p.legalBallsBowled += b.oversBowledBalls;
        p.wickets += b.wickets;
        p.maidens += maidens[b.playerId] ?? 0;
      }

      _scanEventsForMvp(
        events: events,
        rules: rules,
        accum: accum,
        battingOrder: battingOrder,
        bowlingTeamId: bowlingTeamId,
        bowlingTeamName: bowlingTeamName,
        ensurePlayer: ensurePlayer,
        isChaseInnings: isChaseInnings,
        battingWon: battingWon,
        bowlingWon: bowlingWon,
        battingTeamId: battingTeamId,
        battingTeamName: battingTeamName,
      );

      for (final partnership in projection.partnerships) {
        final threshold = format.parRunsPerInnings * 0.22;
        if (partnership.runs < threshold) continue;
        final bonus =
            (partnership.runs / format.parRunsPerInnings).clamp(0.0, 1.2) *
                0.55;
        for (final id in [partnership.batterAId, partnership.batterBId]) {
          if (id.isEmpty) continue;
          ensurePlayer(
            id,
            '',
            battingTeamId,
            battingTeamName,
          );
          accum[id]!.partnershipBonus += bonus / 2;
        }
      }
    }

    final scored = accum.values
        .map((p) => _toScore(p, format))
        .where((s) => s.totalMvp > 0.001)
        .toList()
      ..sort((a, b) => b.totalMvp.compareTo(a.totalMvp));

    final ranked = <MvpPlayerScore>[];
    for (var i = 0; i < scored.length; i++) {
      ranked.add(scored[i].copyWith(rank: i + 1));
    }

    return _applyAwards(
      players: ranked,
      losingTeamId: losingId,
      winnerTeamId: winnerId,
      teamAId: match.teamAId,
      teamBId: match.teamBId,
      isLive: match.status == MatchStatus.live,
      format: format,
    );
  }

  /// Exposed for unit tests (POTM / Fighter rules).
  @visibleForTesting
  static MatchMvpSnapshot applyAwards({
    required List<MvpPlayerScore> players,
    required String? losingTeamId,
    required String? winnerTeamId,
    required String? teamAId,
    required String? teamBId,
    required MvpFormatContext format,
    bool isLive = false,
  }) {
    return MatchMvpService()._applyAwards(
      players: players,
      losingTeamId: losingTeamId,
      winnerTeamId: winnerTeamId,
      teamAId: teamAId,
      teamBId: teamBId,
      isLive: isLive,
      format: format,
    );
  }

  MatchMvpSnapshot _applyAwards({
    required List<MvpPlayerScore> players,
    required String? losingTeamId,
    required String? winnerTeamId,
    required String? teamAId,
    required String? teamBId,
    required bool isLive,
    required MvpFormatContext format,
  }) {
    if (players.isEmpty) {
      return MatchMvpSnapshot(
        hasData: false,
        isLive: isLive,
        formatContext: format,
        losingTeamId: losingTeamId,
        teamAId: teamAId,
        teamBId: teamBId,
      );
    }

    final potm = players.first;
    var result = players
        .map(
          (p) => p.copyWith(
            isPlayerOfTheMatch: p.playerId == potm.playerId,
          ),
        )
        .toList();

    String? fighterId;
    if (losingTeamId != null &&
        winnerTeamId != null &&
        potm.teamId != losingTeamId) {
      final losingSorted = result
          .where((p) => p.teamId == losingTeamId)
          .toList()
        ..sort((a, b) => b.totalMvp.compareTo(a.totalMvp));
      final eligibleIds =
          losingSorted.take(3).map((p) => p.playerId).toSet();
      for (final p in result) {
        if (eligibleIds.contains(p.playerId)) {
          fighterId = p.playerId;
          break;
        }
      }
    }

    if (fighterId != null) {
      result = result
          .map(
            (p) => p.copyWith(
              isFighterOfTheMatch: p.playerId == fighterId,
            ),
          )
          .toList();
    }

    return MatchMvpSnapshot(
      players: result,
      hasData: true,
      isLive: isLive,
      formatContext: format,
      losingTeamId: losingTeamId,
      teamAId: teamAId,
      teamBId: teamBId,
    );
  }

  MvpPlayerScore _toScore(_PlayerAccum p, MvpFormatContext ctx) {
    final batting = _battingMvp(p, ctx);
    final bowling = _bowlingMvp(p, ctx);
    final fielding = _fieldingMvp(p, ctx);
    final clutch = p.clutchBonus;
    final partnership = p.partnershipBonus;
    final total = batting + bowling + fielding + clutch + partnership;

    return MvpPlayerScore(
      playerId: p.playerId,
      playerName: p.playerName,
      teamId: p.teamId,
      teamName: p.teamName,
      photoUrl: p.photoUrl,
      rank: 0,
      battingMvp: batting,
      bowlingMvp: bowling,
      fieldingMvp: fielding,
      clutchBonus: clutch,
      partnershipBonus: partnership,
      totalMvp: total,
    );
  }

  double _battingMvp(_PlayerAccum p, MvpFormatContext ctx) {
    if (p.balls == 0 && p.runs == 0) return 0;

    final runsScore =
        (p.runs / ctx.parRunsPerInnings) * 4.2 * ctx.runsWeight;

    final sr = CricketMath.strikeRate(p.runs, p.balls);
    final srDelta = sr - ctx.parStrikeRate;
    final srBonus = srDelta > 0
        ? (srDelta / ctx.parStrikeRate) * ctx.strikeRateWeight * 1.75
        : 0.0;

    final boundaryBalls = p.fours + p.sixes;
    final boundaryPct = p.balls > 0 ? boundaryBalls / p.balls : 0.0;
    final boundaryBonus = boundaryPct * ctx.strikeRateWeight * 0.85;

    final deathBonus = p.deathBatRuns > 0
        ? (p.deathBatRuns / ctx.parRunsPerInnings) *
            ctx.strikeRateWeight *
            0.9
        : 0.0;

    return runsScore + srBonus + boundaryBonus + deathBonus;
  }

  double _bowlingMvp(_PlayerAccum p, MvpFormatContext ctx) {
    if (p.legalBallsBowled == 0 && p.wickets == 0) return 0;

    final oversBowled = p.legalBallsBowled / ctx.ballsPerOver;
    final economy = CricketMath.economyRate(
      p.runsConceded,
      p.legalBallsBowled,
      ctx.ballsPerOver,
    );
    final econDelta = ctx.parEconomy - economy;
    final econScore = econDelta > 0
        ? (econDelta / ctx.parEconomy) * ctx.economyWeight * oversBowled * 0.38
        : 0.0;

    final wicketScore = p.wicketValueSum * ctx.economyWeight * 1.05;

    final dotPct =
        p.legalBallsBowled > 0 ? p.dotBallsBowled / p.legalBallsBowled : 0.0;
    final dotScore = dotPct * oversBowled * 0.28;

    final maidenScore = p.maidens * 0.42 * ctx.economyWeight;
    final deathScore =
        p.deathWickets * 0.65 + p.deathDotBalls * 0.018;

    return wicketScore + econScore + dotScore + maidenScore + deathScore;
  }

  double _fieldingMvp(_PlayerAccum p, MvpFormatContext ctx) {
    if (p.catches == 0 &&
        p.runOuts == 0 &&
        p.directHitRunOuts == 0 &&
        p.stumpings == 0) {
      return 0;
    }

    final scale = ctx.isTestMatch ? 1.15 : 1.0;
    return scale *
        (p.catches * 0.78 +
            p.importantCatches * 0.42 +
            (p.runOuts - p.directHitRunOuts) * 0.55 +
            p.directHitRunOuts * 1.35 +
            p.stumpings * 0.88);
  }

  void _scanEventsForMvp({
    required List<BallEventModel> events,
    required MatchRulesModel rules,
    required Map<String, _PlayerAccum> accum,
    required Map<String, int> battingOrder,
    required String bowlingTeamId,
    required String bowlingTeamName,
    required void Function(String, String, String, String) ensurePlayer,
    required bool isChaseInnings,
    required bool battingWon,
    required bool bowlingWon,
    required String battingTeamId,
    required String battingTeamName,
  }) {
    var recentWicketBallIndex = -999;
    var wicketsInBurst = 0;

    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final phase = MatchPhaseService.classifyOver(e.overNumber, rules);
      final isDeath = phase == OverPhaseKind.death;

      if (e.bowlerId != null && e.bowlerId!.isNotEmpty && e.isLegalDelivery) {
        ensurePlayer(e.bowlerId!, '', bowlingTeamId, bowlingTeamName);
        final bowler = accum[e.bowlerId!]!;
        if (e.runs == 0 &&
            e.eventType != BallEventType.wide &&
            e.eventType != BallEventType.noBall) {
          bowler.dotBallsBowled++;
          if (isDeath) bowler.deathDotBalls++;
        }
      }

      if (e.strikerId != null &&
          e.strikerId!.isNotEmpty &&
          e.isLegalDelivery &&
          e.runs > 0) {
        ensurePlayer(e.strikerId!, '', battingTeamId, battingTeamName);
        final batter = accum[e.strikerId!]!;
        if (isDeath) batter.deathBatRuns += e.runs;
      }

      if (!_isWicketEvent(e)) continue;

      final dismissedId = e.dismissedPlayerId ?? e.strikerId ?? '';
      final order = battingOrder[dismissedId] ?? 8;
      final wicketVal = _wicketValue(order, rules.maxWickets);

      if (e.bowlerId != null && e.bowlerId!.isNotEmpty) {
        ensurePlayer(e.bowlerId!, '', bowlingTeamId, bowlingTeamName);
        final bowler = accum[e.bowlerId!]!;
        if (e.wicketType != WicketType.runOut ||
            e.wicketType == WicketType.caughtAndBowled) {
          bowler.wicketValueSum += wicketVal;
          if (isDeath) bowler.deathWickets++;
        }
      }

      _creditFieldingEvent(
        e: e,
        order: order,
        accum: accum,
        ensurePlayer: ensurePlayer,
        bowlingTeamId: bowlingTeamId,
        bowlingTeamName: bowlingTeamName,
      );

      if (i - recentWicketBallIndex <= 6) {
        wicketsInBurst++;
      } else {
        wicketsInBurst = 1;
      }
      recentWicketBallIndex = i;

      if (wicketsInBurst >= 2 && e.bowlerId != null) {
        ensurePlayer(e.bowlerId!, '', bowlingTeamId, bowlingTeamName);
        accum[e.bowlerId!]!.clutchBonus += 0.38;
      }

      if (isChaseInnings && battingWon && isDeath && e.strikerId != null) {
        ensurePlayer(e.strikerId!, '', battingTeamId, battingTeamName);
        accum[e.strikerId!]!.clutchBonus += 0.12;
      }
      if (!isChaseInnings && bowlingWon && isDeath && e.bowlerId != null) {
        ensurePlayer(e.bowlerId!, '', bowlingTeamId, bowlingTeamName);
        accum[e.bowlerId!]!.clutchBonus += 0.14;
      }
    }
  }

  void _creditFieldingEvent({
    required BallEventModel e,
    required int order,
    required Map<String, _PlayerAccum> accum,
    required void Function(String, String, String, String) ensurePlayer,
    required String bowlingTeamId,
    required String bowlingTeamName,
  }) {
    final type = e.wicketType;
    if (type == null) return;

    void credit(
      String id, {
      bool isCatch = false,
      bool runOut = false,
      bool direct = false,
      bool stumping = false,
    }) {
      if (id.isEmpty) return;
      ensurePlayer(id, '', bowlingTeamId, bowlingTeamName);
      final p = accum[id]!;
      if (isCatch) {
        p.catches++;
        if (order <= 3) p.importantCatches++;
      }
      if (runOut && !direct) p.runOuts++;
      if (direct) {
        p.runOuts++;
        p.directHitRunOuts++;
      }
      if (stumping) p.stumpings++;
    }

    switch (type) {
      case WicketType.caught:
      case WicketType.caughtBehind:
        credit(
          e.primaryFielderId ?? e.fielderId ?? e.wicketKeeperId ?? '',
          isCatch: true,
        );
      case WicketType.caughtAndBowled:
        break;
      case WicketType.runOut:
        final directId = e.primaryFielderId ?? e.fielderId;
        final assistIds = e.fielders
            .map((f) => f.playerId)
            .where((id) => id.isNotEmpty)
            .toList();
        if (directId != null && directId.isNotEmpty) {
          final isDirect = assistIds.isEmpty ||
              assistIds.length == 1 && assistIds.first == directId;
          credit(directId, runOut: !isDirect, direct: isDirect);
        }
        for (final assist in assistIds) {
          if (assist == directId) continue;
          credit(assist, runOut: true);
        }
      case WicketType.stumped:
        credit(e.wicketKeeperId ?? e.primaryFielderId ?? '', stumping: true);
      default:
        break;
    }
  }

  static bool _isWicketEvent(BallEventModel e) {
    if (e.retiredHurt) return false;
    if (e.isWicket) return true;
    if (e.eventType != BallEventType.wicket) return false;
    return !(e.isFreeHit && e.wicketType != WicketType.runOut);
  }

  static double _wicketValue(int battingOrder, int maxWickets) {
    final order = battingOrder.clamp(1, maxWickets.clamp(1, 10));
    final weight = 1.0 - (order - 1) * 0.075;
    return (weight.clamp(0.35, 1.0)) * 1.25;
  }

  static Map<String, int> _battingOrderMap(List<FallOfWicketRecord> fow) {
    final map = <String, int>{};
    for (final f in fow) {
      if (f.batsmanId.isNotEmpty) {
        map[f.batsmanId] = f.wicketNumber;
      }
    }
    return map;
  }

  static String? _losingTeamId(MatchModel match) {
    final winner = match.winnerTeamId;
    if (winner == null || winner.isEmpty) return null;
    if (winner == match.teamAId) return match.teamBId;
    if (winner == match.teamBId) return match.teamAId;
    return null;
  }

  MvpFormatContext _formatContext(MatchModel match, MatchRulesModel rules) {
    final totalOvers = rules.isTestMatch ? 90 : rules.totalOvers.clamp(1, 999);
    final ballsPerOver = rules.ballsPerOver.clamp(1, 12);
    final totalLegalBalls = totalOvers * ballsPerOver;
    final parRuns = _parRunsPerInnings(match, rules, totalOvers);

    return MvpFormatContext(
      totalOvers: totalOvers,
      ballsPerOver: ballsPerOver,
      totalLegalBalls: totalLegalBalls,
      isTestMatch: rules.isTestMatch,
      parRunsPerInnings: parRuns,
      parStrikeRate: _parStrikeRate(totalOvers, rules.isTestMatch),
      parEconomy: _parEconomy(totalOvers, rules.isTestMatch),
      strikeRateWeight: _strikeRateWeight(totalOvers, rules.isTestMatch),
      economyWeight: _economyWeight(totalOvers, rules.isTestMatch),
      runsWeight: _runsWeight(totalOvers, rules.isTestMatch),
    );
  }

  static double _parRunsPerInnings(
    MatchModel match,
    MatchRulesModel rules,
    int totalOvers,
  ) {
    final inningsTotals = match.innings
        .where((i) => i.totalRuns > 0)
        .map((i) => i.totalRuns.toDouble())
        .toList();
    final formatPar = _formatExpectedRuns(totalOvers, rules.isTestMatch);

    if (inningsTotals.isEmpty) return formatPar;

    final matchAvg =
        inningsTotals.reduce((a, b) => a + b) / inningsTotals.length;
    final matchPeak = inningsTotals.reduce((a, b) => a > b ? a : b);
    return (formatPar * 0.35 + matchAvg * 0.35 + matchPeak * 0.3)
        .clamp(8.0, 800.0);
  }

  static double _formatExpectedRuns(int totalOvers, bool isTest) {
    if (isTest) return 280.0;
    return totalOvers * _parRunRate(totalOvers);
  }

  static double _parRunRate(int totalOvers) {
    if (totalOvers <= 4) return 10.0;
    if (totalOvers <= 5) return 9.5;
    if (totalOvers <= 6) return 9.2;
    if (totalOvers <= 8) return 9.0;
    if (totalOvers <= 10) return 8.5;
    if (totalOvers <= 15) return 7.5;
    if (totalOvers <= 20) return 7.0;
    if (totalOvers <= 30) return 6.0;
    if (totalOvers <= 40) return 5.5;
    return 5.0;
  }

  static double _parStrikeRate(int totalOvers, bool isTest) {
    if (isTest) return 52.0;
    if (totalOvers <= 8) return 145.0;
    if (totalOvers <= 10) return 135.0;
    if (totalOvers <= 15) return 120.0;
    if (totalOvers <= 20) return 115.0;
    if (totalOvers <= 30) return 95.0;
    return 82.0;
  }

  static double _parEconomy(int totalOvers, bool isTest) {
    if (isTest) return 3.2;
    if (totalOvers <= 8) return 8.0;
    if (totalOvers <= 10) return 7.8;
    if (totalOvers <= 15) return 7.2;
    if (totalOvers <= 20) return 7.0;
    if (totalOvers <= 30) return 6.2;
    return 5.5;
  }

  static double _strikeRateWeight(int totalOvers, bool isTest) {
    if (isTest) return 0.12;
    if (totalOvers <= 8) return 1.05;
    if (totalOvers <= 10) return 1.0;
    if (totalOvers <= 15) return 0.82;
    if (totalOvers <= 20) return 0.72;
    if (totalOvers <= 30) return 0.55;
    return 0.42;
  }

  static double _economyWeight(int totalOvers, bool isTest) {
    if (isTest) return 0.55;
    if (totalOvers <= 8) return 1.05;
    if (totalOvers <= 10) return 1.0;
    if (totalOvers <= 20) return 0.85;
    if (totalOvers <= 30) return 0.72;
    return 0.62;
  }

  static double _runsWeight(int totalOvers, bool isTest) {
    if (isTest) return 1.15;
    if (totalOvers <= 8) return 0.88;
    if (totalOvers <= 20) return 1.0;
    return 1.08;
  }

  Map<String, _PlayerMeta> _buildRegistry(MatchModel match) {
    final map = <String, _PlayerMeta>{};
    final setup = match.setup;
    if (setup == null) return map;

    void addList(List<MatchPlayerSnapshot> list, String teamId, String teamName) {
      for (final p in list) {
        map[p.id] = _PlayerMeta(
          name: p.name,
          teamId: teamId,
          teamName: teamName,
          photoUrl: p.photoUrl,
        );
      }
    }

    final teamAId = match.teamAId ?? '';
    final teamBId = match.teamBId ?? '';
    addList(setup.teamAPlayingPlayers, teamAId, match.teamAName);
    addList(setup.teamASubstitutePlayers, teamAId, match.teamAName);
    addList(setup.teamBPlayingPlayers, teamBId, match.teamBName);
    addList(setup.teamBSubstitutePlayers, teamBId, match.teamBName);
    return map;
  }
}

class _PlayerMeta {
  const _PlayerMeta({
    required this.name,
    required this.teamId,
    required this.teamName,
    this.photoUrl,
  });

  final String name;
  final String teamId;
  final String teamName;
  final String? photoUrl;
}

class _PlayerAccum {
  _PlayerAccum({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    this.photoUrl,
  });

  final String playerId;
  String playerName;
  String teamId;
  String teamName;
  final String? photoUrl;

  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  int deathBatRuns = 0;

  int wickets = 0;
  int runsConceded = 0;
  int legalBallsBowled = 0;
  int dotBallsBowled = 0;
  int maidens = 0;
  double wicketValueSum = 0;
  int deathWickets = 0;
  int deathDotBalls = 0;

  int catches = 0;
  int importantCatches = 0;
  int runOuts = 0;
  int directHitRunOuts = 0;
  int stumpings = 0;

  double clutchBonus = 0;
  double partnershipBonus = 0;
}
