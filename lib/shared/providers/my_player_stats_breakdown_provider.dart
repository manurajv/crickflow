import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import '../../data/repositories/match_repository.dart';
import '../../domain/services/player_typed_stats_service.dart';
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

  final ballEventsByMatchId = await loadBallEventsForMatches(
    matchRepository: ref.watch(matchRepositoryProvider),
    matches: completed,
  );

  final service = ref.watch(playerTypedStatsServiceProvider);
  final typedSections = <PlayerStatsSection>[];

  for (final type in CricketBallType.values) {
    final fromMatches = service.aggregateDetailedForType(
      completedMatches: completed,
      playerId: player.id,
      ballType: type,
      authUid: uid,
      playerTeamId: player.teamId,
      userTeamIds: userTeamIds,
      ballEventsByMatchId: ballEventsByMatchId,
    );

    if (fromMatches.stats.matchesPlayed > 0) {
      typedSections.add(
        PlayerStatsSection(
          title: cricketBallTypeLabel(type),
          stats: fromMatches.stats,
          ballsPerOver: fromMatches.ballsPerOver,
          bowlingActualOvers: fromMatches.bowlingActualOvers,
        ),
      );
    }
  }

  final overall = service.aggregateOverallDetailed(
    completedMatches: completed,
    playerId: player.id,
    authUid: uid,
    playerTeamId: player.teamId,
    userTeamIds: userTeamIds,
    ballEventsByMatchId: ballEventsByMatchId,
  );

  return PlayerStatsBreakdown(
    overall: overall.stats,
    typedSections: typedSections,
  );
});

/// Loads ball events for completed matches so fielding stats can be derived.
Future<Map<String, List<BallEventModel>>> loadBallEventsForMatches({
  required MatchRepository matchRepository,
  required List<MatchModel> matches,
  int batchSize = 15,
}) async {
  final completed =
      matches.where((m) => m.status == MatchStatus.completed).toList();
  if (completed.isEmpty) return const {};

  final out = <String, List<BallEventModel>>{};
  for (var i = 0; i < completed.length; i += batchSize) {
    final end = (i + batchSize).clamp(0, completed.length);
    final chunk = completed.sublist(i, end);
    final results = await Future.wait(
      chunk.map((m) async {
        try {
          final events = await matchRepository.getBallEvents(m.id);
          return MapEntry(m.id, events);
        } catch (_) {
          return MapEntry(m.id, const <BallEventModel>[]);
        }
      }),
    );
    for (final e in results) {
      if (e.value.isNotEmpty) out[e.key] = e.value;
    }
  }
  return out;
}
