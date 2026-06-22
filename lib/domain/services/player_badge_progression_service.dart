import '../../core/constants/enums.dart';
import '../../core/utils/cricket_math.dart';
import '../../core/utils/overs_formatter.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import 'player_cricket_profile_models.dart';

/// Match + career badge progression — highest eligible only, no cascade unlocks.
class PlayerBadgeProgressionService {
  const PlayerBadgeProgressionService();

  static const runsInMatchGroup = 'runs_in_match';
  static const sixesInMatchGroup = 'sixes_in_match';
  static const foursInMatchGroup = 'fours_in_match';
  static const strikeRateGroup = 'strike_rate_match';
  static const wicketsInMatchGroup = 'wickets_in_match';
  static const catchesInMatchGroup = 'catches_in_match';
  static const careerRunsGroup = 'career_runs';
  static const careerSixesGroup = 'career_sixes';
  static const careerWicketsGroup = 'career_wickets';
  static const careerCatchesGroup = 'career_catches';
  static const careerRunOutsGroup = 'career_run_outs';
  static const captainWinsGroup = 'captain_wins';
  static const matchesPlayedGroup = 'matches_played';

  /// SR badges require 6+ balls faced or more than 20 runs in the innings.
  static bool qualifiesForSrBadge({required int runs, required int balls}) =>
      balls >= 6 || runs > 20;

  /// Badges earned in a single match (all players).
  List<MatchBadgeUnlock> evaluateMatchBadgeUnlocks({
    required MatchModel match,
    List<BallEventModel> ballEvents = const [],
  }) {
    final unlocks = <MatchBadgeUnlock>[];
    final eventsByMatch = {match.id: ballEvents};

    for (final playerId in _playerIdsInMatch(match)) {
      final records = <String, _MutableRecord>{};
      _processMatch(
        records: records,
        playerId: playerId,
        match: match,
        ballEvents: ballEvents,
      );
      _evaluateFirstTimeSpecials(
        records: records,
        playerId: playerId,
        matches: [match],
        ballEventsByMatch: eventsByMatch,
      );

      final playerName = _playerDisplayName(match, playerId);
      for (final entry in records.entries) {
        final record = entry.value;
        if (record.repeatability == BadgeRepeatability.repeatable) {
          for (final history in record.history) {
            if (history.matchId != match.id) continue;
            unlocks.add(
              MatchBadgeUnlock(
                badgeId: entry.key,
                playerId: playerId,
                playerName: playerName,
                performanceSnapshot: history.performanceSnapshot,
              ),
            );
          }
        } else if (record.isOneTimeUnlocked) {
          final history = record.history.firstOrNull;
          if (history == null) continue;
          if (history.matchId.isNotEmpty && history.matchId != match.id) {
            continue;
          }
          unlocks.add(
            MatchBadgeUnlock(
              badgeId: entry.key,
              playerId: playerId,
              playerName: playerName,
              performanceSnapshot: history.performanceSnapshot,
            ),
          );
        }
      }
    }

    unlocks.sort((a, b) {
      final name = a.playerName.compareTo(b.playerName);
      if (name != 0) return name;
      return a.badgeId.compareTo(b.badgeId);
    });
    return unlocks;
  }

