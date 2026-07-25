import '../../../core/constants/enums.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/ball_event_model.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/player_model.dart';
import '../../scoring/ball_event_aggregator.dart';
import 'team_profile_models.dart';

class _PlayerAgg {
  _PlayerAgg({
    required this.playerId,
    required this.playerName,
    this.photoUrl,
    this.role = '',
  });

  final String playerId;
  String playerName;
  String? photoUrl;
  String role;

  int matches = 0;
  final Set<String> matchIds = {};

  // Batting
  int runs = 0;
  int balls = 0;
  int dismissals = 0;
  int notOuts = 0;
  int fours = 0;
  int sixes = 0;
  int fifties = 0;
  int hundreds = 0;
  int highScore = 0;
  int fastestFiftyBalls = 0;
  int fastestHundredBalls = 0;

  // Bowling
  int wickets = 0;
  int runsConceded = 0;
  int ballsBowled = 0;
  int fiveWickets = 0;
  int bestWickets = 0;
  int bestRunsConceded = 9999;
  int maidens = 0;
  int dotBalls = 0;

  // Fielding
  int catches = 0;
  int runOuts = 0;
  int stumpings = 0;

  double get average => CricketMath.battingAverage(runs, dismissals);
  double get strikeRate => CricketMath.strikeRate(runs, balls);
  double get economy =>
      CricketMath.economyRate(runsConceded, ballsBowled, 6);
  double get bowlingSr =>
      wickets == 0 ? double.infinity : ballsBowled / wickets;
  double get bowlingAvg => CricketMath.bowlingAverage(runsConceded, wickets);
  int get fieldingPoints => catches * 2 + runOuts * 3 + stumpings * 2;
  double get oversBowled => ballsBowled / 6.0;
}

/// Builds team-internal leaderboards from match innings + ball events.
class TeamLeaderboardService {
  TeamLeaderboardService({BallEventAggregator? aggregator})
      : _aggregator = aggregator ?? BallEventAggregator();

  final BallEventAggregator _aggregator;

