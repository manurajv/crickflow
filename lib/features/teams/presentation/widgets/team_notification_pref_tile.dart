import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/providers.dart';

/// Per-team toggle for match notification eligibility.
class TeamNotificationPrefTile extends ConsumerWidget {
  const TeamNotificationPrefTile({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final enabledAsync = ref.watch(teamNotificationEnabledProvider(teamId));
    final enabled = enabledAsync.valueOrNull ?? true;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: const Text('Receive Team Match Notifications'),
      subtitle: const Text('Match start, wickets, results for this team'),
      value: enabled,
      onChanged: (v) async {
        await ref
            .read(notificationPreferencesRepositoryProvider)
            .setTeamNotificationsEnabled(
              userId: uid,
              teamId: teamId,
              enabled: v,
            );
      },
    );
  }
}
