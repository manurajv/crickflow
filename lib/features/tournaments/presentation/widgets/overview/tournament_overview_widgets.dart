import 'package:flutter/material.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';

class TournamentOverviewSectionCard extends StatelessWidget {
  const TournamentOverviewSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      color: cf.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cf.border),
      ),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cf.textPrimary,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              action!,
            ],
            const SizedBox(height: AppDimens.spaceSm),
            child,
          ],
        ),
      ),
    );
  }
}

class TournamentOverviewDetailRow extends StatelessWidget {
  const TournamentOverviewDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.valueColor,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final canTap = onTap != null;

    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: valueColor ?? (canTap ? cf.accent : cf.textPrimary),
          decoration: canTap ? TextDecoration.underline : null,
          fontWeight: canTap ? FontWeight.w600 : FontWeight.w500,
        );

    final valueWidget = canTap
        ? InkWell(
            onTap: onTap,
            child: Text(value, style: valueStyle),
          )
        : Text(value, style: valueStyle);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
            ),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

class TournamentStatusChip extends StatelessWidget {
  const TournamentStatusChip({super.key, required this.status});

  final TournamentStatus status;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final (label, color, bg) = _style(status, cf);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      ),
    );
  }

  (String, Color, Color) _style(TournamentStatus status, CfColors cf) {
    return switch (status) {
      TournamentStatus.live => ('Live', cf.success, cf.success.withValues(alpha: 0.12)),
      TournamentStatus.completed => ('Completed', cf.textSecondary, cf.sectionBackground),
      TournamentStatus.cancelled => ('Cancelled', cf.error, cf.error.withValues(alpha: 0.12)),
      TournamentStatus.upcoming => ('Upcoming', cf.accent, cf.accent.withValues(alpha: 0.12)),
      TournamentStatus.draft => ('Upcoming', cf.accent, cf.accent.withValues(alpha: 0.12)),
    };
  }
}

class TournamentOverviewStatGrid extends StatelessWidget {
  const TournamentOverviewStatGrid({
    super.key,
    required this.stats,
  });

  final List<TournamentOverviewStatItem> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 5 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppDimens.spaceSm,
            crossAxisSpacing: AppDimens.spaceSm,
            childAspectRatio: crossAxisCount >= 5 ? 1.35 : 1.55,
          ),
          itemBuilder: (context, index) {
            final stat = stats[index];
            return _StatTile(stat: stat);
          },
        );
      },
    );
  }
}

class TournamentOverviewStatItem {
  const TournamentOverviewStatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final TournamentOverviewStatItem stat;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(stat.icon, size: 20, color: cf.accent),
          const SizedBox(height: 6),
          Text(
            stat.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cf.textPrimary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cf.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class TournamentOverviewEmptyInline extends StatelessWidget {
  const TournamentOverviewEmptyInline({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
      child: Row(
        children: [
          Icon(icon, color: cf.textMuted.withValues(alpha: 0.55)),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