  List<TeamLeaderboardEntry> build({
    required String teamId,
    required List<MatchModel> matches,
    required List<PlayerModel> squad,
    required TeamLeaderboardCategory category,
    Map<String, List<BallEventModel>> eventsByMatch = const {},
    int limit = 50,
  }) {
    final squadIds = {for (final p in squad) p.id};
    final byId = <String, _PlayerAgg>{};

    void ensure(String id, String name, {String? photo, String role = ''}) {
      if (id.isEmpty) return;
      final existing = byId[id];
      if (existing != null) {
        if (name.isNotEmpty) existing.playerName = name;
        return;
      }
      final fromSquad = squad.where((p) => p.id == id).firstOrNull;
      byId[id] = _PlayerAgg(
        playerId: id,
        playerName: fromSquad != null
            ? (fromSquad.fullName.trim().isNotEmpty
                ? fromSquad.fullName
                : fromSquad.name)
            : name,
        photoUrl: fromSquad?.photoUrl ?? photo,
        role: fromSquad?.role ?? role,
      );
    }

    for (final p in squad) {
      ensure(
        p.id,
        p.fullName.trim().isNotEmpty ? p.fullName : p.name,
        photo: p.photoUrl,
        role: p.role,
      );
    }

    final completed = matches
        .where((m) => m.status == MatchStatus.completed)
        .toList(growable: false);

    var usedBallEvents = false;

    for (final match in completed) {
      final events = eventsByMatch[match.id] ?? const <BallEventModel>[];
      if (events.isNotEmpty) usedBallEvents = true;

      for (final lineupInnings in match.innings) {
        final projection = events.isEmpty
            ? null
            : _aggregator.projectInnings(
                match: match,
                lineupInnings: lineupInnings,
                allEvents: events,
              );
        final inn = projection?.innings ?? lineupInnings;
        final battingForTeam = inn.battingTeamId == teamId;
        final bowlingForTeam = inn.bowlingTeamId == teamId;
        final maidens = projection?.bowlerMaidens ?? const <String, int>{};
        final innEvents = projection?.events ??
            events
                .where((e) => e.inningsNumber == inn.inningsNumber)
                .toList(growable: false);

        if (battingForTeam) {
          for (final b in inn.batsmen) {
            ensure(b.playerId, b.playerName);
            final a = byId[b.playerId]!;
            if (a.matchIds.add(match.id)) a.matches++;
            a.runs += b.runs;
            a.balls += b.balls;
            a.fours += b.fours;
            a.sixes += b.sixes;
            if (b.isOut) {
              a.dismissals++;
            } else if (b.balls > 0 || b.runs > 0) {
              a.notOuts++;
            }
            if (b.runs > a.highScore) a.highScore = b.runs;
            if (b.runs >= 100) {
              a.hundreds++;
            } else if (b.runs >= 50) {
              a.fifties++;
            }
            if (b.runs >= 50) {
              if (a.fastestFiftyBalls == 0 || b.balls < a.fastestFiftyBalls) {
                a.fastestFiftyBalls = b.balls;
              }
            }
            if (b.runs >= 100) {
              if (a.fastestHundredBalls == 0 ||
                  b.balls < a.fastestHundredBalls) {
                a.fastestHundredBalls = b.balls;
              }
            }
          }
        }

        if (bowlingForTeam) {
          for (final bowler in inn.bowlers) {
            ensure(bowler.playerId, bowler.playerName);
            final a = byId[bowler.playerId]!;
            if (a.matchIds.add(match.id)) a.matches++;
            a.wickets += bowler.wickets;
            a.runsConceded += bowler.runsConceded;
            a.ballsBowled += bowler.oversBowledBalls;
            a.maidens += maidens[bowler.playerId] ?? 0;
            if (bowler.wickets >= 5) a.fiveWickets++;
            if (bowler.wickets > a.bestWickets ||
                (bowler.wickets == a.bestWickets &&
                    bowler.runsConceded < a.bestRunsConceded)) {
              a.bestWickets = bowler.wickets;
              a.bestRunsConceded = bowler.runsConceded;
            }
          }

          for (final e in innEvents) {
            if (!e.isLegalDelivery || e.runs != 0) continue;
            final bowlerId = e.bowlerId;
            if (bowlerId == null || bowlerId.isEmpty) continue;
            ensure(bowlerId, e.bowlerName ?? '');
            byId[bowlerId]!.dotBalls++;
          }

          if (innEvents.isNotEmpty) {
            _scanFielding(innEvents, byId, ensure);
          } else {
            for (final f in inn.fielders) {
              ensure(f.playerId, f.playerName);
              final a = byId[f.playerId]!;
              if (a.matchIds.add(match.id)) a.matches++;
              a.catches += f.catches;
              a.runOuts += f.runOuts;
              a.stumpings += f.stumpings;
            }
          }
        }
      }
    }

    // Career fielding when ball events are unavailable.
    if (!usedBallEvents) {
      for (final p in squad) {
        final a = byId[p.id];
        if (a == null) continue;
        a.catches += p.stats.catches;
        a.runOuts += p.stats.runOuts;
        a.stumpings += p.stats.stumpings;
      }
    }
    final players = byId.values
        .where((p) => squadIds.contains(p.playerId) || p.matches > 0)
        .toList();

    return _rank(players, category, limit);
  }

