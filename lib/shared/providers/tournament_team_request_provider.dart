import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tournament/tournament_team_request_model.dart';
import '../../data/repositories/tournament_team_request_repository.dart';
import 'providers.dart';

final tournamentTeamRequestRepositoryProvider = Provider(
  (ref) => TournamentTeamRequestRepository(
    teamRepository: ref.watch(teamRepositoryProvider),
    tournamentRepository: ref.watch(tournamentRepositoryProvider),
    notificationRepository: ref.watch(notificationRepositoryProvider),
  ),
);

final tournamentTeamRequestsProvider =
    StreamProvider.family<List<TournamentTeamRequestModel>, String>(
  (ref, tournamentId) {
    return ref
        .watch(tournamentTeamRequestRepositoryProvider)
        .watchForTournament(tournamentId);
  },
);

final tournamentTeamRequestProvider = StreamProvider.family<
    TournamentTeamRequestModel?,
    ({String tournamentId, String teamId})>((ref, params) {
  return ref.watch(tournamentTeamRequestRepositoryProvider).watchRequest(
        tournamentId: params.tournamentId,
        teamId: params.teamId,
      );
});
