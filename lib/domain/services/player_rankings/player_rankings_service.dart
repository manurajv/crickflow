import '../../../core/constants/enums.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../core/utils/location_text_filter.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/player_model.dart';
import 'player_rankings_models.dart';

/// Ranks players from [PlayerStatsModel] + [CricketMath].
///
/// Career path uses stored player docs. Year/overs filters use match innings
/// aggregates (same batting/bowling/fielding counters — no team/tournament
/// engine changes). Categories that need ball-event replay stay empty.
class PlayerRankingsService {
  const PlayerRankingsService();

  List<PlayerRankingEntry> rank({
    required List<PlayerModel> players,
    required PlayerRankingsFilter filter,
    required Map<String, String> teamNamesById,
    Map<String, PlayerStatsModel>? statsByPlayerId,
    Map<String, int>? bowlingInningsByPlayerId,
  }) {
    if (filter.category.requiresMatchReplay) return const [];

    final scored = <_ScoredPlayer>[];
    for (final player in players) {
      // Walk-in / match-only guest players have no linked account.
      if (!_isRegisteredPlayer(player)) continue;
      if (!_matchesLocation(player, filter)) continue;

      final stats = statsByPlayerId != null
          ? (statsByPlayerId[player.id] ?? const PlayerStatsModel())
          : _statsFor(player, filter.ballType);
      final metric = _metricFor(stats, filter.category);
      if (metric == null || !metric.include) continue;

      scored.add(
        _ScoredPlayer(
          player: player,
          stats: stats,
          bowlingInnings: bowlingInningsByPlayerId?[player.id] ??
              ((stats.oversBowledBalls > 0 || stats.wickets > 0)
                  ? stats.matchesPlayed
                  : 0),
          value: metric.value,
          valueLabel: metric.label,
          ascendingBetter: metric.ascendingBetter,
        ),
      );
    }

    scored.sort((a, b) {
      final cmp = a.ascendingBetter
          ? a.value.compareTo(b.value)
          : b.value.compareTo(a.value);
      if (cmp != 0) return cmp;
      return a.player.name.toLowerCase().compareTo(b.player.name.toLowerCase());
    });

    if (scored.isEmpty) return const [];

    return [
      for (var i = 0; i < scored.length; i++)
        _toEntry(
          ranked: scored[i],
          rank: i + 1,
          section: filter.section,
          teamNamesById: teamNamesById,
        ),
    ];
  }

  /// Aggregates batting / bowling / fielding from completed match innings.
  ///
  /// Ball filtering is rankings-specific via [filter]:
  /// - Leather / Tennis: same as cricket profile (`resolvedBallType`).
  /// - Indoor: indoor match type, optional leather/tennis material.
  Map<String, PlayerStatsModel> aggregateFromMatches({
    required List<MatchModel> matches,
    required PlayerRankingsFilter filter,
    Map<String, int>? bowlingInningsOut,
  }) {
    final byId = <String, _MatchAgg>{};

    _MatchAgg ensure(String id) =>
        byId.putIfAbsent(id, _MatchAgg.new);

    for (final match in matches) {
      if (!_matchesRankingsBallFilter(match, filter)) continue;
      if (!_matchesOversFilter(match, filter.overs)) continue;
      if (filter.year != null) {
        final date = match.completedAt ??
            match.startedAt ??
            match.scheduledAt ??
            match.createdAt;
        if (date == null || date.year != filter.year) continue;
      }

      final played = <String>{};

      for (final inn in match.innings) {
        for (final b in inn.batsmen) {
          if (b.playerId.isEmpty) continue;
          played.add(b.playerId);
          final agg = ensure(b.playerId);
          agg.inningsPlayed += 1;
          agg.runs += b.runs;
          agg.ballsFaced += b.balls;
          agg.fours += b.fours;
          agg.sixes += b.sixes;
          if (b.isOut) {
            agg.dismissals += 1;
            if (b.runs == 0) agg.ducks += 1;
          }
          if (b.runs >= 100) {
            agg.hundreds += 1;
          } else if (b.runs >= 50) {
            agg.fifties += 1;
          } else if (b.runs >= 30) {
            agg.thirties += 1;
          }
          if (b.runs > agg.highScore) agg.highScore = b.runs;
        }

        for (final bowler in inn.bowlers) {
          if (bowler.playerId.isEmpty) continue;
          played.add(bowler.playerId);
          final agg = ensure(bowler.playerId);
          agg.bowlingInnings += 1;
          agg.wickets += bowler.wickets;
          agg.oversBowledBalls += bowler.oversBowledBalls;
          agg.runsConceded += bowler.runsConceded;
          if (bowler.wickets >= 5) {
            agg.fiveWickets += 1;
          } else if (bowler.wickets >= 3) {
            agg.threeWickets += 1;
          }
        }

        for (final f in inn.fielders) {
          if (f.playerId.isEmpty) continue;
          if (f.catches == 0 && f.runOuts == 0 && f.stumpings == 0) continue;
          played.add(f.playerId);
          final agg = ensure(f.playerId);
          agg.catches += f.catches;
          agg.runOuts += f.runOuts;
          agg.stumpings += f.stumpings;
        }
      }

      for (final id in played) {
        ensure(id).matchesPlayed += 1;
      }
    }

    if (bowlingInningsOut != null) {
      bowlingInningsOut
        ..clear()
        ..addAll({
          for (final e in byId.entries) e.key: e.value.bowlingInnings,
        });
    }

    return {
      for (final e in byId.entries) e.key: e.value.toStats(),
    };
  }

