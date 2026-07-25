import '../../../core/constants/enums.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/team_model.dart';
import 'team_profile_models.dart';

/// Derives team profile statistics from [TeamStatsModel] + match innings.
class TeamProfileStatsService {
  const TeamProfileStatsService();

  TeamProfileStats compute({
    required TeamModel team,
    required List<MatchModel> teamMatches,
    int? tournamentWinCount,
  }) {
    final completed = teamMatches
        .where((m) => m.status == MatchStatus.completed)
        .toList(growable: false);

    final stored = team.stats;
    final matches = completed.isNotEmpty
        ? completed.length
        : stored.matchesPlayed;
    final wins = completed.isNotEmpty
        ? completed.where((m) => m.winnerTeamId == team.id).length
        : stored.matchesWon;
    final losses = completed.isNotEmpty
        ? completed
            .where(
              (m) =>
                  m.winnerTeamId != null &&
                  m.winnerTeamId!.isNotEmpty &&
                  m.winnerTeamId != team.id,
            )
            .length
        : stored.matchesLost;
    final ties = completed.isNotEmpty
        ? completed
            .where(
              (m) => m.winnerTeamId == null || m.winnerTeamId!.isEmpty,
            )
            .length
        : stored.matchesTied;

    final decided = wins + losses;
    final winPct = decided == 0 ? 0.0 : (wins * 100.0) / decided;

    final scores = <int>[];
    var totalRuns = 0;
    var totalWicketsTaken = 0;
    var totalBalls = 0;
    var fours = 0;
    var sixes = 0;
    var partnershipRuns = 0;
    var partnershipCount = 0;
    var highestChase = 0;
    var lowestDefence = 0;
    var homeWins = 0;
    var awayWins = 0;
    // Prefer explicit championship trophies when provided.
    var tournamentWins = tournamentWinCount ?? 0;
    final homeGround = _homeGroundFromTeam(team.location);

    for (final match in completed) {
      if (match.winnerTeamId == team.id) {
        if (_isPlayedAtHomeGround(match, homeGround)) {
          homeWins++;
        } else {
          awayWins++;
        }
      }

      for (final inn in match.innings) {
        if (inn.battingTeamId == team.id) {
          // Skip unplayed innings so a 0 placeholder doesn't wipe Lowest Score.
          final played = inn.status == InningsStatus.completed ||
              inn.legalBalls > 0 ||
              inn.totalWickets > 0 ||
              inn.batsmen.any((b) => b.balls > 0 || b.runs > 0);
          if (played) {
            scores.add(inn.totalRuns);
          }
          totalRuns += inn.totalRuns;
          totalBalls += inn.legalBalls;
          for (final b in inn.batsmen) {
            fours += b.fours;
            sixes += b.sixes;
          }
          for (final p in inn.partnerships) {
            partnershipRuns += p.runs;
            partnershipCount++;
          }
          final target = inn.targetRuns;
          if (target != null &&
              match.winnerTeamId == team.id &&
              inn.totalRuns >= target) {
            if (inn.totalRuns > highestChase) highestChase = inn.totalRuns;
          }
        }
        if (inn.bowlingTeamId == team.id) {
          totalWicketsTaken += inn.totalWickets;
          if (match.winnerTeamId == team.id &&
              inn.targetRuns == null &&
              scores.isNotEmpty) {
            // Defended first-innings total: opponent batting second.
          }
          if (match.winnerTeamId == team.id && inn.targetRuns != null) {
            // We bowled in chase — defence is our previous innings score.
          }
        }
      }

      // Successful defence: we batted first, won, and opponent chased.
      final teamFirst = match.innings
          .where((i) => i.battingTeamId == team.id)
          .toList();
      final oppChase = match.innings
          .where(
            (i) =>
                i.bowlingTeamId == team.id &&
                i.targetRuns != null &&
                i.targetRuns! > 0,
          )
          .toList();
      if (match.winnerTeamId == team.id &&
          teamFirst.isNotEmpty &&
          oppChase.isNotEmpty) {
        final defended = teamFirst.first.totalRuns;
        if (lowestDefence == 0 || defended < lowestDefence) {
          lowestDefence = defended;
        }
      }
    }

    scores.sort();
    final highest = scores.isEmpty ? 0 : scores.last;
    final lowest = scores.isEmpty ? 0 : scores.first;
    final avgScore =
        scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final avgRuns = matches == 0 ? 0.0 : totalRuns / matches;
    final avgWkts = matches == 0 ? 0.0 : totalWicketsTaken / matches;
    final rr = totalBalls == 0
        ? 0.0
        : CricketMath.runRate(totalRuns, totalBalls, 6);
    final avgPartnership =
        partnershipCount == 0 ? 0.0 : partnershipRuns / partnershipCount;

    final streak = _currentStreak(team.id, completed);
    final longest = _longestWinStreak(team.id, completed);

    return TeamProfileStats(
      matches: matches,
      wins: wins,
      losses: losses,
      ties: ties,
      winPct: winPct,
      currentStreak: streak,
      longestWinStreak: longest,
      averageScore: avgScore,
      highestScore: highest,
      lowestScore: lowest,
      hasInningsScores: scores.isNotEmpty,
      highestSuccessfulChase: highestChase,
      lowestSuccessfulDefence: lowestDefence,
      averageRuns: avgRuns,
      averageWickets: avgWkts,
      boundaries: fours + sixes,
      sixes: sixes,
      runRate: rr,
      averagePartnership: avgPartnership,
      homeWins: homeWins,
      awayWins: awayWins,
      tournamentWins: tournamentWins,
    );
  }

