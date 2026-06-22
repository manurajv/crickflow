import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import 'widgets/player_profile_body.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final profileAsync = ref.watch(currentUserProfileProvider);

    if (uid == null) {
      final cf = context.cf;
      return ShellTabScaffold(
        title: const Text('Profile'),
        body: Center(
          child: Padding(
            padding: AppDimens.listPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 64, color: cf.textMuted),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  'Sign in to manage your profile',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Browse matches and scorecards without an account. '
                  'Sign in to follow players and build your cricket network.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceXl),
                CfButton(
                  label: 'Login',
                  isGold: true,
                  onPressed: () => context.push('/login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ShellTabScaffold(
      title: const Text('Profile'),
      body: profileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return PlayerProfileBody(
            user: user,
            isOwnProfile: true,
            viewerId: uid,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
