import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../domain/scoring/match_lifecycle.dart';
import 'providers.dart';

final _repairQueued = <String>{};

/// Persists `completed` for matches left at innings break after the final innings.
Future<void> repairStuckMatchIfNeeded(Ref ref, MatchModel match) async {
  if (!MatchLifecycle.needsFinalization(match)) return;
  if (!_repairQueued.add(match.id)) return;

  try {
    final completed =
        await ref.read(matchRepositoryProvider).finalizeMatchIfReady(match.id);
    if (completed != null &&
        completed.status == MatchStatus.completed &&
        completed.tournamentId != null &&
        completed.tournamentId!.isNotEmpty) {
      await ref
          .read(tournamentRepositoryProvider)
          .advanceKnockoutFromMatch(completed);
    }
  } catch (_) {
    _repairQueued.remove(match.id);
  }
}

void scheduleStuckMatchRepairs(Ref ref, Iterable<MatchModel> matches) {
  for (final match in matches) {
    if (MatchLifecycle.needsFinalization(match)) {
      Future.microtask(() => repairStuckMatchIfNeeded(ref, match));
    }
  }
}
