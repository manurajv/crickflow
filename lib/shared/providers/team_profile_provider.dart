import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/player_model.dart';
import '../../data/repositories/team_follow_repository.dart';
import '../../domain/services/player_cricket_profile_models.dart';
import '../../domain/services/profile_match_filter_service.dart';
import '../../domain/services/team_profile/team_leaderboard_service.dart';
import '../../domain/services/team_profile/team_profile_models.dart';
import '../../domain/services/team_profile/team_profile_stats_service.dart';
import '../../domain/services/team_profile/team_trophy_service.dart';
import 'providers.dart';
import 'team_players_provider.dart';

final teamFollowRepositoryProvider = Provider<TeamFollowRepository>((ref) {
  return TeamFollowRepository();
});

final isFollowingTeamProvider =
    StreamProvider.family<bool, ({String teamId, String userId})>((ref, key) {
  return ref.watch(teamFollowRepositoryProvider).watchIsFollowing(
        teamId: key.teamId,
        userId: key.userId,
      );
});

final teamFollowersCountProvider =
    StreamProvider.family<int, String>((ref, teamId) {
  return ref.watch(teamFollowRepositoryProvider).watchFollowersCount(teamId);
});

/// Optimistic delta applied to followers count for instant Follow UI feedback.
final teamFollowersOptimisticDeltaProvider =
    StateProvider.family<int, String>((ref, teamId) => 0);

final teamProfileMatchesProvider =
    Provider.family<AsyncValue<List<MatchModel>>, String>((ref, teamId) {
  final matchesAsync = ref.watch(matchesProvider);
  return matchesAsync.whenData((all) {
    final list = all
        .where((m) => m.teamAId == teamId || m.teamBId == teamId)
        .toList();
    list.sort((a, b) {
      final da = a.completedAt ?? a.scheduledAt ?? a.createdAt ?? DateTime(1970);
      final db = b.completedAt ?? b.scheduledAt ?? b.createdAt ?? DateTime(1970);
      return db.compareTo(da);
    });
    return list;
  });
});

/// Independent from player cricket profile filters.
final teamProfileMatchFiltersProvider =
    StateProvider<ProfileMatchFilters>((ref) => const ProfileMatchFilters());

/// Team matches after app-bar Filters (Matches / Leaderboard / Stats).
final teamProfileFilteredMatchesProvider =
    Provider.family<AsyncValue<List<MatchModel>>, String>((ref, teamId) {
  final matchesAsync = ref.watch(teamProfileMatchesProvider(teamId));
  final filters = ref.watch(teamProfileMatchFiltersProvider);
  return matchesAsync.whenData((m) => filterProfileMatches(m, filters));
});

/// Ball events for completed team matches (needed for fielding / partnerships / dots).
final teamProfileBallEventsProvider =
    FutureProvider.family<Map<String, List<BallEventModel>>, String>(
        (ref, teamId) async {
  final matchesAsync = ref.watch(teamProfileMatchesProvider(teamId));
  final matches = matchesAsync.valueOrNull ?? const <MatchModel>[];
  final repo = ref.watch(matchRepositoryProvider);
  final out = <String, List<BallEventModel>>{};

  for (final match in matches) {
    if (match.status != MatchStatus.completed &&
        match.status != MatchStatus.live &&
        match.status != MatchStatus.inningsBreak) {
      continue;
    }
    try {
      final events = await repo.getBallEvents(match.id);
      if (events.isNotEmpty) out[match.id] = events;
    } catch (_) {}
  }
  return out;
});

final teamProfileTrophiesProvider =
    Provider.family<List<TeamTrophy>, String>((ref, teamId) {
  final tournaments =
      ref.watch(tournamentsProvider).valueOrNull ?? const [];
  final matches =
      ref.watch(teamProfileMatchesProvider(teamId)).valueOrNull ?? const [];
  return const TeamTrophyService().compute(
    teamId: teamId,
    tournaments: tournaments,
    teamMatches: matches,
  );
});

