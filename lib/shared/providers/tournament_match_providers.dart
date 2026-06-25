import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../data/models/match_model.dart';
import '../../domain/scoring/match_lifecycle.dart';
import '../../data/models/tournament/tournament_group_model.dart';
import '../../data/models/tournament/tournament_round_model.dart';
import '../../domain/services/auto_fixture_generator_service.dart';
import 'tournament_providers.dart';

final autoFixtureGeneratorServiceProvider =
    Provider((ref) => const AutoFixtureGeneratorService());

enum TournamentMatchFilter { live, upcoming, completed }

final tournamentMatchesFilteredProvider = Provider.family<
    List<MatchModel>,
    ({String tournamentId, TournamentMatchFilter filter})>((ref, params) {
  final matches =
      ref.watch(tournamentMatchesProvider(params.tournamentId)).valueOrNull ??
          [];

  bool isLive(MatchModel m) => MatchLifecycle.isEffectivelyLive(m);

  bool isUpcoming(MatchModel m) {
    final status = MatchLifecycle.effectiveStatus(m);
    return status == MatchStatus.scheduled ||
        status == MatchStatus.draft ||
        status == MatchStatus.tossCompleted;
  }

  bool isCompleted(MatchModel m) =>
      MatchLifecycle.effectiveStatus(m) == MatchStatus.completed;

  final filtered = switch (params.filter) {
    TournamentMatchFilter.live => matches.where(isLive).toList(),
    TournamentMatchFilter.upcoming => matches.where(isUpcoming).toList(),
    TournamentMatchFilter.completed => matches.where(isCompleted).toList(),
  };

  filtered.sort(
    (a, b) =>
        (a.scheduledAt ?? DateTime(0)).compareTo(b.scheduledAt ?? DateTime(0)),
  );
  return filtered;
});

final tournamentGroupByIdProvider = Provider.family<
    TournamentGroupModel?,
    ({String tournamentId, String? groupId})>((ref, params) {
  if (params.groupId == null || params.groupId!.isEmpty) return null;
  final groups =
      ref.watch(tournamentGroupsProvider(params.tournamentId)).valueOrNull ??
          [];
  return groups.where((g) => g.id == params.groupId).firstOrNull;
});

final tournamentRoundByIdProvider = Provider.family<
    TournamentRoundModel?,
    ({String tournamentId, String? roundId})>((ref, params) {
  if (params.roundId == null || params.roundId!.isEmpty) return null;
  final rounds =
      ref.watch(tournamentRoundsProvider(params.tournamentId)).valueOrNull ??
          [];
  return rounds.where((r) => r.id == params.roundId).firstOrNull;
});

final tournamentActiveRoundsProvider =
    Provider.family<List<TournamentRoundModel>, String>((ref, tournamentId) {
  final rounds =
      ref.watch(tournamentRoundsProvider(tournamentId)).valueOrNull ?? [];
  return rounds.where((r) => r.isActive && !r.isArchived).toList();
});

bool isDeletableUpcomingMatch(MatchStatus status) =>
    status == MatchStatus.draft ||
    status == MatchStatus.scheduled ||
    status == MatchStatus.tossCompleted;
