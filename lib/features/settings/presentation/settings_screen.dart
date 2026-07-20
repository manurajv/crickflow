import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/offline_sync_provider.dart';
import '../../../shared/providers/providers.dart';
import 'widgets/appearance_theme_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to score matches, manage teams, '
          'or change account settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go('/home');
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your CrickFlow profile, player link, and notifications. '
          'Matches and teams you created may remain for other users.\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Deleting account…')),
            ],
          ),
        ),
      ),
    );

    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.go('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = e.code == 'requires-recent-login'
          ? 'For security, sign out, sign in again, then retry delete.'
          : e.message ?? e.code;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(authStateProvider).value?.uid != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const AppearanceThemeSection(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('View and manage your account'),
            onTap: () => context.go('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Match alerts & updates'),
            onTap: () => requireAuthVoid(
              context: context,
              ref: ref,
              returnPath: '/notifications',
              action: () async {
                if (context.mounted) context.push('/notifications');
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Notification Settings'),
            subtitle: const Text('Team and follow preferences'),
            onTap: () => requireAuthVoid(
              context: context,
              ref: ref,
              returnPath: '/settings/notifications',
              action: () async {
                if (context.mounted) {
                  context.push('/settings/notifications');
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Offline Sync'),
            subtitle: const Text('Local-first scoring with cloud sync'),
            onTap: () {
              final pending =
                  ref.read(matchLocalStoreProvider).totalPendingCount();
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Offline sync'),
                  content: Text(
                    'CrickFlow saves every scoring action on your device first, '
                    'then syncs to Firebase when you are online.\n\n'
                    'Pending actions: $pending\n\n'
                    'You can complete an entire match without internet. '
                    'Local data is authoritative until sync completes.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How CrickFlow handles your data'),
            onTap: () => context.push('/legal/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            subtitle: const Text('Rules for using CrickFlow'),
            onTap: () => context.push('/legal/terms'),
          ),
          if (isSignedIn) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out'),
              onTap: () => _confirmSignOut(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account'),
              subtitle: const Text('Remove profile and sign-in'),
              onTap: () => _confirmDeleteAccount(context, ref),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceLg,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: Column(
              children: [
                Text(
                  '${AppConstants.appName} v${AppConstants.appVersion} (${AppConstants.appBuildNumber})',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Powered by ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.cf.textMuted,
                          ),
                    ),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse('https://mavixas.com');
                        if (!await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        )) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open $uri')),
                            );
                          }
                        }
                      },
                      child: Text(
                        'Mavixas',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.cf.link,
                              decoration: TextDecoration.underline,
                              decorationColor: context.cf.link,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
