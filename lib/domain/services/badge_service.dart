import '../../core/constants/enums.dart';
import '../../data/models/badge_model.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';

/// Generates badges and match hero from innings performance.
class BadgeService {
  List<BadgeModel> evaluateInningsBadges({
    required String matchId,
    required InningsModel innings,
    required Map<String, String> playerNames,
  }) {
    final badges = <BadgeModel>[];
    final now = DateTime.now();

    for (final batsman in innings.batsmen) {
      if (batsman.runs >= 100) {
        badges.add(_badge(
          'century_${batsman.playerId}',
          'Century!',
          BadgeType.batting,
          'Scored ${batsman.runs} runs',
          batsman.playerId,
          matchId,
          now,
        ));
      } else if (batsman.runs >= 50) {
        badges.add(_badge(
          'fifty_${batsman.playerId}',
          'Half Century',
          BadgeType.batting,
          'Scored ${batsman.runs} runs',
          batsman.playerId,
          matchId,
          now,
        ));
      }
    }

    for (final bowler in innings.bowlers) {
      if (bowler.wickets >= 5) {
        badges.add(_badge(
          'five_wickets_${bowler.playerId}',
          '5 Wicket Haul',
          BadgeType.bowling,
          'Took ${bowler.wickets} wickets',
          bowler.playerId,
          matchId,
          now,
        ));
      } else if (bowler.wickets >= 3) {
        badges.add(_badge(
          'three_wickets_${bowler.playerId}',
          '3 Wicket Haul',
          BadgeType.bowling,
          'Took ${bowler.wickets} wickets',
          bowler.playerId,
          matchId,
          now,
        ));
      }
    }

    return badges;
  }

  /// Picks the Man/Player of the Match used for the `matchHero` /
  /// `playerOfMatchId` fields (and therefore the MoM badges).
  ///
  /// Rule: when the match has a winner, only players of the winning team are
  /// eligible (the losing side's best is "Fighter of the Match" in the MVP
  /// tab). Ties / no-results consider both teams.
  MatchHeroModel? pickMatchHero(MatchModel match, {String? winnerTeamId}) {
    final winner = decidedWinnerTeamId(match, winnerTeamId: winnerTeamId);
    bool eligible(String teamId) => winner == null || teamId == winner;

    var bestRuns = 0;
    String? heroId;
    String heroName = '';
    String reason = '';

    for (final innings in match.innings) {
      if (eligible(innings.battingTeamId)) {
        for (final b in innings.batsmen) {
          if (b.runs > bestRuns) {
            bestRuns = b.runs;
            heroId = b.playerId;
            heroName = b.playerName;
            reason = 'Top scorer with $bestRuns runs';
          }
        }
      }
      if (eligible(innings.bowlingTeamId)) {
        for (final bowler in innings.bowlers) {
          if (bowler.wickets >= 3 && bowler.wickets * 25 > bestRuns) {
            heroId = bowler.playerId;
            heroName = bowler.playerName;
            reason = 'Match-winning ${bowler.wickets} wicket haul';
            bestRuns = bowler.wickets * 25;
          }
        }
      }
    }

    if (heroId == null) return null;
    return MatchHeroModel(
      playerId: heroId,
      playerName: heroName,
      reason: reason,
    );
  }

  /// The winning team id when the result is decided between the two sides.
  static String? decidedWinnerTeamId(MatchModel match, {String? winnerTeamId}) {
    final w = (winnerTeamId ?? match.winnerTeamId)?.trim();
    if (w == null || w.isEmpty) return null;
    if (w != match.teamAId && w != match.teamBId) return null;
    return w;
  }

  /// Team ids [playerId] played for in [match] (from innings cards).
  static Set<String> playerTeamIds(MatchModel match, String playerId) {
    final teams = <String?>{};
    for (final inn in match.innings) {
      if (inn.batsmen.any((b) => b.playerId == playerId)) {
        teams.add(inn.battingTeamId);
      }
      if (inn.bowlers.any((b) => b.playerId == playerId)) {
        teams.add(inn.bowlingTeamId);
      }
    }
    final setup = match.setup;
    if (setup != null) {
      if (setup.teamAPlayingPlayers.any((p) => p.id == playerId)) {
        teams.add(match.teamAId);
      }
      if (setup.teamBPlayingPlayers.any((p) => p.id == playerId)) {
        teams.add(match.teamBId);
      }
    }
    return teams.whereType<String>().where((t) => t.isNotEmpty).toSet();
  }

  /// Whether [playerId] is a valid Man of the Match for [match]: it must be
  /// the stored POTM and, for decided matches, on the winning team.
  static bool isEligibleManOfTheMatch(MatchModel match, String playerId) {
    if (match.playerOfMatchId != playerId) return false;
    final winner = decidedWinnerTeamId(match);
    if (winner == null) return true;
    final teams = playerTeamIds(match, playerId);
    if (teams.isEmpty) return true; // No card data; trust the stored value.
    return teams.contains(winner);
  }

  BadgeModel _badge(
    String id,
    String title,
    BadgeType type,
    String description,
    String playerId,
    String matchId,
    DateTime earnedAt,
  ) {
    return BadgeModel(
      id: id,
      title: title,
      type: type,
      description: description,
      playerId: playerId,
      matchId: matchId,
      earnedAt: earnedAt,
    );
  }
}
