import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_moderation.dart';
import '../../models/moderation_enums.dart';

class ModerationSummaryCards extends StatelessWidget {
  const ModerationSummaryCards({
    super.key,
    required this.summary,
    required this.surface,
  });

  final ModerationSummaryStats summary;
  final ModerationSurface surface;

  @override
  Widget build(BuildContext context) {
    final cards = switch (surface) {
      ModerationSurface.community => [
          _card(Icons.forum_outlined, 'Community Posts',
              '${summary.communityPosts}', AdminColors.primaryBlue),
          _card(Icons.today_outlined, 'Posts Today', '${summary.postsToday}',
              context.adminColors.info),
          _card(Icons.flag_outlined, 'Pending Reports',
              '${summary.pendingReports}', context.adminColors.warning),
          _card(Icons.delete_outline, 'Removed Posts',
              '${summary.removedPosts}', context.adminColors.error),
          _card(Icons.trending_up, 'Trending Posts',
              '${summary.trendingPosts}', context.adminColors.success),
        ],
      ModerationSurface.discover => [
          _card(Icons.explore_outlined, 'Discover Posts',
              '${summary.discoverPosts}', const Color(0xFF00897B)),
          _card(Icons.today_outlined, 'Posts Today', '${summary.postsToday}',
              context.adminColors.info),
          _card(Icons.flag_outlined, 'Pending Reports',
              '${summary.pendingReports}', context.adminColors.warning),
          _card(Icons.delete_outline, 'Removed Posts',
              '${summary.removedPosts}', context.adminColors.error),
        ],
      ModerationSurface.queue => [
          _card(Icons.forum_outlined, 'Community Posts',
              '${summary.communityPosts}', AdminColors.primaryBlue),
          _card(Icons.explore_outlined, 'Discover Posts',
              '${summary.discoverPosts}', const Color(0xFF00897B)),
          _card(Icons.today_outlined, 'Posts Today', '${summary.postsToday}',
              context.adminColors.info),
          _card(Icons.chat_outlined, 'Active Chats', '${summary.activeChats}',
              context.adminColors.info),
          _card(Icons.flag_outlined, 'Pending Reports',
              '${summary.pendingReports}', context.adminColors.warning),
          _card(Icons.delete_outline, 'Removed Posts',
              '${summary.removedPosts}', context.adminColors.error),
          _card(Icons.block_outlined, 'Blocked Users',
              '${summary.blockedUsers}', context.adminColors.error),
          _card(Icons.trending_up, 'Trending Posts',
              '${summary.trendingPosts}', context.adminColors.success),
        ],
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1400
            ? 4
            : width >= 1100
                ? 4
                : width >= 700
                    ? 2
                    : 1;
        const spacing = 12.0;
        final itemWidth = (width - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in cards) SizedBox(width: itemWidth, child: c),
          ],
        );
      },
    );
  }

  Widget _card(IconData icon, String title, String value, Color accent) {
    return CfStatTile(
      icon: icon,
      title: title,
      value: value,
      accentColor: accent,
      compact: true,
    );
  }
}
