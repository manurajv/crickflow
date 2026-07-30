import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/audit_enums.dart';
import '../../models/audit_log_view.dart';

class AuditSectionChips extends StatelessWidget {
  const AuditSectionChips({
    super.key,
    required this.section,
    required this.onSelect,
  });

  final AuditHubSection section;
  final ValueChanged<AuditHubSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in AuditHubSection.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: section == s,
                label: Text(s.label),
                onSelected: (_) => onSelect(s),
              ),
            ),
        ],
      ),
    );
  }
}

class AuditDashboardCards extends StatelessWidget {
  const AuditDashboardCards({super.key, required this.stats});

  final AuditDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final cards = [
      _card(Icons.flash_on_outlined, 'Actions Today', '${stats.actionsToday}',
          AdminColors.primaryBlue),
      _card(Icons.error_outline, 'Failed Actions', '${stats.failedActions}',
          colors.error),
      _card(Icons.shield_outlined, 'Security Events', '${stats.securityEvents}',
          colors.warning),
      _card(Icons.login, 'Logins Today', '${stats.loginsToday}',
          const Color(0xFF00897B)),
      _card(Icons.people_outline, 'Active Admins', '${stats.activeAdmins}',
          const Color(0xFF7E57C2)),
      _card(Icons.admin_panel_settings_outlined, 'Permission Changes',
          '${stats.permissionChanges}', const Color(0xFF5C6BC0)),
      _card(Icons.warning_amber_outlined, 'Suspicious',
          '${stats.suspiciousActivities}', colors.warning),
      _card(Icons.report_gmailerrorred_outlined, 'Critical',
          '${stats.criticalEvents}', colors.error),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1400
            ? 4
            : width >= 900
                ? 4
                : width >= 600
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

class AuditSeverityBadge extends StatelessWidget {
  const AuditSeverityBadge({super.key, required this.severity});

  final AuditSeverity severity;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (severity) {
      AuditSeverity.info => AdminColors.primaryBlue,
      AuditSeverity.warning => colors.warning,
      AuditSeverity.high => const Color(0xFFE65100),
      AuditSeverity.critical => colors.error,
    };
    return _Pill(label: severity.label, color: color);
  }
}

class AuditStatusBadge extends StatelessWidget {
  const AuditStatusBadge({super.key, required this.status});

  final AuditStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (status) {
      AuditStatus.success => colors.success,
      AuditStatus.failed => colors.error,
      AuditStatus.blocked => colors.warning,
      AuditStatus.expired => colors.textMuted,
      AuditStatus.pending => AdminColors.primaryBlue,
    };
    return _Pill(label: status.label, color: color);
  }
}

class AuditModuleBadge extends StatelessWidget {
  const AuditModuleBadge({super.key, required this.module});

  final AuditModule module;

  @override
  Widget build(BuildContext context) {
    return _Pill(label: module.label, color: context.adminColors.info);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AuditSectionCard extends StatelessWidget {
  const AuditSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final radius = BorderRadius.circular(14);
    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