  /// Home ground is [LocationModel.placeName] (+ coords), not city/region.
  LocationModel _homeGroundFromTeam(LocationModel stored) {
    final name = stored.placeName.trim();
    if (name.isEmpty) return const LocationModel();
    return LocationModel(
      placeName: name,
      latitude: stored.latitude,
      longitude: stored.longitude,
    );
  }

  /// True when the match venue matches the team's Google home ground.
  bool _isPlayedAtHomeGround(MatchModel match, LocationModel homeGround) {
    final groundName = _normalizeVenueName(homeGround.placeName);
    final hasGroundName = groundName.isNotEmpty;
    final hasGroundCoords = homeGround.hasCoordinates;
    if (!hasGroundName && !hasGroundCoords) return false;

    if (hasGroundName) {
      final candidates = <String>{
        _normalizeVenueName(match.venue),
        _normalizeVenueName(match.location.placeName),
      }.where((n) => n.isNotEmpty);
      for (final name in candidates) {
        if (name == groundName) return true;
        // Allow slight naming differences ("SSC" vs "SSC Ground").
        if (name.length >= 4 &&
            groundName.length >= 4 &&
            (name.contains(groundName) || groundName.contains(name))) {
          return true;
        }
      }
    }

    if (hasGroundCoords && match.location.hasCoordinates) {
      return _coordsWithinHomeGround(
        homeGround.latitude!,
        homeGround.longitude!,
        match.location.latitude!,
        match.location.longitude!,
      );
    }
    return false;
  }

  String _normalizeVenueName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// ~350m box — good enough for same cricket ground / pin.
  bool _coordsWithinHomeGround(
    double homeLat,
    double homeLng,
    double matchLat,
    double matchLng,
  ) {
    const thresholdDegrees = 0.0035;
    return (homeLat - matchLat).abs() <= thresholdDegrees &&
        (homeLng - matchLng).abs() <= thresholdDegrees;
  }

  /// Chronological current streak: +N wins, -N losses.
  int _currentStreak(String teamId, List<MatchModel> completed) {
    if (completed.isEmpty) return 0;
    final sorted = [...completed]..sort((a, b) {
        final da = a.completedAt ?? a.scheduledAt ?? DateTime(1970);
        final db = b.completedAt ?? b.scheduledAt ?? DateTime(1970);
        return db.compareTo(da);
      });

    var streak = 0;
    bool? winning;
    for (final m in sorted) {
      final won = m.winnerTeamId == teamId;
      final lost = m.winnerTeamId != null &&
          m.winnerTeamId!.isNotEmpty &&
          m.winnerTeamId != teamId;
      if (!won && !lost) break;
      if (winning == null) {
        winning = won;
        streak = won ? 1 : -1;
        continue;
      }
      if (won && winning) {
        streak++;
      } else if (lost && !winning) {
        streak--;
      } else {
        break;
      }
    }
    return streak;
  }

  int _longestWinStreak(String teamId, List<MatchModel> completed) {
    if (completed.isEmpty) return 0;
    final sorted = [...completed]..sort((a, b) {
        final da = a.completedAt ?? a.scheduledAt ?? DateTime(1970);
        final db = b.completedAt ?? b.scheduledAt ?? DateTime(1970);
        return da.compareTo(db);
      });
    var best = 0;
    var cur = 0;
    for (final m in sorted) {
      if (m.winnerTeamId == teamId) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 0;
      }
    }
    return best;
  }
}
