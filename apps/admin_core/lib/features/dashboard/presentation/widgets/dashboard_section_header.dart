import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_card.dart';

class DashboardSectionHeader extends StatelessWidget {
  const DashboardSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class DashboardSkeletonBox extends StatelessWidget {
  const DashboardSkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: colors.border.withValues(alpha: colors.isLight ? 0.55 : 0.35),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class DashboardSkeletonCard extends StatelessWidget {
  const DashboardSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const CfCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSkeletonBox(width: 40, height: 40, radius: 12),
          Spacer(),
          DashboardSkeletonBox(width: 80, height: 22),
          SizedBox(height: 8),
          DashboardSkeletonBox(width: 120, height: 14),
        ],
      ),
    );
  }
}

/// Horizontal chip-style skeleton matching [DashboardQuickActionCard].
class DashboardSkeletonActionChip extends StatelessWidget {
  const DashboardSkeletonActionChip({super.key});

  @override
  Widget build(BuildContext context) {
    return const CfCard(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DashboardSkeletonBox(width: 36, height: 36, radius: 10),
          SizedBox(width: 12),
          DashboardSkeletonBox(width: 90, height: 14),
        ],
      ),
    );
  }
}