  /// Rankings-only ball matching. Does not change cricket profile filters.
  bool _matchesRankingsBallFilter(
    MatchModel match,
    PlayerRankingsFilter filter,
  ) {
    if (filter.ballType == CricketBallType.indoor) {
      final isIndoorMatch =
          match.rules.cricketMatchType == CricketMatchType.indoor ||
              match.rules.ballType == CricketBallType.indoor;
      if (!isIndoorMatch) return false;
      final material = filter.indoorBallMaterial;
      if (material == null) return true;
      return _rankingsBallType(match) == material;
    }

    // Leather / Tennis — resolve like Cloud Functions stats buckets.
    return _rankingsBallType(match) == filter.ballType;
  }

  /// Mirrors `resolveBallType` in functions/src/utils/stats.js so rankings
  /// align with how player typed stats are written.
  CricketBallType _rankingsBallType(MatchModel match) {
    final rules = match.rules;
    final explicit = rules.ballType;
    if (explicit != null) {
      // Legacy "indoor" ball enum was used for tennis-style indoor games.
      if (explicit == CricketBallType.indoor) return CricketBallType.tennis;
      return explicit;
    }
    if (rules.format == MatchFormat.tennis) return CricketBallType.tennis;
    if (rules.format == MatchFormat.custom) return CricketBallType.tennis;
    return CricketBallType.leather;
  }

  bool _matchesOversFilter(MatchModel match, PlayerRankingsOversFilter overs) {
    if (overs == PlayerRankingsOversFilter.all) return true;

    final type = match.rules.cricketMatchType;
    if (overs == PlayerRankingsOversFilter.testMatch) {
      return type == CricketMatchType.testMatch;
    }
    if (type == CricketMatchType.testMatch) return false;

    final total = _effectiveTotalOvers(match);
    if (total <= 0) return false;

    return switch (overs) {
      PlayerRankingsOversFilter.overs1to12 => total >= 1 && total <= 12,
      PlayerRankingsOversFilter.overs13to20 => total >= 13 && total <= 20,
      PlayerRankingsOversFilter.overs21to99 => total >= 21 && total <= 99,
      PlayerRankingsOversFilter.all ||
      PlayerRankingsOversFilter.testMatch =>
        false,
    };
  }

  /// Prefer explicit [MatchRulesModel.totalOvers]; fall back by match type.
  /// Indoor tennis / box matches default to a short overs count when type is set.
  int _effectiveTotalOvers(MatchModel match) {
    final type = match.rules.cricketMatchType;
    final total = match.rules.totalOvers;

    if (type == CricketMatchType.testMatch) return 0;

    // Indoor formats: trust stored overs when set; otherwise use indoor default.
    if (type == CricketMatchType.indoor) {
      return total > 0 ? total : 6;
    }

    if (total > 0) return total;

    // Legacy docs may omit totalOvers — infer from ball / format hints.
    final ball = match.rules.resolvedBallType;
    if (ball == CricketBallType.indoor) return 6;

    return 20;
  }

  PlayerStatsModel _statsFor(PlayerModel player, CricketBallType ballType) {
    // Career path is unused for rankings (match aggregates only). Kept for
    // typed-bucket access if a caller passes statsByPlayerId: null.
    if (ballType == CricketBallType.indoor) {
      return const PlayerStatsModel();
    }
    return player.statsForBallType(ballType);
  }

