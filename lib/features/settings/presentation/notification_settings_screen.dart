import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../shared/providers/notification_provider.dart';
import '../../../shared/providers/providers.dart';

/// Notification preference toggles for team and follower alerts.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: const Center(child: Text('Sign in to manage notifications')),
      );
    }

    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: prefsAsync.when(
        data: (prefs) => ListView(
          children: [
            const ListTile(
              title: Text('Match notifications'),
              subtitle: Text(
                'Control alerts for your teams and followed matches.',
              ),
            ),
            SwitchListTile(
              title: const Text('Receive Team Match Notifications'),
              subtitle: const Text(
                'Match start, wickets, results, and team updates for your teams',
              ),
              value: prefs.receiveTeamMatchNotifications,
              onChanged: (v) async {
                await ref
                    .read(notificationPreferencesRepositoryProvider)
                    .setReceiveTeamMatchNotifications(uid, v);
              },
            ),
            SwitchListTile(
              title: const Text('Follow Match Notifications'),
              subtitle: const Text(
                'Alerts for matches you follow as a spectator',
              ),
              value: prefs.receiveFollowerNotifications,
              onChanged: (v) async {
                await ref
                    .read(notificationPreferencesRepositoryProvider)
                    .setReceiveFollowerNotifications(uid, v);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notification inbox'),
              subtitle: const Text('View recent alerts'),
              onTap: () => context.push('/notifications'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
