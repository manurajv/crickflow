import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/managed_notification.dart';

class NotificationsSummaryCards extends StatelessWidget {
  const NotificationsSummaryCards({super.key, required this.summary});

  final NotificationSummaryStats summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final cards = [
      _card(Icons.send_outlined, 'Sent Today', '${summary.sentToday}',
          AdminColors.primaryBlue),
      _card(Icons.schedule_outlined, 'Scheduled', '${summary.scheduled}',
          colors.info),
      _card(Icons.check_circle_outline, 'Delivered', '${summary.delivered}',
          colors.success),
      _card(Icons.error_outline, 'Failed', '${summary.failed}', colors.error),
      _card(Icons.visibility_outlined, 'Open Rate',
          '${(summary.openRate * 100).toStringAsFixed(1)}%', colors.info),
      _card(Icons.touch_app_outlined, 'Click Rate',
          '${(summary.clickRate * 100).toStringAsFixed(1)}%', colors.warning),
      _card(Icons.campaign_outlined, 'Active Campaigns',
          '${summary.activeCampaigns}', const Color(0xFF7E57C2)),
      _card(Icons.edit_note_outlined, 'Draft Campaigns',
          '${summary.draftCampaigns}', colors.textMuted),
    ];

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
