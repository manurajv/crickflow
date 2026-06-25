import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament/tournament_analytics_doc.dart';
import '../../data/repositories/tournament_analytics_repository.dart';
import '../../domain/services/tournament/tournament_analytics_engine.dart';
import '../../domain/services/tournament/tournament_analytics_models.dart';
import '../../domain/services/tournament/tournament_hero_ranking_engine.dart';
import '../../domain/services/tournament/tournament_leaderboard_engine.dart';
import '../../domain/services/tournament/tournament_leaderboard_models.dart';
import 'providers.dart';
import 'tournament_providers.dart';

final tournamentAnalyticsEngineProvider =
    Provider((ref) => TournamentAnalyticsEngine());

final tournamentAnalyticsRepositoryProvider =
    Provider((ref) => TournamentAnalyticsRepository(
          matchRepository: ref.watch(matchRepositoryProvider),
          tournamentRepository: ref.watch(tournamentRepositoryProvider),
          engine: ref.watch(tournamentAnalyticsEngineProvider),
        ));

final tournamentLeaderboardEngineProvider =
    Provider((ref) => TournamentLeaderboardEngine());

final tournamentHeroRankingEngineProvider =
    Provider((ref) => TournamentHeroRankingEngine());

/// Ball events for all scored tournament matches (refreshes on live scoring).
final tournamentBallEventsProvider =
    FutureProvider.family<Map<String, List<BallEventModel>>, String>(
        (ref, tournamentId) async {
  final matches =
      ref.watch(tournamentMatchesProvider(tournamentId)).valueOrNull ?? [];
  final repo = ref.watch(matchRepositoryProvider);
  final out = <String, List<BallEventModel>>{};

  for (final match in matches) {
    if (!_isScoredMatch(match)) continue;
    ref.watch(ballEventsProvider(match.id));
    try {
      final events = await repo.getBallEvents(match.id);
      if (events.isNotEmpty) out[match.id] = events;
    } catch (_) {}
  }
  return out;
});

bool _isScoredMatch(MatchModel match) =>
    match.status == MatchStatus.live ||
    match.status == MatchStatus.inningsBreak ||
    match.status == MatchStatus.completed ||
    match.status == MatchStatus.abandoned;

class TournamentLeaderboardParams {
  const TournamentLeaderboardParams({
    required this.tournamentId,
    this.scope = TournamentStatsScope.tournament,
    this.groupId,
    this.roundId,
    this.scopeLabel = 'Tournament',
  });

  final String tournamentId;
  final TournamentStatsScope scope;
  final String? groupId;
  final String? roundId;
  final String scopeLabel;

  @override
  bool operator ==(Object other) =>
      other is TournamentLeaderboardParams &&
      other.tournamentId == tournamentId &&
      other.scope == scope &&
      other.groupId == groupId &&
      other.roundId == roundId;

  @override
  int get hashCode => Object.hash(tournamentId, scope, groupId, roundId);
}

final tournamentLeaderboardProvider = FutureProvider.family<
    TournamentLeaderboardSnapshot,
    TournamentLeaderboardParams>((ref, params) async {
  final matches =
      ref.watch(tournamentMatchesProvider(params.tournamentId)).valueOrNull ??
          [];
  final events =
      await ref.watch(tournamentBallEventsProvider(params.tournamentId).future);

  return ref.watch(tournamentLeaderboardEngineProvider).build(
        matches: matches,
        eventsByMatch: events,
        scope: params.scope,
        scopeLabel: params.scopeLabel,
        groupId: params.groupId,
        roundId: params.roundId,
      );
});

final tournamentHeroesProvider =
    FutureProvider.family<TournamentHeroesSnapshot, String>(
        (ref, tournamentId) async {
  final matches =
      ref.watch(tournamentMatchesProvider(tournamentId)).valueOrNull ?? [];
  final events =
      await ref.watch(tournamentBallEventsProvider(tournamentId).future);

  return ref.watch(tournamentHeroRankingEngineProvider).build(
        matches: matches,
        eventsByMatch: events,
      );
});

class TournamentAnalyticsParams extends Equatable {
  const TournamentAnalyticsParams({
    required this.tournamentId,
    this.filter = const TournamentAnalyticsFilter(),
  });

  final String tournamentId;
  final TournamentAnalyticsFilter filter;

  @override
  List<Object?> get props => [tournamentId, filter];
}

/// Live tournament analytics — recomputes when matches or ball events change.
final tournamentAnalyticsProvider = FutureProvider.family<
    TournamentAnalyticsSnapshot,
    TournamentAnalyticsParams>((ref, params) async {
  ref.watch(tournamentMatchesProvider(params.tournamentId));
  final matches =
      ref.watch(tournamentMatchesProvider(params.tournamentId)).valueOrNull ??
          [];
  final events =
      await ref.watch(tournamentBallEventsProvider(params.tournamentId).future);

  return ref.watch(tournamentAnalyticsEngineProvider).build(
        allMatches: matches,
        eventsByMatch: events,
        filter: params.filter,
      );
});

final tournamentAnalyticsDocProvider =
    StreamProvider.family<TournamentAnalyticsDoc?, String>(
        (ref, tournamentId) {
  return ref
      .watch(tournamentAnalyticsRepositoryProvider)
      .watchDoc(tournamentId);
});

/// Persists tournament analytics to Firestore (call after match completion).
Future<void> syncTournamentAnalyticsAfterMatch(
  WidgetRef ref,
  MatchModel match,
) async {
  final tournamentId = match.tournamentId;
  if (tournamentId == null || tournamentId.isEmpty) return;
  if (match.status != MatchStatus.completed &&
      match.status != MatchStatus.abandoned) {
    return;
  }
  try {
    await ref.read(tournamentAnalyticsRepositoryProvider).syncTournamentAnalytics(
          tournamentId,
        );
    ref.invalidate(tournamentAnalyticsProvider(
      TournamentAnalyticsParams(tournamentId: tournamentId),
    ));
    ref.invalidate(tournamentAnalyticsDocProvider(tournamentId));
  } catch (_) {}
}

