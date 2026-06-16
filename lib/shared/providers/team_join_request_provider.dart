import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/team_join_request_model.dart';
import 'providers.dart';

final userTeamJoinRequestProvider = StreamProvider.family<
    TeamJoinRequestModel?,
    ({String teamId, String userId})>((ref, params) {
  return ref
      .watch(teamJoinRequestRepositoryProvider)
      .watchRequest(params.teamId, params.userId);
});

final teamPendingJoinRequestsProvider =
    StreamProvider.family<List<TeamJoinRequestModel>, String>((ref, teamId) {
  return ref
      .watch(teamJoinRequestRepositoryProvider)
      .watchPendingForTeam(teamId);
});
