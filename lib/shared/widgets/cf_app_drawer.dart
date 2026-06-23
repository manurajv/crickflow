import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/auth/auth_gate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../core/utils/cf_player_id_format.dart';
import '../../data/models/user_model.dart';
import '../providers/my_cricket_ui_provider.dart';
import '../providers/providers.dart';

/// Side navigation aligned with shell tabs and cricket shortcuts.
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
      backgroundColor: context.cf.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(
              profile: profile,
              isGuest: isGuest,
              onOpenProfile: () => _goShell(context, '/profile'),
              onSignIn: () {
                Navigator.pop(context);
                context.push('/login');
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                children: [
                  if (showOrganizerActions) ...[
                    const _DrawerSectionHeader('Quick actions'),
                    _DrawerTile(
                      icon: Icons.play_circle_outline,
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
                          returnPath: '/tournaments/create',
                          action: () async {
                            if (context.mounted) {
                              context.push('/tournaments/create');
                            }
                          },
                        );
                      },
                    ),
                  ],
                  const _DrawerSectionHeader('My cricket'),
                  _DrawerTile(
                    icon: Icons.format_list_bulleted_outlined,
                    label: 'Matches',
                    onTap: () => _goMyCricket(context, ref, tab: 0),
                  ),
                  _DrawerTile(
                    icon: Icons.emoji_events_outlined,
                    label: 'Tournaments',
                    onTap: () => _goMyCricket(context, ref, tab: 1),
                  ),
                  _DrawerTile(
                    icon: Icons.groups_outlined,
                    label: 'Teams',
                    onTap: () => _goMyCricket(context, ref, tab: 2),
                  ),
                  _DrawerTile(
                    icon: Icons.analytics_outlined,
                    label: 'Stats & analysis',
                    onTap: () => _goMyCricket(context, ref, tab: 3),
                  ),
                  _DrawerTile(
                    icon: Icons.movie_outlined,
                    label: 'Highlights',
                    onTap: () => _goMyCricket(context, ref, tab: 4),
                  ),
                  const _DrawerSectionHeader('Explore'),
                  _DrawerTile(
                    icon: Icons.person_search_outlined,
                    label: 'Find cricketers',
                    onTap: () {
                      Navigator.pop(context);
                      requireAuthVoid(
                        context: context,
                        ref: ref,
                        returnPath: '/find-cricketers',
                        action: () async {
                          if (context.mounted) {
                            context.push('/find-cricketers');
                          }
                        },
                      );
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.people_outline,
                    label: 'Player directory',
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
                  const _DrawerSectionHeader('Account'),
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
                          if (context.mounted) {
                            context.push('/notifications');
                          }
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
                    icon: Icons.workspace_premium_outlined,
                    label: 'CrickFlow PRO',
                    subtitle: 'Premium tools',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/store');
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.cf.textMuted,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _goShell(BuildContext context, String path) {
    Navigator.pop(context);
    context.go(path);
  }

  static void _goMyCricket(
    BuildContext context,
    WidgetRef ref, {
    required int tab,
  }) {
    Navigator.pop(context);
    ref.read(myCricketInitialTabProvider.notifier).state = tab;
    context.go('/matches');
  }
}

class _DrawerSectionHeader extends StatelessWidget {
  const _DrawerSectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cf.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.isGuest,
    required this.onOpenProfile,
    required this.onSignIn,
    this.profile,
  });

  final UserModel? profile;
  final bool isGuest;
  final VoidCallback onOpenProfile;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    if (isGuest) {
      return Material(
        color: cf.chromeBackground,
        child: InkWell(
          onTap: onSignIn,
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
                  backgroundColor: cf.surfaceElevated,
                  child: Icon(Icons.person_outline, color: cf.textSecondary),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guest',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: cf.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sign in to sync your cricket',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cf.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.login, color: cf.accent, size: 22),
              ],
            ),
          ),
        ),
      );
    }

    final name = profile?.effectiveName ?? 'Player';
    final playerId = profile?.playerId;
    final role = profile?.role ?? UserRole.organizer;
    final isViewer = role == UserRole.viewer;

    return Material(
      color: cf.chromeBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpenProfile,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: CfColors.primaryBlue,
                    backgroundImage: profile?.photoUrl != null
                        ? CachedNetworkImageProvider(profile!.photoUrl!)
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: cf.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (playerId != null && playerId.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            CfPlayerIdFormat.displayLabel(playerId),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cf.textSecondary,
                                      letterSpacing: 0.3,
                                    ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cf.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cf.accent.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            isViewer ? 'Viewer' : 'Member',
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: cf.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cf.textMuted),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              0,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
            ),
            child: _HeaderAction(
              icon: Icons.insights_outlined,
              label: 'Cricket profile',
              onTap: () {
                Navigator.pop(context);
                context.push('/my-cricket-profile');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return Material(
      color: cf.surfaceElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceSm,
            vertical: AppDimens.spaceSm + 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: cf.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cf.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return ListTile(
      dense: subtitle == null,
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(icon, color: CfColors.primaryBlueLight, size: 22),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cf.textPrimary,
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                  ),
            )
          : null,
      onTap: onTap,
    );
  }
}