  Set<String> _playerIdsInMatch(MatchModel match) {
    final ids = <String>{};
    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.playerId.isNotEmpty) ids.add(b.playerId);
      }
      for (final b in inn.bowlers) {
        if (b.playerId.isNotEmpty) ids.add(b.playerId);
      }
      for (final f in inn.fielders) {
        if (f.playerId.isNotEmpty) ids.add(f.playerId);
      }
    }
    return ids;
  }

  String _playerDisplayName(MatchModel match, String playerId) {
    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.playerId == playerId && b.playerName.isNotEmpty) {
          return b.playerName;
        }
      }
      for (final b in inn.bowlers) {
        if (b.playerId == playerId && b.playerName.isNotEmpty) {
          return b.playerName;
        }
      }
      for (final f in inn.fielders) {
        if (f.playerId == playerId && f.playerName.isNotEmpty) {
          return f.playerName;
        }
      }
    }
    final setup = match.setup;
    if (setup != null) {
      for (final p in [
        ...setup.teamAPlayingPlayers,
        ...setup.teamASubstitutePlayers,
        ...setup.teamBPlayingPlayers,
        ...setup.teamBSubstitutePlayers,
      ]) {
        if (p.id == playerId && p.name.isNotEmpty) return p.name;
      }
    }
    return 'Player';
  }

  Map<String, PlayerBadgeRecord> computeRecords({
    required String playerId,
    required PlayerStatsModel stats,
    required List<MatchModel> completedMatches,
    required CaptainStatsSnapshot captainStats,
    Map<String, List<BallEventModel>> ballEventsByMatch = const {},
    required List<PlayerBadgeDefinition> catalog,
  }) {
    final records = <String, _MutableRecord>{};
    final sorted = completedMatches.toList()
      ..sort(
        (a, b) => (a.completedAt ?? a.scheduledAt ?? DateTime(2000))
            .compareTo(b.completedAt ?? b.scheduledAt ?? DateTime(2000)),
      );

    for (final match in sorted) {
      _processMatch(
        records: records,
        playerId: playerId,
        match: match,
        ballEvents: ballEventsByMatch[match.id] ?? const [],
      );
    }

    _applyCareerHighestOnly(
      records: records,
      value: stats.runs,
      tiers: const [
        ('career_runs_100', 100),
        ('career_runs_500', 500),
        ('career_runs_1000', 1000),
        ('career_runs_5000', 5000),
        ('career_runs_10000', 10000),
      ],
    );
    _applyCareerHighestOnly(
      records: records,
      value: stats.sixes,
      tiers: const [
        ('career_6s_50', 50),
        ('career_6s_100', 100),
        ('career_6s_250', 250),
        ('career_6s_500', 500),
      ],
    );
    _applyCareerHighestOnly(
      records: records,
      value: stats.wickets,
      tiers: const [
        ('career_wkts_50', 50),
        ('career_wkts_100', 100),
        ('career_wkts_250', 250),
        ('career_wkts_500', 500),
      ],
    );
    _applyCareerHighestOnly(
      records: records,
      value: stats.catches,
      tiers: const [
        ('career_catch_50', 50),
        ('career_catch_100', 100),
        ('career_catch_250', 250),
      ],
    );

    _applyCareerHighestOnly(
      records: records,
      value: stats.matchesPlayed,
      tiers: const [
        ('debut', 1),
        ('matches_25', 25),
        ('matches_50', 50),
        ('matches_100', 100),
        ('matches_250', 250),
        ('matches_500', 500),
      ],
    );
    if (stats.matchesPlayed >= 200) {
      _unlockOneTime(
        records: records,
        badgeId: 'veteran',
        achievedAt: DateTime.now(),
        snapshot: '${stats.matchesPlayed} matches',
      );
    }
    if (stats.matchesPlayed >= 1000) {
      _unlockOneTime(
        records: records,
        badgeId: 'legend',
        achievedAt: DateTime.now(),
        snapshot: '${stats.matchesPlayed} matches',
      );
    }

    _applyCareerHighestOnly(
      records: records,
      value: captainStats.wins,
      tiers: const [
        ('cap_wins_10', 10),
        ('cap_wins_25', 25),
        ('cap_wins_50', 50),
        ('cap_wins_100', 100),
      ],
    );

    _applyStandaloneCareerBadges(
      records: records,
      playerId: playerId,
      stats: stats,
      matches: sorted,
      captainStats: captainStats,
      ballEventsByMatch: ballEventsByMatch,
    );

    _evaluateFirstTimeSpecials(
      records: records,
      playerId: playerId,
      matches: sorted,
      ballEventsByMatch: ballEventsByMatch,
    );

    final repeatabilityById = {
      for (final def in catalog) def.id: def.repeatability,
    };

    return {
      for (final entry in records.entries)
        entry.key: entry.value.toRecord(
          entry.key,
          repeatabilityById[entry.key] ?? BadgeRepeatability.repeatable,
        ),
    };
  }

  List<PlayerBadgeProgress> toProgressList({
    required List<PlayerBadgeDefinition> catalog,
    required Map<String, PlayerBadgeRecord> records,
    required String playerId,
    required PlayerStatsModel stats,
    required List<MatchModel> completedMatches,
    required CaptainStatsSnapshot captainStats,
    Map<String, List<BallEventModel>> ballEventsByMatch = const {},
  }) {
    return catalog.map((def) {
      final record = records[def.id];
      final unlocked = record?.unlocked ?? false;
      final progress = _progressTowardBadge(
        def: def,
        stats: stats,
        matches: completedMatches,
        playerId: playerId,
        captainStats: captainStats,
        ballEventsByMatch: ballEventsByMatch,
        unlocked: unlocked,
      );
      final next = def.isRepeatable ? _nextTierInGroup(def, catalog) : null;

      if (def.isOneTime) {
        return PlayerBadgeProgress(
          definition: def,
          unlocked: unlocked,
          progress: progress.progress,
          target: progress.target,
          unlockedAt: record?.unlockedAt,
          matchId: record?.unlockedMatchId,
          unlockPerformanceSnapshot: record?.unlockPerformanceSnapshot,
          unlockMatchTitle: record?.unlockMatchTitle,
          nextTierTitle: next?.title,
          progressToNextTier:
              next != null && !unlocked ? 'Progress to ${next.title}' : null,
        );
      }

      return PlayerBadgeProgress(
        definition: def,
        unlocked: unlocked,
        unlockCount: record?.unlockCount ?? 0,
        progress: progress.progress,
        target: progress.target,
        earnedAt: record?.lastAchievedAt,
        firstAchievedAt: record?.firstAchievedAt,
        matchId: record?.achievementHistory.lastOrNull?.matchId,
        achievementHistory: record?.achievementHistory ?? const [],
        nextTierTitle: next?.title,
        progressToNextTier: next != null && !unlocked
            ? 'Progress to ${next.title}'
            : (next != null && unlocked ? 'Next: ${next.title}' : null),
      );
    }).toList();
  }

  void _processMatch({
    required Map<String, _MutableRecord> records,
    required String playerId,
    required MatchModel match,
    required List<BallEventModel> ballEvents,
  }) {
    final achievedAt = match.completedAt ?? match.scheduledAt ?? DateTime.now();
    var matchRuns = 0;
    var matchBalls = 0;
    var matchFours = 0;
    var matchSixes = 0;
    var matchWickets = 0;
    var matchCatches = 0;
    var bestSr = 0.0;
    var bestSrRuns = 0;
    var bestSrBalls = 0;

    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.playerId != playerId) continue;
        matchRuns += b.runs;
        matchBalls += b.balls;
        matchFours += b.fours;
        matchSixes += b.sixes;
        if (b.balls > 0 &&
            qualifiesForSrBadge(runs: b.runs, balls: b.balls)) {
          final sr = CricketMath.strikeRate(b.runs, b.balls);
          if (sr >= bestSr) {
            bestSr = sr;
            bestSrRuns = b.runs;
            bestSrBalls = b.balls;
          }
        }
      }
      for (final b in inn.bowlers) {
        if (b.playerId == playerId) matchWickets += b.wickets;
      }
      for (final f in inn.fielders) {
        if (f.playerId == playerId) matchCatches += f.catches;
      }
    }

    _awardHighestInGroup(
      records: records,
      tiers: const [
        ('bat_30', 30),
        ('bat_50', 50),
        ('bat_75', 75),
        ('bat_100', 100),
        ('bat_150', 150),
        ('bat_200', 200),
      ],
      value: matchRuns,
      match: match,
      achievedAt: achievedAt,
      snapshot: '$matchRuns${matchBalls > 0 ? ' ($matchBalls)' : ''}',
    );

    _awardHighestInGroup(
      records: records,
      tiers: const [
        ('6s_5', 5),
        ('6s_10', 10),
        ('6s_15', 15),
      ],
      value: matchSixes,
      match: match,
      achievedAt: achievedAt,
      snapshot: '$matchSixes sixes',
    );

    _awardHighestInGroup(
      records: records,
      tiers: const [
        ('4s_10', 10),
        ('4s_15', 15),
        ('4s_20', 20),
      ],
      value: matchFours,
      match: match,
      achievedAt: achievedAt,
      snapshot: '$matchFours fours',
    );

    _awardHighestSr(
      records: records,
      sr: bestSr,
      runs: bestSrRuns,
      balls: bestSrBalls,
      match: match,
      achievedAt: achievedAt,
    );

    _awardHighestInGroup(
      records: records,
      tiers: const [
        ('bowl_3', 3),
        ('bowl_4', 4),
        ('bowl_5', 5),
        ('bowl_6', 6),
      ],
      value: matchWickets,
      match: match,
      achievedAt: achievedAt,
      snapshot: '$matchWickets wickets',
    );

    _awardHighestInGroup(
      records: records,
      tiers: const [
        ('catch_3', 3),
        ('catch_5', 5),
      ],
      value: matchCatches,
      match: match,
      achievedAt: achievedAt,
      snapshot: '$matchCatches catches',
    );

    _evaluateFieldingExtras(records, playerId, match, achievedAt);
    _evaluateSpecialMatchBadges(records, playerId, match, achievedAt);
  }

  void _evaluateFirstTimeSpecials({
    required Map<String, _MutableRecord> records,
    required String playerId,
    required List<MatchModel> matches,
    required Map<String, List<BallEventModel>> ballEventsByMatch,
  }) {
    for (final match in matches) {
      final achievedAt = match.completedAt ?? match.scheduledAt ?? DateTime.now();
      var matchRuns = 0;
      var matchWickets = 0;

      for (final inn in match.innings) {
        for (final b in inn.batsmen) {
          if (b.playerId == playerId) matchRuns += b.runs;
        }
        for (final b in inn.bowlers) {
          if (b.playerId == playerId) matchWickets += b.wickets;
        }
      }

      if (matchRuns >= 100) {
        _unlockOneTime(
          records: records,
          badgeId: 'first_century',
          match: match,
          achievedAt: achievedAt,
          snapshot: '$matchRuns runs',
        );
      }
      if (matchWickets >= 5) {
        _unlockOneTime(
          records: records,
          badgeId: 'first_five_wicket',
          match: match,
          achievedAt: achievedAt,
          snapshot: '$matchWickets wickets',
        );
      }
      if (match.playerOfMatchId == playerId) {
        _unlockOneTime(
          records: records,
          badgeId: 'first_motm',
          match: match,
          achievedAt: achievedAt,
          snapshot: 'Player of the match',
        );
      }

      final events = ballEventsByMatch[match.id] ?? const [];
      var streak = 0;
      for (final e in events) {
        if (e.bowlerId != playerId) continue;
        if (e.bowlerGetsWicket && e.isLegalDelivery) {
          streak += 1;
          if (streak >= 3) {
            _unlockOneTime(
              records: records,
              badgeId: 'first_hat_trick',
              match: match,
              achievedAt: achievedAt,
              snapshot: 'Hat-trick',
            );
            break;
          }
        } else if (e.isLegalDelivery) {
          streak = 0;
        }
      }

      if (match.tournamentId != null && match.winnerTeamId != null) {
        _unlockOneTime(
          records: records,
          badgeId: 'tournament_winner',
          match: match,
          achievedAt: achievedAt,
          snapshot: 'Tournament match win',
        );
        final setup = match.setup;
        if (setup != null) {
          final isCap = setup.teamACaptainId == playerId ||
              setup.teamBCaptainId == playerId;
          if (isCap) {
            _unlockOneTime(
              records: records,
              badgeId: 'captain_champion',
              match: match,
              achievedAt: achievedAt,
              snapshot: 'Captain — tournament win',
            );
          }
        }
      }
    }
  }

  void _awardHighestInGroup({
    required Map<String, _MutableRecord> records,
    required List<(String badgeId, int threshold)> tiers,
    required int value,
    required MatchModel match,
    required DateTime achievedAt,
    required String snapshot,
  }) {
    if (value <= 0) return;
    String? badgeId;
    for (final tier in tiers) {
      if (value >= tier.$2) badgeId = tier.$1;
    }
    if (badgeId == null) return;
    _addAchievement(
      records: records,
      badgeId: badgeId,
      match: match,
      achievedAt: achievedAt,
      snapshot: snapshot,
    );
  }

  void _awardHighestSr({
    required Map<String, _MutableRecord> records,
    required double sr,
    required int runs,
    required int balls,
    required MatchModel match,
    required DateTime achievedAt,
  }) {
    if (!qualifiesForSrBadge(runs: runs, balls: balls)) return;

    const tiers = [
      ('sr_200', 200.0),
      ('sr_250', 250.0),
      ('sr_300', 300.0),
    ];
    String? badgeId;
    for (final (id, srMin) in tiers) {
      if (sr >= srMin) badgeId = id;
    }
    if (badgeId == null) return;
    _addAchievement(
      records: records,
      badgeId: badgeId,
      match: match,
      achievedAt: achievedAt,
      snapshot: '${sr.toStringAsFixed(0)} SR ($runs/$balls)',
    );
  }

  void _addAchievement({
    required Map<String, _MutableRecord> records,
    required String badgeId,
    required MatchModel match,
    required DateTime achievedAt,
    required String snapshot,
  }) {
    final entry = BadgeAchievementEntry(
      matchId: match.id,
      achievedAt: achievedAt,
      performanceSnapshot: snapshot,
      matchTitle: match.title,
    );
    records
        .putIfAbsent(badgeId, () => _MutableRecord(BadgeRepeatability.repeatable))
        .addRepeatable(entry);
  }

  void _unlockOneTime({
    required Map<String, _MutableRecord> records,
    required String badgeId,
    required DateTime achievedAt,
    required String snapshot,
    MatchModel? match,
  }) {
    final entry = BadgeAchievementEntry(
      matchId: match?.id ?? '',
      achievedAt: achievedAt,
      performanceSnapshot: snapshot,
      matchTitle: match?.title ?? '',
    );
    records
        .putIfAbsent(badgeId, () => _MutableRecord(BadgeRepeatability.oneTime))
        .unlockOneTime(entry);
  }

  void _applyCareerHighestOnly({
    required Map<String, _MutableRecord> records,
    required int value,
    required List<(String badgeId, int threshold)> tiers,
  }) {
    if (value <= 0) return;
    String? badgeId;
    for (final tier in tiers) {
      if (value >= tier.$2) badgeId = tier.$1;
    }
    if (badgeId == null) return;

    for (final tier in tiers) {
      if (tier.$1 != badgeId) records.remove(tier.$1);
    }

    if (records[badgeId]?.isOneTimeUnlocked == true) return;

    records[badgeId] = _MutableRecord(BadgeRepeatability.oneTime)
      ..unlockOneTime(
        BadgeAchievementEntry(
          matchId: '',
          achievedAt: DateTime.now(),
          performanceSnapshot: 'Career total: $value',
        ),
      );
  }

  void _evaluateFieldingExtras(
    Map<String, _MutableRecord> records,
    String playerId,
    MatchModel match,
    DateTime achievedAt,
  ) {
    var runOuts = 0;
    var dismissals = 0;
    for (final inn in match.innings) {
      for (final f in inn.fielders) {
        if (f.playerId != playerId) continue;
        runOuts += f.runOuts;
        dismissals += f.catches + f.runOuts + f.stumpings;
      }
    }
    if (runOuts >= 2) {
      _addAchievement(
        records: records,
        badgeId: 'ro_2',
        match: match,
        achievedAt: achievedAt,
        snapshot: '$runOuts run outs',
      );
    }
    if (dismissals >= 5) {
      _addAchievement(
        records: records,
        badgeId: 'safe_hands',
        match: match,
        achievedAt: achievedAt,
        snapshot: '$dismissals dismissals',
      );
    }
  }

  void _evaluateSpecialMatchBadges(
    Map<String, _MutableRecord> records,
    String playerId,
    MatchModel match,
    DateTime achievedAt,
  ) {
    var runs = 0;
    var wickets = 0;
    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.playerId == playerId) runs += b.runs;
      }
      for (final b in inn.bowlers) {
        if (b.playerId == playerId) wickets += b.wickets;
      }
    }
    if (runs >= 100 && wickets >= 5) {
      _addAchievement(
        records: records,
        badgeId: 'all_round_match',
        match: match,
        achievedAt: achievedAt,
        snapshot: '$runs runs & $wickets wickets',
      );
    } else if (runs >= 50 && wickets >= 3) {
      _addAchievement(
        records: records,
        badgeId: 'all_round_hero',
        match: match,
        achievedAt: achievedAt,
        snapshot: '$runs runs & $wickets wickets',
      );
    }

    if (match.innings.length >= 2) {
      final second = match.innings[1];
      for (final b in second.batsmen) {
        if (b.playerId != playerId) continue;
        final sr = CricketMath.strikeRate(b.runs, b.balls);
        if (b.runs >= 30 && sr >= 150) {
          _addAchievement(
            records: records,
            badgeId: 'finisher',
            match: match,
            achievedAt: achievedAt,
            snapshot: '${b.runs} (${b.balls}) SR ${sr.toStringAsFixed(0)}',
          );
        }
      }
    }
  }

  void _applyStandaloneCareerBadges({
    required Map<String, _MutableRecord> records,
    required String playerId,
    required PlayerStatsModel stats,
    required List<MatchModel> matches,
    required CaptainStatsSnapshot captainStats,
    required Map<String, List<BallEventModel>> ballEventsByMatch,
  }) {
    final overs = OversFormatter.calculateOvers(stats.oversBowledBalls, 6);
    if (overs >= 20) {
      final econ = OversFormatter.economyFromDecimalOvers(
        stats.runsConceded,
        overs,
      );
      if (econ > 0 && econ < 3) {
        _applyCareerHighestOnly(
          records: records,
          value: 1,
          tiers: const [('econ_3', 1)],
        );
        records.remove('econ_4');
      } else if (econ > 0 && econ < 4) {
        _applyCareerHighestOnly(
          records: records,
          value: 1,
          tiers: const [('econ_4', 1)],
        );
      }
    }

    if (captainStats.matchesAsCaptain >= 10 && captainStats.winPct >= 70) {
      _applyCareerHighestOnly(
        records: records,
        value: 1,
        tiers: const [('winning_machine', 1)],
      );
    }

    if (captainStats.successfulChases >= 5) {
      _unlockOneTime(
        records: records,
        badgeId: 'chase_master',
        achievedAt: DateTime.now(),
        snapshot: '${captainStats.successfulChases} successful chases',
      );
    }

    if (captainStats.lowestDefendedScore >= 100) {
      _unlockOneTime(
        records: records,
        badgeId: 'defender',
        achievedAt: DateTime.now(),
        snapshot: 'Defended ${captainStats.lowestDefendedScore}',
      );
    }

    var potmStreak = 0;
    for (final match in matches) {
      if (match.playerOfMatchId == playerId) {
        potmStreak += 1;
        if (potmStreak >= 2) {
          _addAchievement(
            records: records,
            badgeId: 'potm_streak',
            match: match,
            achievedAt: match.completedAt ?? DateTime.now(),
            snapshot: '2 consecutive POTM',
          );
          break;
        }
      } else {
        potmStreak = 0;
      }
    }

    final dates = matches
        .map((m) => m.completedAt ?? m.scheduledAt)
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (dates.length >= 10) {
      for (var i = 0; i <= dates.length - 10; i++) {
        if (dates[i + 9].difference(dates[i]).inDays <= 30) {
          _unlockOneTime(
            records: records,
            badgeId: 'iron_man',
            achievedAt: dates[i + 9],
            snapshot: '10 matches in 30 days',
          );
          break;
        }
      }
    }

    for (final match in matches) {
      if (!match.rules.superOverEnabled) continue;
      if (match.playerOfMatchId != playerId) continue;
      _addAchievement(
        records: records,
        badgeId: 'super_over_hero',
        match: match,
        achievedAt: match.completedAt ?? DateTime.now(),
        snapshot: 'Super over hero',
      );
    }

    for (final entry in ballEventsByMatch.entries) {
      for (final e in entry.value) {
        if (e.wicketType != WicketType.runOut) continue;
        if (e.primaryFielderId == playerId || e.fielderId == playerId) {
          final match = matches.where((m) => m.id == entry.key).firstOrNull;
          if (match != null) {
            _addAchievement(
              records: records,
              badgeId: 'ro_direct',
              match: match,
              achievedAt: match.completedAt ?? DateTime.now(),
              snapshot: 'Direct hit run out',
            );
          }
          break;
        }
      }
    }
  }

  PlayerBadgeDefinition? _nextTierInGroup(
    PlayerBadgeDefinition def,
    List<PlayerBadgeDefinition> catalog,
  ) {
    if (def.progressionGroup == null) return null;
    final group = catalog
        .where((d) => d.progressionGroup == def.progressionGroup)
        .toList()
      ..sort((a, b) => a.groupOrder.compareTo(b.groupOrder));
    final idx = group.indexWhere((d) => d.id == def.id);
    if (idx < 0 || idx >= group.length - 1) return null;
    return group[idx + 1];
  }

  ({double progress, double target}) _progressTowardBadge({
    required PlayerBadgeDefinition def,
    required PlayerStatsModel stats,
    required List<MatchModel> matches,
    required String playerId,
    required CaptainStatsSnapshot captainStats,
    required Map<String, List<BallEventModel>> ballEventsByMatch,
    required bool unlocked,
  }) {
    return switch (def.id) {
      'bat_30' ||
      'bat_50' ||
      'bat_75' ||
      'bat_100' ||
      'bat_150' ||
      'bat_200' =>
        _matchRunsProgress(matches, playerId, _runsThreshold(def.id)),
      '6s_5' || '6s_10' || '6s_15' =>
        _matchSixesProgress(matches, playerId, _sixesThreshold(def.id)),
      '4s_10' || '4s_15' || '4s_20' =>
        _matchFoursProgress(matches, playerId, _foursThreshold(def.id)),
      'bowl_3' ||
      'bowl_4' ||
      'bowl_5' ||
      'bowl_6' =>
        _matchWicketsProgress(matches, playerId, _wicketsThreshold(def.id)),
      'catch_3' || 'catch_5' =>
        _matchCatchesProgress(matches, playerId, _catchesThreshold(def.id)),
      'sr_200' => _srProgress(matches, playerId, 200),
      'sr_250' => _srProgress(matches, playerId, 250),
      'sr_300' => _srProgress(matches, playerId, 300),
      'career_runs_100' => (progress: stats.runs.toDouble(), target: 100),
      'career_runs_500' => (progress: stats.runs.toDouble(), target: 500),
      'career_runs_1000' => (progress: stats.runs.toDouble(), target: 1000),
      'career_runs_5000' => (progress: stats.runs.toDouble(), target: 5000),
      'career_runs_10000' => (progress: stats.runs.toDouble(), target: 10000),
      'career_wkts_50' => (progress: stats.wickets.toDouble(), target: 50),
      'career_wkts_100' => (progress: stats.wickets.toDouble(), target: 100),
      'career_wkts_250' => (progress: stats.wickets.toDouble(), target: 250),
      'career_wkts_500' => (progress: stats.wickets.toDouble(), target: 500),
      'career_6s_50' => (progress: stats.sixes.toDouble(), target: 50),
      'career_6s_100' => (progress: stats.sixes.toDouble(), target: 100),
      'career_6s_250' => (progress: stats.sixes.toDouble(), target: 250),
      'career_6s_500' => (progress: stats.sixes.toDouble(), target: 500),
      'career_catch_50' => (progress: stats.catches.toDouble(), target: 50),
      'career_catch_100' => (progress: stats.catches.toDouble(), target: 100),
      'career_catch_250' => (progress: stats.catches.toDouble(), target: 250),
      'cap_wins_10' =>
        (progress: captainStats.wins.toDouble(), target: 10),
      'cap_wins_25' =>
        (progress: captainStats.wins.toDouble(), target: 25),
      'cap_wins_50' =>
        (progress: captainStats.wins.toDouble(), target: 50),
      'cap_wins_100' =>
        (progress: captainStats.wins.toDouble(), target: 100),
      'debut' ||
      'matches_25' ||
      'matches_50' ||
      'matches_100' ||
      'matches_250' ||
      'matches_500' ||
      'veteran' ||
      'legend' =>
        (
          progress: stats.matchesPlayed.toDouble(),
          target: _matchesThreshold(def.id).toDouble(),
        ),
      _ => (progress: unlocked ? 1.0 : 0.0, target: 1.0),
    };
  }

  int _runsThreshold(String id) => switch (id) {
        'bat_30' => 30,
        'bat_50' => 50,
        'bat_75' => 75,
        'bat_100' => 100,
        'bat_150' => 150,
        'bat_200' => 200,
        _ => 1,
      };

  int _sixesThreshold(String id) => switch (id) {
        '6s_5' => 5,
        '6s_10' => 10,
        '6s_15' => 15,
        _ => 1,
      };

  int _foursThreshold(String id) => switch (id) {
        '4s_10' => 10,
        '4s_15' => 15,
        '4s_20' => 20,
        _ => 1,
      };

  int _wicketsThreshold(String id) => switch (id) {
        'bowl_3' => 3,
        'bowl_4' => 4,
        'bowl_5' => 5,
        'bowl_6' => 6,
        _ => 1,
      };

  int _catchesThreshold(String id) =>
      id == 'catch_5' ? 5 : 3;

  int _matchesThreshold(String id) => switch (id) {
        'debut' => 1,
        'matches_25' => 25,
        'matches_50' => 50,
        'matches_100' => 100,
        'matches_250' => 250,
        'matches_500' => 500,
        'veteran' => 200,
        'legend' => 1000,
        _ => 1,
      };

  ({double progress, double target}) _matchRunsProgress(
    List<MatchModel> matches,
    String playerId,
    int threshold,
  ) {
    var best = 0;
    for (final match in matches) {
      var total = 0;
      for (final inn in match.innings) {
        for (final b in inn.batsmen) {
          if (b.playerId == playerId) total += b.runs;
        }
      }
      if (total > best) best = total;
    }
    return (progress: best.toDouble(), target: threshold.toDouble());
  }

  ({double progress, double target}) _matchSixesProgress(
    List<MatchModel> matches,
    String playerId,
    int threshold,
  ) {
    var best = 0;
    for (final match in matches) {
      var total = 0;
      for (final inn in match.innings) {
        for (final b in inn.batsmen) {
          if (b.playerId == playerId) total += b.sixes;
        }
      }
      if (total > best) best = total;
    }
    return (progress: best.toDouble(), target: threshold.toDouble());
  }

  ({double progress, double target}) _matchFoursProgress(
    List<MatchModel> matches,
    String playerId,
    int threshold,
  ) {
    var best = 0;
    for (final match in matches) {
      var total = 0;
      for (final inn in match.innings) {
        for (final b in inn.batsmen) {
          if (b.playerId == playerId) total += b.fours;
        }
      }
      if (total > best) best = total;
    }
    return (progress: best.toDouble(), target: threshold.toDouble());
  }

  ({double progress, double target}) _matchWicketsProgress(
    List<MatchModel> matches,
    String playerId,
    int threshold,
  ) {
    var best = 0;
    for (final match in matches) {
      var total = 0;
      for (final inn in match.innings) {
        for (final b in inn.bowlers) {
          if (b.playerId == playerId) total += b.wickets;
        }
      }
      if (total > best) best = total;
    }
    return (progress: best.toDouble(), target: threshold.toDouble());
  }

  ({double progress, double target}) _matchCatchesProgress(
    List<MatchModel> matches,
    String playerId,
    int threshold,
  ) {
    var best = 0;
    for (final match in matches) {
      var total = 0;
      for (final inn in match.innings) {
        for (final f in inn.fielders) {
          if (f.playerId == playerId) total += f.catches;
        }
      }
      if (total > best) best = total;
    }
    return (progress: best.toDouble(), target: threshold.toDouble());
  }

  ({double progress, double target}) _srProgress(
    List<MatchModel> matches,
    String playerId,
    double srTarget,
  ) {
    var bestSr = 0.0;
    for (final match in matches) {
      for (final inn in match.innings) {
        for (final b in inn.batsmen) {
          if (b.playerId != playerId) continue;
          if (!qualifiesForSrBadge(runs: b.runs, balls: b.balls)) continue;
          final sr = CricketMath.strikeRate(b.runs, b.balls);
          if (sr > bestSr) bestSr = sr;
        }
      }
    }
    return (progress: bestSr, target: srTarget);
  }
}

