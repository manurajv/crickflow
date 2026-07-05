import '../data/models/bowler_intro_profile.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../domain/services/player_typed_stats_service.dart'
    hide cricketBallTypeLabel;

/// Builds [BowlerIntroProfile] for the stream bowler intro card.
class BowlerIntroProfileBuilder {
  BowlerIntroProfileBuilder._();

  static BowlerIntroProfile build({
    required MatchModel match,
    required String playerId,
    required String fallbackName,
    PlayerModel? player,
    String? teamName,
    String? teamLogoUrl,
    List<MatchModel> completedMatches = const [],
  }) {
    final ballType = match.rules.resolvedBallType;
    final formatLabel = cricketBallTypeLabel(ballType);
    final name = player?.name.isNotEmpty == true ? player!.name : fallbackName;

    if (player == null || playerId.isEmpty) {
      return BowlerIntroProfile(
        playerId: playerId,
        playerName: name,
        teamName: teamName ?? '',
        teamLogoUrl: teamLogoUrl,
        formatLabel: formatLabel,
      );
    }

    final stored = player.statsForBallType(ballType);
    final typed = const PlayerTypedStatsService().aggregateDetailedForType(
      completedMatches: completedMatches,
      playerId: player.id,
      ballType: ballType,
      authUid: player.userId,
      playerTeamId: player.teamId,
      userTeamIds: player.effectiveTeamIds.toSet(),
    );
    final stats = stored.matchesPlayed > 0 ? stored : typed.stats;
    final average = CricketMath.bowlingAverage(stats.runsConceded, stats.wickets);
    final best = _bestBowlingFigures(completedMatches, player.id, ballType);

    return BowlerIntroProfile(
      playerId: player.id,
      playerName: name,
      photoUrl: player.photoUrl,
      teamName: teamName ?? '',
      teamLogoUrl: teamLogoUrl,
      formatLabel: formatLabel,
      bowlingStyle: player.bowlingStyle,
      matches: stats.matchesPlayed,
      wickets: stats.wickets,
      average: average,
      fiveWicketHauls: stats.fiveWickets,
      bestFigures: best,
    );
  }

  static String _bestBowlingFigures(
    List<MatchModel> matches,
    String playerId,
    CricketBallType ballType,
  ) {
    var bestWkts = 0;
    var bestRuns = 999;
    for (final match in matches) {
      if (match.status != MatchStatus.completed) continue;
      if (match.rules.resolvedBallType != ballType) continue;
      for (final inn in match.innings) {
        for (final b in inn.bowlers) {
          if (b.playerId != playerId || b.wickets <= 0) continue;
          if (b.wickets > bestWkts ||
              (b.wickets == bestWkts && b.runsConceded < bestRuns)) {
            bestWkts = b.wickets;
            bestRuns = b.runsConceded;
          }
        }
      }
    }
    if (bestWkts <= 0) return '—';
    return '$bestWkts/$bestRuns';
  }
}