final teamProfileStatsProvider =
    Provider.family<AsyncValue<TeamProfileStats>, String>((ref, teamId) {
  final teamAsync = ref.watch(teamByIdProvider(teamId));
  final matchesAsync = ref.watch(teamProfileMatchesProvider(teamId));
  final trophies = ref.watch(teamProfileTrophiesProvider(teamId));
  if (teamAsync.isLoading || matchesAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (teamAsync.hasError) {
    return AsyncValue.error(teamAsync.error!, teamAsync.stackTrace!);
  }
  if (matchesAsync.hasError) {
    return AsyncValue.error(matchesAsync.error!, matchesAsync.stackTrace!);
  }
  final team = teamAsync.valueOrNull;
  if (team == null) {
    return const AsyncValue.data(TeamProfileStats());
  }
  final stats = const TeamProfileStatsService().compute(
    team: team,
    teamMatches: matchesAsync.valueOrNull ?? const [],
    tournamentWinCount: trophies
        .where((t) => t.kind == TeamTrophyKind.tournamentWinner)
        .length,
  );
  return AsyncValue.data(stats);
});

/// Stats for the Stats tab — respects [teamProfileMatchFiltersProvider].
final teamProfileFilteredStatsProvider =
    Provider.family<AsyncValue<TeamProfileStats>, String>((ref, teamId) {
  final teamAsync = ref.watch(teamByIdProvider(teamId));
  final matchesAsync = ref.watch(teamProfileFilteredMatchesProvider(teamId));
  final trophies = ref.watch(teamProfileTrophiesProvider(teamId));
  if (teamAsync.isLoading || matchesAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (teamAsync.hasError) {
    return AsyncValue.error(teamAsync.error!, teamAsync.stackTrace!);
  }
  if (matchesAsync.hasError) {
    return AsyncValue.error(matchesAsync.error!, matchesAsync.stackTrace!);
  }
  final team = teamAsync.valueOrNull;
  if (team == null) {
    return const AsyncValue.data(TeamProfileStats());
  }
  final stats = const TeamProfileStatsService().compute(
    team: team,
    teamMatches: matchesAsync.valueOrNull ?? const [],
    tournamentWinCount: trophies
        .where((t) => t.kind == TeamTrophyKind.tournamentWinner)
        .length,
  );
  return AsyncValue.data(stats);
});

final teamProfileSnapshotProvider =
    Provider.family<AsyncValue<TeamProfileSnapshot>, String>((ref, teamId) {
  final teamAsync = ref.watch(teamByIdProvider(teamId));
  final playersAsync = ref.watch(teamPlayersProvider(teamId));
  final matchesAsync = ref.watch(teamProfileMatchesProvider(teamId));
  final statsAsync = ref.watch(teamProfileStatsProvider(teamId));
  final followersAsync = ref.watch(teamFollowersCountProvider(teamId));
  final trophies = ref.watch(teamProfileTrophiesProvider(teamId));
  final optimistic =
      ref.watch(teamFollowersOptimisticDeltaProvider(teamId));

  if (teamAsync.isLoading ||
      playersAsync.isLoading ||
      matchesAsync.isLoading ||
      statsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  for (final a in [teamAsync, playersAsync, matchesAsync, statsAsync]) {
    if (a.hasError) {
      return AsyncValue.error(a.error!, a.stackTrace!);
    }
  }

  final team = teamAsync.valueOrNull;
  if (team == null) {
    return AsyncValue.error('Team not found', StackTrace.current);
  }

  final players = playersAsync.valueOrNull ?? const <PlayerModel>[];
  PlayerModel? captain;
  PlayerModel? vc;
  for (final p in players) {
    if (team.captainId != null && p.id == team.captainId) captain = p;
    if (team.viceCaptainId != null && p.id == team.viceCaptainId) vc = p;
  }

  final rawFollowers = followersAsync.valueOrNull ?? 0;
  final followers = (rawFollowers + optimistic).clamp(0, 1 << 30);

  return AsyncValue.data(
    TeamProfileSnapshot(
      team: team,
      players: players,
      matches: matchesAsync.valueOrNull ?? const [],
      stats: statsAsync.valueOrNull ?? const TeamProfileStats(),
      captain: captain,
      viceCaptain: vc,
      trophies: trophies,
      followersCount: followers,
    ),
  );
});

typedef TeamLeaderboardKey = ({
  String teamId,
  TeamLeaderboardCategory category,
});

final teamLeaderboardProvider = FutureProvider.family<List<TeamLeaderboardEntry>,
    TeamLeaderboardKey>((ref, key) async {
  if (key.category.section == TeamLeaderboardSection.partnerships) {
    return const [];
  }
  final snap = ref.watch(teamProfileSnapshotProvider(key.teamId)).valueOrNull;
  if (snap == null) return const [];
  final filters = ref.watch(teamProfileMatchFiltersProvider);
  final matches = filterProfileMatches(snap.matches, filters);
  final events =
      await ref.watch(teamProfileBallEventsProvider(key.teamId).future);
  return TeamLeaderboardService().build(
    teamId: key.teamId,
    matches: matches,
    squad: snap.players,
    category: key.category,
    eventsByMatch: events,
  );
});

final teamPartnershipLeaderboardProvider = FutureProvider.family<
    List<TeamPartnershipLeaderboardEntry>,
    TeamLeaderboardKey>((ref, key) async {
  final snap = ref.watch(teamProfileSnapshotProvider(key.teamId)).valueOrNull;
  if (snap == null) return const [];
  final filters = ref.watch(teamProfileMatchFiltersProvider);
  final matches = filterProfileMatches(snap.matches, filters);
  final events =
      await ref.watch(teamProfileBallEventsProvider(key.teamId).future);
  return TeamLeaderboardService().buildPartnerships(
    teamId: key.teamId,
    matches: matches,
    squad: snap.players,
    category: key.category,
    eventsByMatch: events,
  );
});
