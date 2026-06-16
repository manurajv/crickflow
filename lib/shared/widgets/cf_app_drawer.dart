import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/auth/auth_gate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../data/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../providers/my_cricket_ui_provider.dart';
import '../providers/providers.dart';

/// Side navigation — ecosystem shortcuts (CrickFlow chrome, not reference clone).
class CfAppDrawer extends ConsumerWidget {
  const CfAppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final uid = ref.watch(authStateProvider).value?.uid;
    final isGuest = uid == null;
    final role = profile?.role ?? UserRole.organizer;
    final showOrganizerActions = isGuest || role != UserRole.viewer;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(profile: profile),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (showOrganizerActions) ...[
                    _DrawerTile(
                      icon: Icons.sports_cricket,
                      label: 'Start a match',
                      subtitle: 'Ball-by-ball scoring',
                      onTap: () {
                        Navigator.pop(context);
                        requireAuthVoid(
                          context: context,
                          ref: ref,
                          returnPath: '/match/create',
                          action: () async {
                            if (context.mounted) {
                              context.push('/match/create');
                            }
                          },
                        );
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.emoji_events_outlined,
                      label: 'Add tournament',
                      subtitle: 'League or knockout',
                      onTap: () {
                        Navigator.pop(context);
                        requireAuthVoid(
                          context: context,
                          ref: ref,
                          returnPath: '/tournaments',
                          action: () async {
                            if (context.mounted) context.push('/tournaments');
                          },
                        );
                      },
                    ),
                    _DrawerTile(
                      icon: Icons.videocam_outlined,
                      label: 'Go live',
                      subtitle: 'From Match Center stream tab',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Open a match → Summary → Go Live',
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                  ],
                  _DrawerTile(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    onTap: () => _goTab(context, 0),
                  ),
                  _DrawerTile(
                    icon: Icons.sports_cricket_outlined,
                    label: 'My matches',
                    onTap: () => _goTab(context, 2),
                  ),
                  _DrawerTile(
                    icon: Icons.analytics_outlined,
                    label: 'My performance',
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(myCricketInitialTabProvider.notifier).state = 3;
                      context.go('/matches');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.groups_outlined,
                    label: 'Teams',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/teams');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.person_outline,
                    label: 'Players',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/players');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.sports_esports_outlined,
                    label: 'Fantasy cricket',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/fantasy');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.explore_outlined,
                    label: 'Discover',
                    onTap: () => _goTab(context, 1),
                  ),
                  _DrawerTile(
                    icon: Icons.forum_outlined,
                    label: 'Community',
                    onTap: () => _goTab(context, 3),
                  ),
                  const Divider(height: 1),
                  _DrawerTile(
                    icon: Icons.workspace_premium_outlined,
                    label: 'CrickFlow PRO',
                    subtitle: 'Premium tools',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/store');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () {
                      Navigator.pop(context);
                      requireAuthVoid(
                        context: context,
                        ref: ref,
                        returnPath: '/notifications',
                        action: () async {
                          if (context.mounted) context.push('/notifications');
                        },
                      );
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.share_outlined,
                    label: 'Share the app',
                    onTap: () {
                      Navigator.pop(context);
                      Share.share(
                        'Score and stream cricket with ${AppConstants.appName}!',
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: AppDimens.cardPadding,
              child: Text(
                '${AppConstants.appName} v${AppConstants.appVersion}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goTab(BuildContext context, int index) {
    Navigator.pop(context);
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/discover');
      case 2:
        context.go('/matches');
      case 3:
        context.go('/community');
      case 4:
        context.go('/profile');
    }
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({this.profile});

  final UserModel? profile;

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName ?? 'Guest';
    final email = profile?.email ?? '';
    final role = profile?.role.name ?? 'member';

    return Material(
      color: AppColors.chromeBackground,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          context.push('/profile');
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceLg,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryBlue,
                backgroundImage: profile?.photoUrl != null
                    ? NetworkImage(profile!.photoUrl!)
                    : null,
                child: profile?.photoUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        role == UserRole.viewer.name ? 'Viewer' : 'Member',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: subtitle == null,
      leading: Icon(icon, color: AppColors.primaryBlueLight, size: 22),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      subtitle: subtitle != null
          ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
          : null,
      onTap: onTap,
    );
  }
}
