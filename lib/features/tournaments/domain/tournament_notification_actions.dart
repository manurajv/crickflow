import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/notification_model.dart';
import '../../../data/models/tournament/tournament_team_request_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_team_request_provider.dart';

/// Handles accept/reject actions from tournament team notifications.
class TournamentNotificationActions {
  TournamentNotificationActions._();

  static Future<void> accept(
    WidgetRef ref, {
    required NotificationModel notification,
  }) async {
    await _respond(ref, notification: notification, accept: true);
  }

  static Future<void> reject(
    WidgetRef ref, {
    required NotificationModel notification,
  }) async {
    await _respond(ref, notification: notification, accept: false);
  }

  static Future<void> _respond(
    WidgetRef ref, {
    required NotificationModel notification,
    required bool accept,
  }) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final tournamentId = notification.tournamentId;
    final teamId = notification.teamId;
    if (tournamentId == null ||
        tournamentId.isEmpty ||
        teamId == null ||
        teamId.isEmpty) {
      throw StateError('Missing tournament or team on notification');
    }

    final repo = ref.read(tournamentTeamRequestRepositoryProvider);
    final request = await repo.getRequest(
      tournamentId: tournamentId,
      teamId: teamId,
    );
    if (request == null || !request.isPending) {
      throw StateError('Request is no longer pending');
    }

    final tournament = await ref.read(tournamentRepositoryProvider).getTournament(
          tournamentId,
        );
    final team = await ref.read(teamRepositoryProvider).getTeam(teamId);
    if (tournament == null || team == null) {
      throw StateError('Tournament or team not found');
    }

    if (request.requestType == TournamentTeamRequestType.invitation) {
      if (accept) {
        await repo.acceptInvitation(
          request: request,
          team: team,
          resolverUserId: uid,
        );
      } else {
        await repo.rejectInvitation(
          request: request,
          team: team,
          resolverUserId: uid,
        );
      }
      return;
    }

    if (accept) {
      await repo.approveJoinRequest(
        request: request,
        tournament: tournament,
        resolverUserId: uid,
      );
    } else {
      await repo.rejectJoinRequest(
        request: request,
        tournament: tournament,
        resolverUserId: uid,
      );
    }
  }
}
