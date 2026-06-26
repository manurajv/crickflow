import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/notification_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';

/// Accept/reject team invitation notifications.
class TeamNotificationActions {
  TeamNotificationActions._();

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
    final teamId = notification.teamId;
    final requestId = notification.requestId ?? uid;
    if (uid == null ||
        teamId == null ||
        teamId.isEmpty ||
        requestId == null ||
        requestId.isEmpty) {
      throw StateError('Missing team or invitation details');
    }

    final team = await ref.read(teamRepositoryProvider).getTeam(teamId);
    if (team == null) throw StateError('Team not found');

    final request = await ref
        .read(teamJoinRequestRepositoryProvider)
        .getRequest(teamId, requestId);
    if (request == null || !request.isPending) {
      throw StateError('Invitation is no longer pending');
    }

    final repo = ref.read(teamJoinRequestRepositoryProvider);
    if (accept) {
      await repo.acceptInvitation(
        team: team,
        request: request,
        playerUid: uid,
      );
      ref.invalidate(teamPlayersProvider(teamId));
    } else {
      await repo.rejectInvitation(
        team: team,
        request: request,
        playerUid: uid,
      );
    }
  }
}
