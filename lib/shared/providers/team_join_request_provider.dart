import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/team_join_request_model.dart';
import 'providers.dart';

final userTeamJoinRequestProvider = StreamProvider.autoDispose.family<
    TeamJoinRequestModel?,
    ({String teamId, String userId})>((ref, params) {
  return ref
      .watch(teamJoinRequestRepositoryProvider)
      .watchRequest(params.teamId, params.userId);
});

// autoDispose: a denied first listen (e.g. right after creating the team)
// must not stay cached for the rest of the session.
final teamPendingJoinRequestsProvider = StreamProvider.autoDispose
    .family<List<TeamJoinRequestModel>, String>((ref, teamId) {
  return ref
      .watch(teamJoinRequestRepositoryProvider)
      .watchPendingForTeam(teamId);
});
