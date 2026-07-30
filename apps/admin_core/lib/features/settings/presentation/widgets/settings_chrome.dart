import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_stat_tile.dart';
import '../../models/platform_settings.dart';
import '../../models/settings_enums.dart';

class SettingsSectionChips extends StatelessWidget {
  const SettingsSectionChips({
    super.key,
    required this.section,
    required this.onSelect,
    this.sections,
  });

  final SettingsHubSection section;
  final ValueChanged<SettingsHubSection> onSelect;
  final List<SettingsHubSection>? sections;

  @override
  Widget build(BuildContext context) {
    final list = sections ?? SettingsHubSection.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in list) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: section == s,
                label: Text(s.label),
                onSelected: (_) => onSelect(s),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsDashboardCards extends StatelessWidget {
  const SettingsDashboardCards({super.key, required this.dashboard});

  final SettingsDashboardSnapshot dashboard;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final df = DateFormat.yMMMd().add_jm();
    final cards = [
      _card(
        Icons.android,
        'Android Latest',
        dashboard.androidLatest,
        const Color(0xFF3DDC84),
      ),
      _card(
        Icons.phone_iphone,
        'iOS Latest',
        dashboard.iosLatest,
        const Color(0xFF555555),
      ),
      _card(
        Icons.system_update_alt,
        'Min Supported',
        'A ${dashboard.androidMinimum} · i ${dashboard.iosMinimum}',
        AdminColors.primaryBlue,
      ),
      _card(
        Icons.build_circle_outlined,
        'Maintenance',
        dashboard.maintenanceEnabled ? 'ON' : 'OFF',
        dashboard.maintenanceEnabled ? colors.warning : colors.success,
      ),
      _card(
        Icons.toggle_on_outlined,
        'Feature Flags On',
        '${dashboard.featureFlagsEnabled}/${dashboard.featureFlagsTotal}',
        const Color(0xFF7E57C2),
      ),
      _card(
        Icons.api_outlined,
        'Active APIs',
        '${dashboard.activeApis}',
        const Color(0xFF00897B),
      ),
      _card(
        Icons.update,
        'Last Update',
        dashboard.lastSettingsUpdate == null
            ? '—'
            : df.format(dashboard.lastSettingsUpdate!),
        colors.textMuted,
      ),
      _card(
        Icons.cloud_outlined,
        'Environment',
        dashboard.environment.label,
        AdminColors.goldDark,
      ),
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

class SettingsReadOnlyBanner extends StatelessWidget {
  const SettingsReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Read-only — only Super Admin can modify platform settings.',
              style: TextStyle(fontSize: 13, color: colors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
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
    );
  }
}
