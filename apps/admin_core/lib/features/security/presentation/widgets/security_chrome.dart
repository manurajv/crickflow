import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_search_bar.dart';
import '../../models/managed_security.dart';
import '../../models/security_enums.dart';
import '../../models/security_filters.dart';

class SocSummaryCards extends StatelessWidget {
  const SocSummaryCards({super.key, required this.summary});

  final SecuritySummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Security Score', '${summary.securityScore}', Icons.security),
      ('Critical Alerts', '${summary.criticalAlerts}', Icons.warning_amber),
      ('Warnings', '${summary.warnings}', Icons.error_outline),
      ('Blocked Users', '${summary.blockedUsers}', Icons.person_off_outlined),
      ('Blocked Devices', '${summary.blockedDevices}', Icons.phonelink_erase),
      ('Blocked IPs', '${summary.blockedIps}', Icons.block),
      ('Failed Logins Today', '${summary.failedLoginsToday}', Icons.lock_outline),
      ('Suspicious', '${summary.suspiciousActivities}', Icons.policy_outlined),
      ('Expired Sessions', '${summary.expiredSessions}', Icons.timer_off_outlined),
      ('Admins Online', '${summary.adminsOnline}', Icons.admin_panel_settings_outlined),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1200
            ? 5
            : c.maxWidth >= 800
                ? 3
                : c.maxWidth >= 520
                    ? 2
                    : 1;
        const spacing = 12.0;
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final i in items)
              SizedBox(
                width: w,
                child: CfCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(i.$3, color: AdminColors.primaryBlue, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.adminColors.textMuted,
                              ),
                            ),
                            Text(
                              i.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SocSeverityBadge extends StatelessWidget {
  const SocSeverityBadge({super.key, required this.severity});
  final SocSeverity severity;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = switch (severity) {
      SocSeverity.info => AdminColors.primaryBlue,
      SocSeverity.warning => colors.warning,
      SocSeverity.high => colors.error,
      SocSeverity.critical => colors.error,
    };
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          severity.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

class SocSectionChips extends StatelessWidget {
  const SocSectionChips({
    super.key,
    required this.section,
    required this.onChanged,
    this.isSuperAdmin = true,
  });

  final SocHubSection section;
  final ValueChanged<SocHubSection> onChanged;
  final bool isSuperAdmin;

  @override
  Widget build(BuildContext context) {
    final sections = SocHubSection.visibleFor(isSuperAdmin: isSuperAdmin);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s.label),
                selected: section == s,
                onSelected: (_) => onChanged(s),
              ),
            ),
        ],
      ),
    );
  }
}

class SocToolbar extends StatelessWidget {
  const SocToolbar({
    super.key,
    this.searchController,
    required this.onQueryChanged,
    required this.onFilter,
    required this.onRefresh,
    required this.filterActive,
    required this.refreshing,
  });

  final TextEditingController? searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final bool filterActive;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CfSearchBar(
          controller: searchController,
          hintText: 'Search users, sessions, roles, permissions, devices, alerts…',
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onFilter,
              icon: Badge(
                isLabelVisible: filterActive,
                smallSize: 8,
                child: const Icon(Icons.filter_list),
              ),
              label: const Text('Filters'),
            ),
            IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
            Text(
              'Secrets never displayed · Firebase config never auto-changed',
              style: TextStyle(
                fontSize: 11,
                color: context.adminColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<SecurityFilters?> showSocFilterDrawer({
  required BuildContext context,
  required SecurityFilters initial,
  required bool isSuperAdmin,
}) {
  return showModalBottomSheet<SecurityFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _SocFilterSheet(
      initial: initial,
      isSuperAdmin: isSuperAdmin,
    ),
  );
}

class _SocFilterSheet extends StatefulWidget {
  const _SocFilterSheet({required this.initial, required this.isSuperAdmin});
  final SecurityFilters initial;
  final bool isSuperAdmin;

  @override
  State<_SocFilterSheet> createState() => _SocFilterSheetState();
}

class _SocFilterSheetState extends State<_SocFilterSheet> {
  late Set<SocSeverity> _severities;
  late Set<SocAlertStatus> _statuses;
  late final TextEditingController _role;
  late final TextEditingController _org;
  late final TextEditingController _country;
  late final TextEditingController _device;
  late final TextEditingController _browser;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _severities = {...widget.initial.severities};
    _statuses = {...widget.initial.alertStatuses};
    _role = TextEditingController(text: widget.initial.roleId ?? '');
    _org = TextEditingController(text: widget.initial.organizationId ?? '');
    _country = TextEditingController(text: widget.initial.country ?? '');
    _device = TextEditingController(text: widget.initial.device ?? '');
    _browser = TextEditingController(text: widget.initial.browser ?? '');
    _from = widget.initial.from;
    _to = widget.initial.to;
  }

  @override
  void dispose() {
    _role.dispose();
    _org.dispose();
    _country.dispose();
    _device.dispose();
    _browser.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Security filters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text('Severity', style: Theme.of(context).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in SocSeverity.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _severities.contains(s),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _severities.add(s);
                            } else {
                              _severities.remove(s);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Alert status',
                      style: Theme.of(context).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in SocAlertStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _statuses.contains(s),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _statuses.add(s);
                            } else {
                              _statuses.remove(s);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                  ),
                  if (widget.isSuperAdmin) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _org,
                      decoration:
                          const InputDecoration(labelText: 'Organization ID'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _country,
                    decoration: const InputDecoration(labelText: 'Country'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _device,
                    decoration: const InputDecoration(labelText: 'Device'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _browser,
                    decoration: const InputDecoration(labelText: 'Browser'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, SecurityFilters.empty),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  CfButton(
                    label: 'Apply',
                    onPressed: () {
                      Navigator.pop(
                        context,
                        SecurityFilters(
                          query: widget.initial.query,
                          severities: _severities,
                          alertStatuses: _statuses,
                          roleId:
                              _role.text.trim().isEmpty ? null : _role.text.trim(),
                          organizationId:
                              _org.text.trim().isEmpty ? null : _org.text.trim(),
                          country: _country.text.trim().isEmpty
                              ? null
                              : _country.text.trim(),
                          device: _device.text.trim().isEmpty
                              ? null
                              : _device.text.trim(),
                          browser: _browser.text.trim().isEmpty
                              ? null
                              : _browser.text.trim(),
                          from: _from,
                          to: _to,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
