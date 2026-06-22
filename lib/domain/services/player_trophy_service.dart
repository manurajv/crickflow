import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import 'match_mvp_service.dart';
import 'match_mvp_models.dart';
import 'player_cricket_profile_models.dart';

class PlayerTrophyService {
  PlayerTrophyService({MatchMvpService? mvpService})
      : mvpService = mvpService ?? MatchMvpService();

  final MatchMvpService mvpService;

  List<PlayerTrophy> compute({
    required String playerId,
    required List<MatchModel> completedMatches,
    Map<String, List<BallEventModel>> ballEventsByMatch = const {},
  }) {
    final trophies = <PlayerTrophy>[];

    for (final match in completedMatches) {
      final events = ballEventsByMatch[match.id] ?? const [];
      final mvp = mvpService.build(match: match, ballEvents: events);
      if (mvp.hasData) {
        _addMvpTrophies(
          trophies: trophies,
          playerId: playerId,
          match: match,
          mvp: mvp,
        );
      } else {
        _addScorecardTrophies(
          trophies: trophies,
          playerId: playerId,
          match: match,
        );
      }
    }

    trophies.sort((a, b) => b.date.compareTo(a.date));
    return trophies;
  }

  void _addMvpTrophies({
    required List<PlayerTrophy> trophies,
    required String playerId,
    required MatchModel match,
    required MatchMvpSnapshot mvp,
  }) {
    void add(PlayerTrophyKind kind, MvpPlayerScore? player) {
      if (player == null || player.playerId != playerId) return;
      trophies.add(
        _trophy(
          playerId: playerId,
          match: match,
          kind: kind,
          performance: _performanceForKind(match, playerId, kind, player),
        ),
      );
    }

    add(PlayerTrophyKind.playerOfMatch, mvp.playerOfTheMatch);
    add(PlayerTrophyKind.fighterOfMatch, mvp.fighterOfTheMatch);

    final bestBatter = mvp.players.where((p) => p.battingMvp > 0).toList()
      ..sort((a, b) => b.battingMvp.compareTo(a.battingMvp));
    if (bestBatter.isNotEmpty) {
      add(PlayerTrophyKind.bestBatter, bestBatter.first);
    }

    final bestBowler = mvp.players.where((p) => p.bowlingMvp > 0).toList()
      ..sort((a, b) => b.bowlingMvp.compareTo(a.bowlingMvp));
    if (bestBowler.isNotEmpty) {
      add(PlayerTrophyKind.bestBowler, bestBowler.first);
    }

    final bestFielder = mvp.players.where((p) => p.fieldingMvp > 0).toList()
      ..sort((a, b) => b.fieldingMvp.compareTo(a.fieldingMvp));
    if (bestFielder.isNotEmpty) {
      add(PlayerTrophyKind.bestFielder, bestFielder.first);
    }
  }

  void _addScorecardTrophies({
    required List<PlayerTrophy> trophies,
    required String playerId,
    required MatchModel match,
  }) {
    if (match.playerOfMatchId == playerId) {
      trophies.add(
        _trophy(
          playerId: playerId,
          match: match,
          kind: PlayerTrophyKind.playerOfMatch,
          performance: _overallMvpPerformance(match, playerId),
        ),
      );
    }

    final stats = _aggregateScorecardStats(match);
    if (stats.isEmpty) return;

    final ranked = stats.values.toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final losingId = _losingTeamId(match);
    final winnerId = match.winnerTeamId;
    final potmId = match.playerOfMatchId ?? ranked.firstOrNull?.playerId;

    String? fighterId;
    if (losingId != null &&
        winnerId != null &&
        potmId != null &&
        stats[potmId]?.teamId != losingId) {
      final losingSorted = ranked
          .where((p) => p.teamId == losingId)
          .take(3)
          .map((p) => p.playerId)
          .toSet();
      for (final p in ranked) {
        if (losingSorted.contains(p.playerId)) {
          fighterId = p.playerId;
          break;
        }
      }
    }

    if (fighterId == playerId) {
      trophies.add(
        _trophy(
          playerId: playerId,
          match: match,
          kind: PlayerTrophyKind.fighterOfMatch,
          performance: _overallMvpPerformance(match, playerId),
        ),
      );
    }

    final bestBatter = stats.values.toList()
      ..sort((a, b) => b.runs.compareTo(a.runs));
    if (bestBatter.isNotEmpty &&
        bestBatter.first.runs > 0 &&
        bestBatter.first.playerId == playerId) {
      trophies.add(
        _trophy(
          playerId: playerId,
          match: match,
          kind: PlayerTrophyKind.bestBatter,
          performance: _battingLine(match, playerId),
        ),
      );
    }

    final bestBowler = stats.values.toList()
      ..sort((a, b) => b.wickets.compareTo(a.wickets));
    if (bestBowler.isNotEmpty &&
        bestBowler.first.wickets > 0 &&
        bestBowler.first.playerId == playerId) {
      trophies.add(
        _trophy(
          playerId: playerId,
          match: match,
          kind: PlayerTrophyKind.bestBowler,
          performance: _bowlingLine(match, playerId),
        ),
      );
    }

    final bestFielder = stats.values.toList()
      ..sort((a, b) => b.dismissals.compareTo(a.dismissals));
    if (bestFielder.isNotEmpty &&
        bestFielder.first.dismissals > 0 &&
        bestFielder.first.playerId == playerId) {
      trophies.add(
        _trophy(
          playerId: playerId,
          match: match,
          kind: PlayerTrophyKind.bestFielder,
          performance: '${bestFielder.first.dismissals} dismissals',
        ),
      );
    }
  }

