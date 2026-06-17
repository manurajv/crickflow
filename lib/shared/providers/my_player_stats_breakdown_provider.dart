import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../data/models/player_model.dart';
import '../../domain/services/player_typed_stats_service.dart';
import '../../features/my_cricket/my_cricket_filters.dart';
import 'my_player_provider.dart';
import 'providers.dart';

class PlayerStatsSection {
  const PlayerStatsSection({
    required this.title,
    required this.stats,
    this.isOverall = false,
    this.ballsPerOver,
    this.bowlingActualOvers,
  });

  final String title;
  final PlayerStatsModel stats;
  final bool isOverall;
  /// When set, used for bowling overs/economy display for this section.
  final int? ballsPerOver;
  final double? bowlingActualOvers;
}

class PlayerStatsBreakdown {
  const PlayerStatsBreakdown({
    required this.overall,
    required this.typedSections,
  });

  final PlayerStatsModel overall;
  final List<PlayerStatsSection> typedSections;
}

final playerTypedStatsServiceProvider =
    Provider((ref) => const PlayerTypedStatsService());

final myPlayerStatsBreakdownProvider =
    FutureProvider<PlayerStatsBreakdown?>((ref) async {
  final player = await ref.watch(myPlayerProvider.future);
  if (player == null) return null;

  final uid = ref.watch(authStateProvider).value?.uid ?? player.id;
  final matches = await ref.watch(matchesProvider.future);
  final userTeams = await ref.watch(teamsProvider.future);
  final userTeamIds = userTeams.map((t) => t.id).toSet();

  final completed = matches
      .where((m) => m.status == MatchStatus.completed)
      .toList();

  final service = ref.watch(playerTypedStatsServiceProvider);
  final typedSections = <PlayerStatsSection>[];

  for (final type in CricketBallType.values) {
    final stored = player.statsForBallType(type);
    final fromMatches = service.aggregateDetailedForType(
      completedMatches: completed,
      playerId: player.id,
      ballType: type,
      authUid: uid,
      playerTeamId: player.teamId,
      userTeamIds: userTeamIds,
    );

    final stats =
        stored.matchesPlayed > 0 ? stored : fromMatches.stats;
    if (stats.matchesPlayed > 0) {
      typedSections.add(
        PlayerStatsSection(
          title: cricketBallTypeLabel(type),
          stats: stats,
          ballsPerOver: stored.matchesPlayed > 0 ? null : fromMatches.ballsPerOver,
          bowlingActualOvers:
              stored.matchesPlayed > 0 ? null : fromMatches.bowlingActualOvers,
        ),
      );
    }
  }

  return PlayerStatsBreakdown(
    overall: player.stats,
    typedSections: typedSections,
  );
});
