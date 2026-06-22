import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/repositories/match_repository.dart';
import '../../domain/services/player_advanced_analysis_service.dart';
import '../../domain/services/player_analysis_models.dart';
import '../../domain/services/profile_match_filter_service.dart';
import '../../features/my_cricket/my_cricket_filters.dart';
import 'player_cricket_profile_provider.dart';
import 'providers.dart';

final playerAdvancedAnalysisServiceProvider =
    Provider((ref) => PlayerAdvancedAnalysisService());

/// Advanced analytics for a player doc id, respecting profile match filters.
final playerAdvancedAnalysisProvider =
    FutureProvider.family<PlayerAdvancedAnalysisSnapshot, String>(
  (ref, playerDocId) async {
    final player =
        await ref.watch(playerRepositoryProvider).getPlayer(playerDocId);
    if (player == null) return PlayerAdvancedAnalysisSnapshot.empty;

    final matches = await ref.watch(matchesProvider.future);
    final filters = ref.watch(profileMatchFiltersProvider);
    final uid = player.userId ?? player.id;
    final userTeamIds = player.effectiveTeamIds.toSet();

    final participated = matches
        .where(
          (m) => userParticipatedInMatch(
            m,
            uid: uid,
            player: player,
            userTeamIds: userTeamIds,
          ),
        )
        .toList();

    final filtered = filterProfileMatches(participated, filters);
    final completed = filtered
        .where((m) => m.status == MatchStatus.completed)
        .toList()
      ..sort((a, b) {
        final da = a.completedAt ?? a.scheduledAt ?? DateTime(2000);
        final db = b.completedAt ?? b.scheduledAt ?? DateTime(2000);
        return db.compareTo(da);
      });

    final ballEventsByMatch = await _fetchBallEvents(
      ref.watch(matchRepositoryProvider),
      completed,
    );

    return ref.watch(playerAdvancedAnalysisServiceProvider).compute(
          player: player,
          completedMatches: completed,
          ballEventsByMatch: ballEventsByMatch,
        );
  },
);

Future<Map<String, List<BallEventModel>>> _fetchBallEvents(
  MatchRepository matchRepo,
  List<MatchModel> matches,
) async {
  final out = <String, List<BallEventModel>>{};
  for (final match in matches) {
    try {
      final events = await matchRepo.getBallEvents(match.id);
      if (events.isNotEmpty) out[match.id] = events;
    } catch (_) {}
  }
  return out;
}
