import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/badge_gallery.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../../../shared/widgets/location_fields.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final profileAsync = ref.watch(currentUserProfileProvider);

    if (uid == null) {
      return ShellTabScaffold(
        title: const Text('Profile'),
        body: Center(
          child: Padding(
            padding: AppDimens.listPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline, size: 64, color: AppColors.gold),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  'Sign in to manage your profile',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Browse matches and scorecards without an account. '
                  'Sign in to score, join teams, and stream.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
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

          return ListView(
            padding: AppDimens.listPadding,
            children: [
              if (!user.onboardingCompleted)
                Card(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.gold),
                    title: const Text('Complete your player profile'),
                    subtitle: const Text(
                      'Required before scoring or managing teams',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/player-onboarding'),
                  ),
                ),
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryBlue,
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.effectiveName.isNotEmpty
                              ? user.effectiveName[0].toUpperCase()
                              : '?',
                          style: Theme.of(context).textTheme.displayLarge,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.effectiveName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (user.effectivePlayerIdDisplay.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    user.effectivePlayerIdDisplay,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
              if (user.displayName.isNotEmpty && user.displayName != user.name)
                Text(
                  '@${user.displayName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              Text(
                user.email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Chip(
                label: Text(user.role.name.toUpperCase()),
                backgroundColor: AppColors.gold.withValues(alpha: 0.2),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text('Location', style: Theme.of(context).textTheme.titleMedium),
              LocationFields(
                location: user.location,
                onChanged: (loc) async {
                  if (!user.onboardingCompleted) {
                    context.push('/player-onboarding');
                    return;
                  }
                  await ref
                      .read(userRepositoryProvider)
                      .updateUser(user.copyWith(location: loc));
                  ref.invalidate(currentUserProfileProvider);
                },
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text('Stats', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                title: const Text('Matches Played'),
                trailing: Text('${user.stats.matchesPlayed}'),
              ),
              ListTile(
                title: const Text('Matches Scored'),
                trailing: Text('${user.stats.matchesScored}'),
              ),
              Text('Badges', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppDimens.spaceSm),
              BadgeGallery(badgeIds: user.badgeIds),
              const SizedBox(height: AppDimens.spaceLg),
              Text('Explore', style: Theme.of(context).textTheme.titleMedium),
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('Analytics'),
                subtitle: const Text('Matches, teams, tournaments by location'),
                onTap: () => context.push('/analytics'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Players'),
                subtitle: const Text('Rosters and career stats'),
                onTap: () => context.push('/players'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit player profile'),
                onTap: () => context.push('/player-onboarding'),
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('CrickFlow PRO'),
                subtitle: const Text('Premium features (coming soon)'),
                onTap: () => context.push('/store'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: user.role == UserRole.viewer
                    ? UserRole.viewer
                    : UserRole.organizer,
                decoration: const InputDecoration(
                  labelText: 'App mode',
                  helperText:
                      'Member: score, stream, and join squads. Viewer: browse only.',
                ),
                items: const [
                  DropdownMenuItem(
                    value: UserRole.organizer,
                    child: Text('Member (score & play)'),
                  ),
                  DropdownMenuItem(
                    value: UserRole.viewer,
                    child: Text('Viewer (browse only)'),
                  ),
                ],
                onChanged: (role) async {
                  if (role == null) return;
                  await ref
                      .read(userRepositoryProvider)
                      .updateUser(user.copyWith(role: role));
                  if (role == UserRole.organizer) {
                    await ref
                        .read(playerRepositoryProvider)
                        .ensurePlayerProfileForUser(
                          userId: user.id,
                          displayName: user.displayName,
                          fullName: user.name,
                          photoUrl: user.photoUrl,
                          email: user.email,
                        );
                  }
                  ref.invalidate(currentUserProfileProvider);
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