  PlayerTrophy _trophy({
    required String playerId,
    required MatchModel match,
    required PlayerTrophyKind kind,
    required String performance,
  }) {
    final date = match.completedAt ?? match.scheduledAt ?? DateTime.now();
    final isTournament = match.tournamentId != null;
    return PlayerTrophy(
      id: '${kind.name}_${match.id}_$playerId',
      kind: kind,
      title: kind.label,
      tier: TrophyTier.gold,
      category: isTournament ? TrophyCategory.tournament : TrophyCategory.match,
      date: date,
      matchId: match.id,
      tournamentId: match.tournamentId,
      matchTitle: match.title,
      performance: performance,
      teamName: _playerTeamName(match, playerId),
      emoji: kind.emoji,
    );
  }

  String _performanceForKind(
    MatchModel match,
    String playerId,
    PlayerTrophyKind kind,
    MvpPlayerScore player,
  ) {
    return switch (kind) {
      PlayerTrophyKind.playerOfMatch ||
      PlayerTrophyKind.fighterOfMatch =>
        _overallMvpPerformance(match, playerId, mvpScore: player.totalMvp),
      PlayerTrophyKind.bestBatter => _battingLine(match, playerId),
      PlayerTrophyKind.bestBowler => _bowlingLine(match, playerId),
      PlayerTrophyKind.bestFielder => _fieldingLine(match, playerId),
    };
  }

  /// POTM / Fighter: `MVP 6.5 · 20(8) · 2/32` — omits batting or bowling when absent.
  String _overallMvpPerformance(
    MatchModel match,
    String playerId, {
    double? mvpScore,
  }) {
    final parts = <String>[];
    if (mvpScore != null && mvpScore > 0) {
      parts.add('MVP ${mvpScore.toStringAsFixed(1)}');
    }
    final bat = _battingLine(match, playerId);
    if (bat.isNotEmpty) parts.add(bat);
    final bowl = _bowlingLine(match, playerId);
    if (bowl.isNotEmpty) parts.add(bowl);
    return parts.join(' · ');
  }

  String _battingLine(MatchModel match, String playerId) {
    var runs = 0;
    var balls = 0;
    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.playerId == playerId) {
          runs += b.runs;
          balls += b.balls;
        }
      }
    }
    if (runs == 0 && balls == 0) return '';
    return '$runs ($balls)';
  }

  String _bowlingLine(MatchModel match, String playerId) {
    var wickets = 0;
    var runs = 0;
    var balls = 0;
    for (final inn in match.innings) {
      for (final b in inn.bowlers) {
        if (b.playerId == playerId) {
          wickets += b.wickets;
          runs += b.runsConceded;
          balls += b.oversBowledBalls;
        }
      }
    }
    if (wickets == 0 && balls == 0) return '';
    return '$wickets/$runs';
  }

  String _fieldingLine(MatchModel match, String playerId) {
    var catches = 0;
    var runOuts = 0;
    var stumpings = 0;
    for (final inn in match.innings) {
      for (final f in inn.fielders) {
        if (f.playerId != playerId) continue;
        catches += f.catches;
        runOuts += f.runOuts;
        stumpings += f.stumpings;
      }
    }
    final parts = <String>[];
    if (catches > 0) parts.add('$catches ct');
    if (runOuts > 0) parts.add('$runOuts ro');
    if (stumpings > 0) parts.add('$stumpings st');
    return parts.join(' · ');
  }

  Map<String, _ScorecardPlayerStats> _aggregateScorecardStats(MatchModel match) {
    final stats = <String, _ScorecardPlayerStats>{};

    void ensure(String playerId, String teamId) {
      stats.putIfAbsent(
        playerId,
        () => _ScorecardPlayerStats(playerId: playerId, teamId: teamId),
      );
    }

    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.playerId.isEmpty) continue;
        ensure(b.playerId, inn.battingTeamId);
        final p = stats[b.playerId]!;
        p.runs += b.runs;
        p.wickets += 0;
      }
      for (final b in inn.bowlers) {
        if (b.playerId.isEmpty) continue;
        ensure(b.playerId, inn.bowlingTeamId);
        stats[b.playerId]!.wickets += b.wickets;
      }
      for (final f in inn.fielders) {
        if (f.playerId.isEmpty) continue;
        ensure(f.playerId, inn.bowlingTeamId);
        final p = stats[f.playerId]!;
        p.catches += f.catches;
        p.runOuts += f.runOuts;
        p.stumpings += f.stumpings;
      }
    }

    for (final p in stats.values) {
      p.totalScore = p.runs + p.wickets * 25 + p.dismissals * 12;
    }
    return stats;
  }

  String? _losingTeamId(MatchModel match) {
    final winnerId = match.winnerTeamId;
    if (winnerId == null) return null;
    if (winnerId == match.teamAId) return match.teamBId;
    if (winnerId == match.teamBId) return match.teamAId;
    return null;
  }

  String _playerTeamName(MatchModel match, String playerId) {
    final setup = match.setup;
    if (setup == null) return '';
    if (setup.teamAPlayingPlayers.any((p) => p.id == playerId)) {
      return match.teamAName;
    }
    if (setup.teamBPlayingPlayers.any((p) => p.id == playerId)) {
      return match.teamBName;
    }
    return '';
  }
}

class _ScorecardPlayerStats {
  _ScorecardPlayerStats({required this.playerId, required this.teamId});

  final String playerId;
  final String teamId;
  int runs = 0;
  int wickets = 0;
  int catches = 0;
  int runOuts = 0;
  int stumpings = 0;
  double totalScore = 0;

  int get dismissals => catches + runOuts + stumpings;
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
