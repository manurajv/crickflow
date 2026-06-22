import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import '../../domain/services/player_cricket_profile_models.dart';
import '../../domain/services/player_cricket_profile_service.dart';
import '../../domain/services/player_typed_stats_service.dart';
import '../../domain/services/profile_match_filter_service.dart';
import 'my_player_provider.dart';
import 'my_player_stats_breakdown_provider.dart';
import 'providers.dart';

final playerCricketProfileServiceProvider =
    Provider((ref) => PlayerCricketProfileService());

/// Cached cricket profile snapshot for the signed-in player's linked doc.
final myCricketProfileProvider =
    FutureProvider<PlayerCricketProfileSnapshot?>((ref) async {
  final player = await ref.watch(myPlayerProvider.future);
  if (player == null) return null;

  final uid = ref.watch(authStateProvider).value?.uid;
  final matches = await ref.watch(matchesProvider.future);
  final teams = await ref.watch(allTeamsProvider.future);
  final userTeams = await ref.watch(teamsProvider.future);
  final userTeamIds = userTeams.map((t) => t.id).toSet();

  return ref.watch(playerCricketProfileServiceProvider).build(
        player: player,
        allMatches: matches,
        teams: teams,
        matchRepo: ref.watch(matchRepositoryProvider),
        authUid: uid,
        userTeamIds: userTeamIds,
      );
    });

/// Cached cricket profile for any player doc id (public profiles).
final playerCricketProfileByIdProvider =
    FutureProvider.family<PlayerCricketProfileSnapshot?, String>(
  (ref, playerDocId) async {
    final player =
        await ref.watch(playerRepositoryProvider).getPlayer(playerDocId);
    if (player == null) return null;

    final matches = await ref.watch(matchesProvider.future);
    final teams = await ref.watch(allTeamsProvider.future);

    return ref.watch(playerCricketProfileServiceProvider).build(
          player: player,
          allMatches: matches,
          teams: teams,
          matchRepo: ref.watch(matchRepositoryProvider),
          authUid: player.userId,
          userTeamIds: player.effectiveTeamIds.toSet(),
        );
  },
);

/// Stats breakdown for a specific player (reuses typed stats service).
final playerStatsBreakdownByIdProvider =
    FutureProvider.family<PlayerStatsBreakdown?, String>(
  (ref, playerDocId) async {
    final player =
        await ref.watch(playerRepositoryProvider).getPlayer(playerDocId);
    if (player == null) return null;

    final uid = player.userId ?? player.id;
    final matches = await ref.watch(matchesProvider.future);
    final userTeamIds = player.effectiveTeamIds.toSet();
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
            ballsPerOver:
                stored.matchesPlayed > 0 ? null : fromMatches.ballsPerOver,
            bowlingActualOvers: stored.matchesPlayed > 0
                ? null
                : fromMatches.bowlingActualOvers,
          ),
        );
      }
    }

    return PlayerStatsBreakdown(
      overall: player.stats,
      typedSections: typedSections,
    );
  },
);

final profileMatchFiltersProvider =
    StateProvider<ProfileMatchFilters>((ref) => const ProfileMatchFilters());

final profileInitialTabProvider = StateProvider<int>((ref) => 0);

PlayerStatsBreakdown buildProfileFilteredStatsBreakdown({
  required PlayerModel player,
  required List<MatchModel> participatedMatches,
  required ProfileMatchFilters filters,
  required PlayerTypedStatsService service,
}) {
  final filtered = filterProfileMatches(participatedMatches, filters);
  final completed =
      filtered.where((m) => m.status == MatchStatus.completed).toList();
  final uid = player.userId ?? player.id;
  final userTeamIds = player.effectiveTeamIds.toSet();

  final typedSections = <PlayerStatsSection>[];
  for (final type in CricketBallType.values) {
    final fromMatches = service.aggregateDetailedForType(
      completedMatches: completed,
      playerId: player.id,
      ballType: type,
      authUid: uid,
      playerTeamId: player.teamId,
      userTeamIds: userTeamIds,
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

  final overallResult = service.aggregateOverallDetailed(
    completedMatches: completed,
    playerId: player.id,
    authUid: uid,
    playerTeamId: player.teamId,
    userTeamIds: userTeamIds,
  );

  return PlayerStatsBreakdown(
    overall: overallResult.stats,
    typedSections: typedSections,
  );
}

String cricketBallTypeLabel(CricketBallType type) => switch (type) {
      CricketBallType.leather => 'Leather',
      CricketBallType.tennis => 'Tennis',
      CricketBallType.indoor => 'Indoor',
    };
