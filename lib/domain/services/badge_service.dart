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

  MatchHeroModel? pickMatchHero(MatchModel match) {
    var bestRuns = 0;
    String? heroId;
    String heroName = '';
    String reason = '';

    for (final innings in match.innings) {
      for (final b in innings.batsmen) {
        if (b.runs > bestRuns) {
          bestRuns = b.runs;
          heroId = b.playerId;
          heroName = b.playerName;
          reason = 'Top scorer with $bestRuns runs';
        }
      }
      for (final bowler in innings.bowlers) {
        if (bowler.wickets >= 3 && bowler.wickets * 25 > bestRuns) {
          heroId = bowler.playerId;
          heroName = bowler.playerName;
          reason = 'Match-winning ${bowler.wickets} wicket haul';
          bestRuns = bowler.wickets * 25;
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
