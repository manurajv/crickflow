import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';


import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/cf_player_id_format.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../core/utils/player_profile_labels.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/player_social_stats_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../shared/providers/player_social_provider.dart';
import '../../../../shared/widgets/player_cluster_text.dart';
import '../../../profile/presentation/widgets/player_follow_button.dart';

/// Profile hero content — sits below the pinned app bar inside [FlexibleSpaceBar].
class CricketProfileHeader extends ConsumerWidget {
  const CricketProfileHeader({
    super.key,
    this.user,
    this.player,
    this.clusters = const PlayerClusters(),
    this.isOwnProfile = false,
    this.viewerId,
  });

  final UserModel? user;
  final PlayerModel? player;
  final PlayerClusters clusters;
  final bool isOwnProfile;
  final String? viewerId;

  /// Card body height including vertical padding (keep in sync with layout).
  static const contentHeight = 180.0;

  static double expandedHeight(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return top + contentHeight;
  }

  /// Solid fallback matching [CfColors.heroGradient] bottom — used for app bar chrome.
  static Color heroBarColor(CfColors cf) => cf.heroGradient.colors.last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = user?.effectiveName ?? player?.name ?? 'Player';
    final photoUrl = user?.photoUrl ?? player?.photoUrl;
    final playerId = user?.playerId ?? player?.playerId ?? '';
    final stats = user != null
        ? ref.watch(playerSocialStatsProvider(user!.id)).valueOrNull ??
            user!.socialStats
        : const PlayerSocialStatsModel();

    final location = user != null
        ? PlayerProfileLabels.location(user!)
        : (player?.location.displayLabel ?? '');
    final roleLine = user != null
        ? PlayerProfileLabels.roleStylesLine(user!)
        : PlayerProfileLabels.roleStylesLineFromPlayer(
            role: player?.role ?? '',
            battingStyle: player?.battingStyle ?? '',
            bowlingStyle: player?.bowlingStyle ?? '',
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white24,
                  backgroundImage: photoUrl != null
                      ? CachedNetworkImageProvider(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
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
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                      if (playerId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          CfPlayerIdFormat.displayLabel(playerId),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    letterSpacing: 0.4,
                                  ),
                        ),
                      ],
                      if (location.isNotEmpty && location != '—') ...[
                        const SizedBox(height: 4),
                        Text(
                          location,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                        ),
                      ],
                      if (roleLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          roleLine,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                        ),
                      ],
                      if (clusters.batting != null ||
                          clusters.bowling != null) ...[
                        const SizedBox(height: 6),
                        PlayerClusterText(
                          clusters: clusters,
                          separatorColor: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            _StatsRow(stats: stats, playerId: playerId),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                if (!isOwnProfile &&
                    user != null &&
                    viewerId != null &&
                    viewerId != user!.id) ...[
                  Expanded(
                    child: PlayerFollowButton(
                      followedUser: user!,
                      followerUserId: viewerId!,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                ],
                Expanded(
                  child: _CardActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onPressed: playerId.isEmpty ? null : () => _share(context),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: _CardActionButton(
                    icon: Icons.qr_code_2_outlined,
                    label: 'QR Code',
                    onPressed: playerId.isEmpty
                        ? null
                        : () => context.push('/player/$playerId/qr'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  Future<void> _share(BuildContext context) async {
    final id = user?.playerId ?? player?.playerId;
    if (id == null || id.isEmpty) return;
    final name = user?.effectiveName ?? player?.name ?? 'Player';
    final appLink = DeepLinkUtils.playerUri(id).toString();
    final webLink = DeepLinkUtils.hostedPlayerUri(id).toString();
    await Share.share(
      'Check out $name on CrickFlow ($id)\n$appLink\n$webLink',
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.playerId});

  final PlayerSocialStatsModel stats;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatChip(
          value: stats.followersCount,
          label: 'Followers',
          onTap: playerId.isEmpty
              ? null
              : () => context.push('/player/$playerId/followers'),
        ),
        _StatChip(
          value: stats.followingCount,
          label: 'Following',
          onTap: playerId.isEmpty
              ? null
              : () => context.push('/player/$playerId/following'),
        ),
        _StatChip(
          value: stats.profileViewsCount,
          label: 'Profile Views',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          _format(value),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
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

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: cf.accent,
          fontWeight: FontWeight.w600,
        );

    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17, color: cf.accent),
      label: Text(label, style: labelStyle),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: cf.accent,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
        disabledForegroundColor: cf.textMuted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