  /// Pair-based partnership leaderboard (both batters on one row).
  List<TeamPartnershipLeaderboardEntry> buildPartnerships({
    required String teamId,
    required List<MatchModel> matches,
    required List<PlayerModel> squad,
    required TeamLeaderboardCategory category,
    Map<String, List<BallEventModel>> eventsByMatch = const {},
    int limit = 50,
  }) {
    if (category.section != TeamLeaderboardSection.partnerships) {
      return const [];
    }

    final photoById = <String, String?>{
      for (final p in squad)
        if (p.photoUrl != null && p.photoUrl!.isNotEmpty) p.id: p.photoUrl,
    };

    final collected = <_RawPartnership>[];

    final completed = matches
        .where((m) => m.status == MatchStatus.completed)
        .toList(growable: false);

    for (final match in completed) {
      final events = eventsByMatch[match.id] ?? const <BallEventModel>[];
      final opponent = match.teamAId == teamId
          ? match.teamBName
          : match.teamAName;
      final matchLabel = [
        if (match.title.trim().isNotEmpty) match.title.trim(),
        if (opponent.trim().isNotEmpty) 'vs $opponent',
      ].join(' · ');

      for (final lineupInnings in match.innings) {
        if (lineupInnings.battingTeamId != teamId) continue;
        final projection = events.isEmpty
            ? null
            : _aggregator.projectInnings(
                match: match,
                lineupInnings: lineupInnings,
                allEvents: events,
              );
        final partnerships = _partnershipsForInnings(
          projection: projection,
          lineupInnings: lineupInnings,
          events: events,
        );
        for (var i = 0; i < partnerships.length; i++) {
          final p = partnerships[i];
          collected.add(
            _RawPartnership(
              runs: p.runs,
              balls: p.balls,
              wicketNumber: p.wicketNumber,
              indexInInnings: i,
              inningsPartnershipCount: partnerships.length,
              batterAId: p.batterAId,
              batterAName: p.batterAName,
              batterBId: p.batterBId,
              batterBName: p.batterBName,
              batterARuns: p.batterARuns,
              batterABalls: p.batterABalls,
              batterBRuns: p.batterBRuns,
              batterBBalls: p.batterBBalls,
              matchLabel: matchLabel,
            ),
          );
        }
      }
    }

    Iterable<_RawPartnership> filtered = collected;
    switch (category) {
      case TeamLeaderboardCategory.mostCenturyPartnerships:
        filtered = collected.where((p) => p.runs >= 100);
      case TeamLeaderboardCategory.mostFiftyPartnerships:
        filtered = collected.where((p) => p.runs >= 50);
      case TeamLeaderboardCategory.highestOpeningPartnership:
        filtered = collected.where((p) => p.indexInInnings == 0);
      case TeamLeaderboardCategory.highestLastWicketPartnership:
        filtered = collected.where(
          (p) =>
              p.inningsPartnershipCount <= 1 ||
              p.indexInInnings == p.inningsPartnershipCount - 1,
        );
      case TeamLeaderboardCategory.highestMiddleOrderPartnership:
        filtered = collected.where(
          (p) =>
              p.indexInInnings > 0 &&
              p.indexInInnings < p.inningsPartnershipCount - 1,
        );
      case TeamLeaderboardCategory.highestPartnership:
      default:
        filtered = collected;
    }

    final list = filtered.toList()
      ..sort((a, b) {
        final byRuns = b.runs.compareTo(a.runs);
        if (byRuns != 0) return byRuns;
        return a.balls.compareTo(b.balls);
      });

    final maxRuns = list.isEmpty ? 0 : list.first.runs;
    final out = <TeamPartnershipLeaderboardEntry>[];
    for (var i = 0; i < list.length && i < limit; i++) {
      final p = list[i];
      out.add(
        TeamPartnershipLeaderboardEntry(
          rank: i + 1,
          runs: p.runs,
          balls: p.balls,
          wicketNumber: p.wicketNumber,
          batterAId: p.batterAId,
          batterAName: p.batterAName,
          batterBId: p.batterBId,
          batterBName: p.batterBName,
          batterAPhotoUrl: photoById[p.batterAId],
          batterBPhotoUrl: photoById[p.batterBId],
          batterARuns: p.batterARuns,
          batterABalls: p.batterABalls,
          batterBRuns: p.batterBRuns,
          batterBBalls: p.batterBBalls,
          matchLabel: p.matchLabel,
          isHighest: p.runs == maxRuns && maxRuns > 0 && i == 0,
        ),
      );
    }
    return out;
  }

  List<_DetailPartnership> _partnershipsForInnings({
    required InningsDerivedProjection? projection,
    required InningsModel lineupInnings,
    required List<BallEventModel> events,
  }) {
    final innEvents = projection?.events ??
        events
            .where((e) => e.inningsNumber == lineupInnings.inningsNumber)
            .toList(growable: false);
    final closed = projection?.partnerships ?? lineupInnings.partnerships;

    if (innEvents.isEmpty && closed.isEmpty) return const [];

    if (closed.isNotEmpty && innEvents.isNotEmpty) {
      return _detailFromClosedWithContributions(closed, innEvents);
    }
    if (closed.isNotEmpty) {
      return [
        for (var i = 0; i < closed.length; i++)
          _DetailPartnership(
            wicketNumber: i + 1,
            runs: closed[i].runs,
            balls: closed[i].balls,
            batterAId: closed[i].batterAId,
            batterAName: closed[i].batterAName,
            batterBId: closed[i].batterBId,
            batterBName: closed[i].batterBName,
            batterARuns: 0,
            batterABalls: 0,
            batterBRuns: 0,
            batterBBalls: 0,
          ),
      ];
    }
    return const [];
  }

