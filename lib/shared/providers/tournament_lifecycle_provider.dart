import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/tournament/tournament_lifecycle_service.dart';
import 'providers.dart';
import 'tournament_providers.dart';

final tournamentLifecycleServiceProvider =
    Provider((ref) => const TournamentLifecycleService());

/// Watches tournament + matches and auto-syncs status (upcoming → live → completed).
///
/// Designed to be watched from the tournament dashboard — fires at most once
/// per status transition to avoid write loops.
final tournamentLifecycleAutoSyncProvider =
    FutureProvider.family<void, String>((ref, tournamentId) async {
  final tournament = ref.watch(tournamentProvider(tournamentId)).valueOrNull;
  final matches =
      ref.watch(tournamentMatchesProvider(tournamentId)).valueOrNull;

  if (tournament == null || matches == null) return;

  final service = ref.read(tournamentLifecycleServiceProvider);
  final newStatus = service.computeStatus(tournament, matches);
  if (newStatus == null) return;

  // Prevent repeated writes — only write if actually changing.
  if (newStatus == tournament.status) return;

  final repo = ref.read(tournamentRepositoryProvider);
  await repo.updateTournament(
    tournament.copyWith(status: newStatus),
  );
});
