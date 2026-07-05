import '../data/models/batter_intro_profile.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/player_model.dart';
import '../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../domain/services/player_typed_stats_service.dart'
    hide cricketBallTypeLabel;

/// Builds [BatterIntroProfile] for the stream batter intro card.
class BatterIntroProfileBuilder {
  BatterIntroProfileBuilder._();

  static BatterIntroProfile build({
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
      return BatterIntroProfile(
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
    final average = CricketMath.battingAverage(stats.runs, stats.dismissals);
    final strikeRate = CricketMath.strikeRate(stats.runs, stats.ballsFaced);
    final bestFromMatches =
        _bestBattingScore(completedMatches, player.id, ballType);
    final bestScore = stats.highScore > bestFromMatches
        ? stats.highScore
        : bestFromMatches;

    return BatterIntroProfile(
      playerId: player.id,
      playerName: name,
      photoUrl: player.photoUrl,
      teamName: teamName ?? '',
      teamLogoUrl: teamLogoUrl,
      formatLabel: formatLabel,
      battingStyle: player.battingStyle,
      matches: stats.matchesPlayed,
      average: average,
      strikeRate: strikeRate,
      bestScore: bestScore,
    );
  }

  static int _bestBattingScore(
    List<MatchModel> matches,
    String playerId,
    CricketBallType ballType,
  ) {
    var best = 0;
    for (final match in matches) {
      if (match.status != MatchStatus.completed) continue;
      if (match.rules.resolvedBallType != ballType) continue;
      for (final inn in match.innings) {
        for (final b in inn.batsmen) {
          if (b.playerId != playerId) continue;
          if (b.runs > best) best = b.runs;
        }
      }
    }
    return best;
  }
}
