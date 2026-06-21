import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/cf_player_id_format.dart';
import '../../../../core/utils/player_profile_labels.dart';
import '../../../../data/models/player_social_stats_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/player_social_provider.dart';

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    this.statsOverride,
  });

  final UserModel user;
  final PlayerSocialStatsModel? statsOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final statsAsync = ref.watch(playerSocialStatsProvider(user.id));
    final stats = statsOverride ??
        statsAsync.valueOrNull ??
        user.socialStats;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: cfCardDecoration(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: CfColors.primaryBlue,
                backgroundImage: user.photoUrl != null
                    ? CachedNetworkImageProvider(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? Text(
                        user.effectiveName.isNotEmpty
                            ? user.effectiveName[0].toUpperCase()
                            : '?',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: cf.onPrimary,
                                  fontWeight: FontWeight.w700,
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
                      user.effectiveName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cf.textPrimary,
                          ),
                    ),
                    if (user.effectivePlayerIdDisplay.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${CfPlayerIdFormat.displayLabel(user.playerId)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cf.textSecondary,
                              letterSpacing: 0.4,
                            ),
                      ),
                    ],
                    const SizedBox(height: AppDimens.spaceSm),
                    _HeaderDetailLine(
                      icon: Icons.location_on_outlined,
                      text: PlayerProfileLabels.location(user),
                      cf: cf,
                    ),
                    const SizedBox(height: 4),
                    _HeaderDetailLine(
                      icon: Icons.calendar_today_outlined,
                      text: PlayerProfileLabels.joinedDate(user),
                      cf: cf,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        ProfileStatsRow(
          stats: stats,
          playerId: user.playerId,
        ),
      ],
    );
  }
}

class _HeaderDetailLine extends StatelessWidget {
  const _HeaderDetailLine({
    required this.icon,
    required this.text,
    required this.cf,
  });

  final IconData icon;
  final String text;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cf.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    super.key,
    required this.stats,
    this.playerId,
  });

  final PlayerSocialStatsModel stats;
  final String? playerId;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final id = playerId;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatChip(
          value: stats.followersCount,
          label: 'Followers',
          cf: cf,
          onTap: id == null || id.isEmpty
              ? null
              : () => context.push('/player/$id/followers'),
        ),
        _StatChip(
          value: stats.followingCount,
          label: 'Following',
          cf: cf,
          onTap: id == null || id.isEmpty
              ? null
              : () => context.push('/player/$id/following'),
        ),
        _StatChip(
          value: stats.profileViewsCount,
          label: 'Profile Views',
          cf: cf,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    required this.cf,
    this.onTap,
  });

  final int value;
  final String label;
  final CfColors cf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          _format(value),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cf.textPrimary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cf.textSecondary,
              ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: content,
      ),
    );
  }

  static String _format(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