  /// Registered CrickFlow accounts only — excludes walk-ins and match guests.
  static bool _isRegisteredPlayer(PlayerModel player) {
    final userId = player.userId?.trim() ?? '';
    return userId.isNotEmpty;
  }

  bool _matchesLocation(PlayerModel player, PlayerRankingsFilter filter) {
    if (!filter.hasLocationFilter) return true;
    return locationMatchesTextFilter(player.location, filter.location);
  }

  _Metric? _metricFor(PlayerStatsModel s, PlayerRankingsCategory category) {
    switch (category) {
      case PlayerRankingsCategory.mostRuns:
        return _Metric(
          value: s.runs,
          label: '${s.runs}',
          include: s.runs > 0,
        );
      case PlayerRankingsCategory.highestScore:
        return _Metric(
          value: s.highScore,
          label: '${s.highScore}',
          include: s.highScore > 0,
        );
      case PlayerRankingsCategory.bestAverage:
        final avg = CricketMath.battingAverage(s.runs, s.dismissals);
        return _Metric(
          value: avg,
          label: avg.toStringAsFixed(1),
          include: s.ballsFaced >= 1 && s.runs > 0,
        );
      case PlayerRankingsCategory.strikeRate:
        final sr = CricketMath.strikeRate(s.runs, s.ballsFaced);
        return _Metric(
          value: sr,
          label: sr.toStringAsFixed(1),
          include: s.ballsFaced >= 10,
        );
      case PlayerRankingsCategory.mostFifties:
        return _Metric(
          value: s.fifties,
          label: '${s.fifties}',
          include: s.fifties > 0,
        );
      case PlayerRankingsCategory.mostHundreds:
        return _Metric(
          value: s.hundreds,
          label: '${s.hundreds}',
          include: s.hundreds > 0,
        );
      case PlayerRankingsCategory.mostSixes:
        return _Metric(
          value: s.sixes,
          label: '${s.sixes}',
          include: s.sixes > 0,
        );
      case PlayerRankingsCategory.mostFours:
        return _Metric(
          value: s.fours,
          label: '${s.fours}',
          include: s.fours > 0,
        );
      case PlayerRankingsCategory.mostWickets:
        return _Metric(
          value: s.wickets,
          label: '${s.wickets}',
          include: s.wickets > 0,
        );
      case PlayerRankingsCategory.economy:
        final eco =
            CricketMath.economyRate(s.runsConceded, s.oversBowledBalls, 6);
        return _Metric(
          value: eco,
          label: eco.toStringAsFixed(2),
          include: s.oversBowledBalls >= 12,
          ascendingBetter: true,
        );
      case PlayerRankingsCategory.bowlingStrikeRate:
        final bsr = s.wickets == 0
            ? double.infinity
            : s.oversBowledBalls / s.wickets;
        return _Metric(
          value: bsr.isFinite ? bsr : 9999,
          label: bsr.isFinite ? bsr.toStringAsFixed(1) : '—',
          include: s.wickets >= 2,
          ascendingBetter: true,
        );
      case PlayerRankingsCategory.fiveWicketHauls:
        return _Metric(
          value: s.fiveWickets,
          label: '${s.fiveWickets}',
          include: s.fiveWickets > 0,
        );
      case PlayerRankingsCategory.mostCatches:
        return _Metric(
          value: s.catches,
          label: '${s.catches}',
          include: s.catches > 0,
        );
      case PlayerRankingsCategory.mostRunOuts:
      case PlayerRankingsCategory.mostDirectHits:
        return _Metric(
          value: s.runOuts,
          label: '${s.runOuts}',
          include: s.runOuts > 0,
        );
      case PlayerRankingsCategory.mostStumpings:
        return _Metric(
          value: s.stumpings,
          label: '${s.stumpings}',
          include: s.stumpings > 0,
        );
      case PlayerRankingsCategory.fastestFifty:
      case PlayerRankingsCategory.fastestHundred:
      case PlayerRankingsCategory.bestBowlingFigures:
      case PlayerRankingsCategory.maidens:
      case PlayerRankingsCategory.dotBalls:
        return null;
    }
  }