  List<_DetailPartnership> _detailFromClosedWithContributions(
    List<PartnershipRecord> closed,
    List<BallEventModel> events,
  ) {
    final result = <_DetailPartnership>[];
    final playerRuns = <String, int>{};
    final playerBalls = <String, int>{};
    var closedIndex = 0;
    var wicketNumber = 0;

    void flush(PartnershipRecord part) {
      wicketNumber++;
      result.add(
        _DetailPartnership(
          wicketNumber: wicketNumber,
          runs: part.runs,
          balls: part.balls,
          batterAId: part.batterAId,
          batterAName: part.batterAName,
          batterBId: part.batterBId,
          batterBName: part.batterBName,
          batterARuns: playerRuns[part.batterAId] ?? 0,
          batterABalls: playerBalls[part.batterAId] ?? 0,
          batterBRuns: playerRuns[part.batterBId] ?? 0,
          batterBBalls: playerBalls[part.batterBId] ?? 0,
        ),
      );
      playerRuns.clear();
      playerBalls.clear();
    }

    for (final e in events) {
      final striker = e.strikerId;
      if (striker != null && striker.isNotEmpty) {
        playerRuns[striker] = (playerRuns[striker] ?? 0) + e.batsmanRuns;
        if (e.countsAsBallFaced) {
          playerBalls[striker] = (playerBalls[striker] ?? 0) + 1;
        }
      }
      if (!e.isWicket) continue;
      if (closedIndex < closed.length) {
        final part = closed[closedIndex];
        if (part.runs > 0 || part.balls > 0) {
          flush(part);
        } else {
          playerRuns.clear();
          playerBalls.clear();
        }
        closedIndex++;
      }
    }

    while (closedIndex < closed.length) {
      final part = closed[closedIndex++];
      if (part.runs > 0 || part.balls > 0) flush(part);
    }

    return result;
  }

  void _scanFielding(
    List<BallEventModel> events,
    Map<String, _PlayerAgg> byId,
    void Function(String id, String name) ensure,
  ) {
    for (final e in events) {
      if (!e.isWicket) continue;
      final wt = e.wicketType;
      if (wt == WicketType.caught || wt == WicketType.caughtBehind) {
        final id = e.fielderId ?? e.primaryFielderId ?? '';
        if (id.isEmpty) continue;
        ensure(id, e.fielderName ?? e.primaryFielderName ?? '');
        byId[id]!.catches++;
      } else if (wt == WicketType.caughtAndBowled) {
        final id = e.bowlerId ?? '';
        if (id.isEmpty) continue;
        ensure(id, e.bowlerName ?? '');
        byId[id]!.catches++;
      } else if (wt == WicketType.runOut) {
        final ids = <String>{
          if (e.fielderId != null) e.fielderId!,
          if (e.primaryFielderId != null) e.primaryFielderId!,
          if (e.secondaryFielderId != null) e.secondaryFielderId!,
          ...e.fielderIds,
        };
        for (final id in ids) {
          if (id.isEmpty) continue;
          ensure(id, '');
          byId[id]!.runOuts++;
        }
      } else if (wt == WicketType.stumped) {
        final id = e.wicketKeeperId ?? e.currentWicketKeeperId ?? '';
        if (id.isEmpty) continue;
        ensure(id, e.wicketKeeperName ?? e.currentWicketKeeperName ?? '');
        byId[id]!.stumpings++;
      }
    }
  }

