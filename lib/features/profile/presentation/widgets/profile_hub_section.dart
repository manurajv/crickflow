import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/user_model.dart';

/// Quick navigation hub for the signed-in user's account area.
class ProfileHubSection extends StatelessWidget {
  const ProfileHubSection({
    super.key,
    this.user,
    this.isOwnProfile = true,
  });

  /// When viewing another user's profile, pass their [user] and set
  /// [isOwnProfile] to false to show only their cricket profile link.
  final UserModel? user;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final otherPlayerId = user?.playerId?.trim() ?? '';
    final otherName = user?.effectiveName.trim() ?? 'Player';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOwnProfile ? 'Quick links' : 'Cricket',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cf.textPrimary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        if (isOwnProfile) ...[
          _HubTile(
            icon: Icons.insights_outlined,
            title: 'Cricket Profile',
            subtitle: 'Stats, badges, and analysis',
            accent: cf.accent,
            onTap: () => context.push('/my-cricket-profile'),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _HubTile(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Photo, role, and contact details',
            onTap: () => context.push('/profile/edit'),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _HubTile(
            icon: Icons.person_search_outlined,
            title: 'Find Cricketers',
            subtitle: 'Discover players near you',
            onTap: () => context.push('/find-cricketers'),
          ),
        ] else if (otherPlayerId.isNotEmpty) ...[
          _HubTile(
            icon: Icons.insights_outlined,
            title: "$otherName's Cricket Profile",
            subtitle: 'Stats, badges, and analysis',
            accent: cf.accent,
            onTap: () => context.push('/player/$otherPlayerId/cricket'),
          ),
        ],
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final iconColor = accent ?? CfColors.primaryBlueLight;

    return Material(
      color: cf.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: cfCardDecoration(context),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cf.textPrimary,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cf.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