class _MutableRecord {
  _MutableRecord(this.repeatability);

  final BadgeRepeatability repeatability;
  final List<BadgeAchievementEntry> history = [];
  bool _oneTimeUnlocked = false;

  bool get isOneTimeUnlocked => _oneTimeUnlocked;

  int get count => history.length;

  void addRepeatable(BadgeAchievementEntry entry) => history.add(entry);

  void unlockOneTime(BadgeAchievementEntry entry) {
    if (_oneTimeUnlocked) return;
    _oneTimeUnlocked = true;
    history
      ..clear()
      ..add(entry);
  }

  PlayerBadgeRecord toRecord(String badgeId, BadgeRepeatability repeatability) {
    if (repeatability == BadgeRepeatability.oneTime) {
      final entry = history.firstOrNull;
      return PlayerBadgeRecord(
        badgeId: badgeId,
        repeatability: BadgeRepeatability.oneTime,
        oneTimeUnlocked: _oneTimeUnlocked,
        unlockedAt: entry?.achievedAt,
        unlockedMatchId: entry?.matchId,
        unlockPerformanceSnapshot: entry?.performanceSnapshot,
        unlockMatchTitle: entry?.matchTitle,
      );
    }

    if (history.isEmpty) {
      return PlayerBadgeRecord(
        badgeId: badgeId,
        repeatability: BadgeRepeatability.repeatable,
      );
    }
    final sorted = history.toList()
      ..sort((a, b) => a.achievedAt.compareTo(b.achievedAt));
    return PlayerBadgeRecord(
      badgeId: badgeId,
      repeatability: BadgeRepeatability.repeatable,
      unlockCount: sorted.length,
      firstAchievedAt: sorted.first.achievedAt,
      lastAchievedAt: sorted.last.achievedAt,
      achievementHistory: sorted,
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

extension _LastOrNull<E> on List<E> {
  E? get lastOrNull => isEmpty ? null : last;
}