  List<TeamLeaderboardEntry> _rank(
    List<_PlayerAgg> players,
    TeamLeaderboardCategory category,
    int limit,
  ) {
    num Function(_PlayerAgg) valueOf = (p) => 0;
    String Function(_PlayerAgg) labelOf = (p) => '—';
    bool Function(_PlayerAgg) include = (_) => false;
    var ascendingBetter = false;

    switch (category) {
      case TeamLeaderboardCategory.mostRuns:
        valueOf = (p) => p.runs;
        labelOf = (p) => '${p.runs}';
        include = (p) => p.runs > 0;
      case TeamLeaderboardCategory.highestScore:
        valueOf = (p) => p.highScore;
        labelOf = (p) => '${p.highScore}';
        include = (p) => p.highScore > 0;
      case TeamLeaderboardCategory.highestAverage:
        valueOf = (p) => p.average;
        labelOf = (p) => p.average.toStringAsFixed(1);
        include = (p) => p.balls >= 1 && p.runs > 0;
      case TeamLeaderboardCategory.bestStrikeRate:
        valueOf = (p) => p.strikeRate;
        labelOf = (p) => p.strikeRate.toStringAsFixed(1);
        include = (p) => p.balls >= 10;
      case TeamLeaderboardCategory.mostFifties:
        valueOf = (p) => p.fifties;
        labelOf = (p) => '${p.fifties}';
        include = (p) => p.fifties > 0;
      case TeamLeaderboardCategory.mostHundreds:
        valueOf = (p) => p.hundreds;
        labelOf = (p) => '${p.hundreds}';
        include = (p) => p.hundreds > 0;
      case TeamLeaderboardCategory.mostSixes:
        valueOf = (p) => p.sixes;
        labelOf = (p) => '${p.sixes}';
        include = (p) => p.sixes > 0;
      case TeamLeaderboardCategory.mostFours:
        valueOf = (p) => p.fours;
        labelOf = (p) => '${p.fours}';
        include = (p) => p.fours > 0;
      case TeamLeaderboardCategory.mostBallsFaced:
        valueOf = (p) => p.balls;
        labelOf = (p) => '${p.balls}';
        include = (p) => p.balls > 0;
      case TeamLeaderboardCategory.mostNotOuts:
        valueOf = (p) => p.notOuts;
        labelOf = (p) => '${p.notOuts}';
        include = (p) => p.notOuts > 0;
      case TeamLeaderboardCategory.fastestFifty:
        valueOf = (p) =>
            p.fastestFiftyBalls == 0 ? 9999 : p.fastestFiftyBalls;
        labelOf = (p) => '${p.fastestFiftyBalls} balls';
        include = (p) => p.fastestFiftyBalls > 0;
        ascendingBetter = true;
      case TeamLeaderboardCategory.fastestHundred:
        valueOf = (p) =>
            p.fastestHundredBalls == 0 ? 9999 : p.fastestHundredBalls;
        labelOf = (p) => '${p.fastestHundredBalls} balls';
        include = (p) => p.fastestHundredBalls > 0;
        ascendingBetter = true;
      case TeamLeaderboardCategory.mostWickets:
        valueOf = (p) => p.wickets;
        labelOf = (p) => '${p.wickets}';
        include = (p) => p.wickets > 0;
      case TeamLeaderboardCategory.bestBowlingFigures:
        valueOf = (p) => p.bestWickets * 1000 - p.bestRunsConceded;
        labelOf = (p) => p.bestWickets == 0
            ? '—'
            : '${p.bestWickets}/${p.bestRunsConceded}';
        include = (p) => p.bestWickets > 0;
      case TeamLeaderboardCategory.bestEconomy:
        valueOf = (p) => p.economy;
        labelOf = (p) => p.economy.toStringAsFixed(2);
        include = (p) => p.ballsBowled >= 12;
        ascendingBetter = true;
      case TeamLeaderboardCategory.bestBowlingStrikeRate:
        valueOf = (p) => p.bowlingSr;
        labelOf = (p) => p.bowlingSr == double.infinity
            ? '—'
            : p.bowlingSr.toStringAsFixed(1);
        include = (p) => p.wickets >= 2;
        ascendingBetter = true;
      case TeamLeaderboardCategory.mostMaidens:
        valueOf = (p) => p.maidens;
        labelOf = (p) => '${p.maidens}';
        include = (p) => p.maidens > 0;
      case TeamLeaderboardCategory.mostDotBalls:
        valueOf = (p) => p.dotBalls;
        labelOf = (p) => '${p.dotBalls}';
        include = (p) => p.dotBalls > 0;
      case TeamLeaderboardCategory.mostOversBowled:
        valueOf = (p) => p.oversBowled;
        labelOf = (p) => p.oversBowled.toStringAsFixed(1);
        include = (p) => p.ballsBowled > 0;
      case TeamLeaderboardCategory.mostFiveWicketHauls:
        valueOf = (p) => p.fiveWickets;
        labelOf = (p) => '${p.fiveWickets}';
        include = (p) => p.fiveWickets > 0;
      case TeamLeaderboardCategory.lowestAverage:
        valueOf = (p) => p.bowlingAvg;
        labelOf = (p) => p.bowlingAvg.toStringAsFixed(1);
        include = (p) => p.wickets >= 2;
        ascendingBetter = true;
      case TeamLeaderboardCategory.mostCatches:
        valueOf = (p) => p.catches;
        labelOf = (p) => '${p.catches}';
        include = (p) => p.catches > 0;
      case TeamLeaderboardCategory.mostRunOuts:
      case TeamLeaderboardCategory.mostDirectHits:
        valueOf = (p) => p.runOuts;
        labelOf = (p) => '${p.runOuts}';
        include = (p) => p.runOuts > 0;
      case TeamLeaderboardCategory.mostStumpings:
        valueOf = (p) => p.stumpings;
        labelOf = (p) => '${p.stumpings}';
        include = (p) => p.stumpings > 0;
      case TeamLeaderboardCategory.mostFieldingPoints:
        valueOf = (p) => p.fieldingPoints;
        labelOf = (p) => '${p.fieldingPoints}';
        include = (p) => p.fieldingPoints > 0;
      case TeamLeaderboardCategory.highestPartnership:
      case TeamLeaderboardCategory.mostCenturyPartnerships:
      case TeamLeaderboardCategory.mostFiftyPartnerships:
      case TeamLeaderboardCategory.highestOpeningPartnership:
      case TeamLeaderboardCategory.highestMiddleOrderPartnership:
      case TeamLeaderboardCategory.highestLastWicketPartnership:
        return const [];
    }

    final filtered = players.where(include).toList();
    filtered.sort((a, b) {
      final va = valueOf(a);
      final vb = valueOf(b);
      final cmp = ascendingBetter ? va.compareTo(vb) : vb.compareTo(va);
      if (cmp != 0) return cmp;
      return a.playerName.compareTo(b.playerName);
    });

    final out = <TeamLeaderboardEntry>[];
    for (var i = 0; i < filtered.length && i < limit; i++) {
      final p = filtered[i];
      out.add(
        TeamLeaderboardEntry(
          rank: i + 1,
          playerId: p.playerId,
          playerName: p.playerName,
          photoUrl: p.photoUrl,
          role: p.role,
          valueLabel: labelOf(p),
          matches: p.matches,
        ),
      );
    }
    return out;
  }
}

