import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../shared/providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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

    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      if (context.mounted) context.go('/login');
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      final message = e.code == 'requires-recent-login'
          ? 'For security, sign out, sign in again, then retry delete.'
          : e.message ?? e.code;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () => context.push('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Match alerts & updates'),
            onTap: () => context.push('/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Offline Sync'),
            subtitle: const Text('Firestore persistence enabled'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('Hosted on crickflow-b06bc.web.app'),
            onTap: () async {
              final uri = DeepLinkUtils.privacyPolicyUri();
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open $uri')),
                  );
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out'),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account'),
            subtitle: const Text('Remove profile and sign-in'),
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion} (${AppConstants.appBuildNumber})',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