  PlayerRankingEntry _toEntry({
    required _ScoredPlayer ranked,
    required int rank,
    required PlayerRankingsSection section,
    required Map<String, String> teamNamesById,
  }) {
    final player = ranked.player;
    final teamId =
        player.effectiveTeamIds.isNotEmpty ? player.effectiveTeamIds.first : null;
    final teamName = teamId != null ? (teamNamesById[teamId] ?? '') : '';

    return PlayerRankingEntry(
      rank: rank,
      playerDocId: player.id,
      publicPlayerId: player.playerId,
      playerName:
          player.name.isNotEmpty ? player.name : player.effectiveFullName,
      photoUrl: player.photoUrl,
      role: player.role,
      teamName: teamName,
      teamId: teamId,
      verified: player.badgeIds.isNotEmpty,
      value: ranked.value,
      valueLabel: ranked.valueLabel,
      section: section,
      detailStats: _detailStats(
        section: section,
        stats: ranked.stats,
        bowlingInnings: ranked.bowlingInnings,
      ),
    );
  }

  List<PlayerRankingStat> _detailStats({
    required PlayerRankingsSection section,
    required PlayerStatsModel stats,
    required int bowlingInnings,
  }) {
    final avg = CricketMath.battingAverage(stats.runs, stats.dismissals);
    final batSr = CricketMath.strikeRate(stats.runs, stats.ballsFaced);
    final eco =
        CricketMath.economyRate(stats.runsConceded, stats.oversBowledBalls, 6);
    final bowlSr = stats.wickets == 0
        ? null
        : stats.oversBowledBalls / stats.wickets;
    final fieldDismissals = stats.catches + stats.stumpings + stats.runOuts;

    return switch (section) {
      PlayerRankingsSection.batting => [
          PlayerRankingStat(label: 'Inn', value: '${stats.inningsPlayed}'),
          PlayerRankingStat(label: 'R', value: '${stats.runs}'),
          PlayerRankingStat(label: 'Avg', value: avg.toStringAsFixed(1)),
          PlayerRankingStat(label: 'SR', value: batSr.toStringAsFixed(1)),
        ],
      PlayerRankingsSection.bowling => [
          PlayerRankingStat(label: 'Inn', value: '$bowlingInnings'),
          PlayerRankingStat(label: 'W', value: '${stats.wickets}'),
          PlayerRankingStat(label: 'Eco', value: eco.toStringAsFixed(2)),
          PlayerRankingStat(
            label: 'SR',
            value: bowlSr == null ? '—' : bowlSr.toStringAsFixed(1),
          ),
        ],
      PlayerRankingsSection.fielding => [
          PlayerRankingStat(label: 'Mat', value: '${stats.matchesPlayed}'),
          PlayerRankingStat(label: 'Dis', value: '$fieldDismissals'),
          PlayerRankingStat(label: 'Ct', value: '${stats.catches}'),
          PlayerRankingStat(label: 'St', value: '${stats.stumpings}'),
          PlayerRankingStat(label: 'RO', value: '${stats.runOuts}'),
        ],
    };
  }
}

class _Metric {
  const _Metric({
    required this.value,
    required this.label,
    required this.include,
    this.ascendingBetter = false,
  });

  final num value;
  final String label;
  final bool include;
  final bool ascendingBetter;
}

class _ScoredPlayer {
  const _ScoredPlayer({
    required this.player,
    required this.stats,
    required this.bowlingInnings,
    required this.value,
    required this.valueLabel,
    required this.ascendingBetter,
  });

  final PlayerModel player;
  final PlayerStatsModel stats;
  final int bowlingInnings;
  final num value;
  final String valueLabel;
  final bool ascendingBetter;
}

class _MatchAgg {
  int runs = 0;
  int ballsFaced = 0;
  int fours = 0;
  int sixes = 0;
  int wickets = 0;
  int oversBowledBalls = 0;
  int runsConceded = 0;
  int matchesPlayed = 0;
  int inningsPlayed = 0;
  int bowlingInnings = 0;
  int dismissals = 0;
  int highScore = 0;
  int thirties = 0;
  int fifties = 0;
  int hundreds = 0;
  int ducks = 0;
  int threeWickets = 0;
  int fiveWickets = 0;
  int catches = 0;
  int runOuts = 0;
  int stumpings = 0;

  PlayerStatsModel toStats() => PlayerStatsModel(
        runs: runs,
        ballsFaced: ballsFaced,
        fours: fours,
        sixes: sixes,
        wickets: wickets,
        oversBowledBalls: oversBowledBalls,
        runsConceded: runsConceded,
        matchesPlayed: matchesPlayed,
        inningsPlayed: inningsPlayed,
        dismissals: dismissals,
        highScore: highScore,
        thirties: thirties,
        fifties: fifties,
        hundreds: hundreds,
        ducks: ducks,
        threeWickets: threeWickets,
        fiveWickets: fiveWickets,
        catches: catches,
        runOuts: runOuts,
        stumpings: stumpings,
      );
}