class _RawPartnership {
  const _RawPartnership({
    required this.runs,
    required this.balls,
    required this.wicketNumber,
    required this.indexInInnings,
    required this.inningsPartnershipCount,
    required this.batterAId,
    required this.batterAName,
    required this.batterBId,
    required this.batterBName,
    required this.batterARuns,
    required this.batterABalls,
    required this.batterBRuns,
    required this.batterBBalls,
    required this.matchLabel,
  });

  final int runs;
  final int balls;
  final int wicketNumber;
  final int indexInInnings;
  final int inningsPartnershipCount;
  final String batterAId;
  final String batterAName;
  final String batterBId;
  final String batterBName;
  final int batterARuns;
  final int batterABalls;
  final int batterBRuns;
  final int batterBBalls;
  final String matchLabel;
}

class _DetailPartnership {
  const _DetailPartnership({
    required this.wicketNumber,
    required this.runs,
    required this.balls,
    required this.batterAId,
    required this.batterAName,
    required this.batterBId,
    required this.batterBName,
    required this.batterARuns,
    required this.batterABalls,
    required this.batterBRuns,
    required this.batterBBalls,
  });

  final int wicketNumber;
  final int runs;
  final int balls;
  final String batterAId;
  final String batterAName;
  final String batterBId;
  final String batterBName;
  final int batterARuns;
  final int batterABalls;
  final int batterBRuns;
  final int batterBBalls;
}
