import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_ads.dart';

class AdsSummaryCards extends StatelessWidget {
  const AdsSummaryCards({super.key, required this.summary});

  final AdsSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final revenueFmt = NumberFormat.compactCurrency(symbol: '\$');
    final cards = [
      _card(Icons.play_circle_outline, 'Active Campaigns',
          '${summary.activeCampaigns}', colors.success),
      _card(Icons.schedule_outlined, 'Scheduled',
          '${summary.scheduledCampaigns}', AdminColors.primaryBlue),
      _card(Icons.campaign_outlined, 'Total Ads', '${summary.totalAds}',
          const Color(0xFF7E57C2)),
      _card(Icons.emoji_events_outlined, 'Sponsored Tournaments',
          '${summary.sponsoredTournaments}', colors.info),
      _card(Icons.groups_outlined, 'Sponsored Teams',
          '${summary.sponsoredTeams}', colors.warning),
      _card(Icons.forum_outlined, 'Sponsored Posts',
          '${summary.sponsoredCommunityPosts}', const Color(0xFF00897B)),
      _card(Icons.visibility_outlined, 'Total Impressions',
          NumberFormat.compact().format(summary.totalImpressions), colors.info),
      _card(Icons.payments_outlined, 'Est. Revenue',
          revenueFmt.format(summary.estimatedRevenue), colors.success),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 800.0;
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
            for (final c in cards)
              SizedBox(
                width: itemWidth.isFinite && itemWidth > 0 ? itemWidth : width,
                child: c,
              ),
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
