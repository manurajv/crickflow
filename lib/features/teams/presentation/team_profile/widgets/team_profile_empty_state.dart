import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';

class TeamProfileEmptyState extends StatelessWidget {
  const TeamProfileEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
        Icon(icon, size: 56, color: cf.textMuted),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cf.textPrimary,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppDimens.spaceXs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXl),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

class TeamProfileSkeleton extends StatelessWidget {
  const TeamProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    Widget bar({double w = double.infinity, double h = 14}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: cf.border.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
          ),
        );

    return ListView(
      padding: AppDimens.listPadding,
      children: [
        for (var i = 0; i < 6; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: cfCardDecoration(context),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cf.border.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(w: 140, h: 16),
                      const SizedBox(height: 8),
                      bar(w: 90, h: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
