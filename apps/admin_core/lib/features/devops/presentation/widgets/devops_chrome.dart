import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_search_bar.dart';
import '../../../../shared/widgets/cf_status_badge.dart';
import '../../models/devops_enums.dart';
import '../../models/devops_filters.dart';
import '../../models/managed_devops.dart';

class DevOpsSummaryCards extends StatelessWidget {
  const DevOpsSummaryCards({super.key, required this.summary});

  final DevOpsSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Environment', summary.currentEnvironment.label, Icons.layers_outlined),
      ('Current Version', summary.currentVersion, Icons.tag),
      ('Latest Version', summary.latestVersion, Icons.new_releases_outlined),
      ('Last Deployment', summary.lastDeploymentLabel, Icons.rocket_launch_outlined),
      ('Deploy Status', summary.deploymentStatus.label, Icons.flag_outlined),
      ('Duration', summary.deploymentDurationLabel, Icons.timer_outlined),
      ('Env Health', summary.environmentHealth, Icons.monitor_heart_outlined),
      ('Firebase', summary.firebaseProject, Icons.local_fire_department_outlined),
      ('Hosting', summary.hostingStatus, Icons.cloud_outlined),
      ('Domains', summary.domainStatus, Icons.language_outlined),
      ('Open Releases', '${summary.openReleases}', Icons.inventory_2_outlined),
      ('Failed Builds', '${summary.failedBuilds}', Icons.broken_image_outlined),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1200
            ? 4
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
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

class DevOpsSectionChips extends StatelessWidget {
  const DevOpsSectionChips({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final DevOpsHubSection section;
  final ValueChanged<DevOpsHubSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in DevOpsHubSection.values)
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

class DevOpsToolbar extends StatelessWidget {
  const DevOpsToolbar({
    super.key,
    required this.searchController,
    required this.onQueryChanged,
    required this.filterActive,
    required this.refreshing,
    required this.onFilter,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final bool filterActive;
  final bool refreshing;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CfSearchBar(
            controller: searchController,
            hintText: 'Search releases, deployments, versions…',
            onChanged: onQueryChanged,
          ),
        ),
        const SizedBox(width: 8),
        CfButton(
          label: filterActive ? 'Filters •' : 'Filters',
          icon: Icons.filter_list,
          variant: CfButtonVariant.secondary,
          onPressed: onFilter,
        ),
        const SizedBox(width: 8),
        CfButton(
          label: 'Refresh',
          icon: Icons.refresh,
          variant: CfButtonVariant.ghost,
          isLoading: refreshing,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}

CfBadgeTone _statusTone(String status) {
  final s = status.toLowerCase();
  if (s.contains('fail') || s.contains('error') || s.contains('cancel')) {
    return CfBadgeTone.danger;
  }
  if (s.contains('success') ||
      s.contains('published') ||
      s.contains('healthy') ||
      s.contains('completed') ||
      s.contains('active')) {
    return CfBadgeTone.success;
  }
  if (s.contains('schedul') || s.contains('queued') || s.contains('pending')) {
    return CfBadgeTone.warning;
  }
  return CfBadgeTone.info;
}

class DevOpsStatusChip extends StatelessWidget {
  const DevOpsStatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CfStatusBadge(label: label, tone: _statusTone(label));
  }
}

Future<DevOpsFilters?> showDevOpsFilterDrawer({
  required BuildContext context,
  required DevOpsFilters initial,
}) async {
  var draft = initial;
  final statusController = TextEditingController(text: initial.status ?? '');
  final versionController = TextEditingController(text: initial.version ?? '');
  try {
    return await showGeneralDialog<DevOpsFilters>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filters',
      pageBuilder: (ctx, a1, a2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Theme.of(ctx).colorScheme.surface,
            child: SizedBox(
              width: 360,
              height: MediaQuery.sizeOf(ctx).height,
              child: StatefulBuilder(
                builder: (ctx, setLocal) {
                  return SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Filters',
                                  style: Theme.of(ctx).textTheme.titleLarge,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              DropdownButtonFormField<DevOpsEnvironment?>(
                                // ignore: deprecated_member_use
                                value: draft.environment,
                                decoration: const InputDecoration(
                                  labelText: 'Environment',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Any'),
                                  ),
                                  for (final e in DevOpsEnvironment.values)
                                    DropdownMenuItem(
                                      value: e,
                                      child: Text(e.label),
                                    ),
                                ],
                                onChanged: (v) => setLocal(() {
                                  draft = v == null
                                      ? draft.copyWith(clearEnvironment: true)
                                      : draft.copyWith(environment: v);
                                }),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<DevOpsReleaseType?>(
                                // ignore: deprecated_member_use
                                value: draft.releaseType,
                                decoration: const InputDecoration(
                                  labelText: 'Release type',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Any'),
                                  ),
                                  for (final t in DevOpsReleaseType.values)
                                    DropdownMenuItem(
                                      value: t,
                                      child: Text(t.label),
                                    ),
                                ],
                                onChanged: (v) => setLocal(() {
                                  draft = v == null
                                      ? draft.copyWith(clearReleaseType: true)
                                      : draft.copyWith(releaseType: v);
                                }),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Status (wire value)',
                                  hintText: 'draft / published / success…',
                                ),
                                controller: statusController,
                                onChanged: (v) {
                                  draft = v.trim().isEmpty
                                      ? draft.copyWith(clearStatus: true)
                                      : draft.copyWith(status: v.trim());
                                },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Version contains',
                                ),
                                controller: versionController,
                                onChanged: (v) {
                                  draft = v.trim().isEmpty
                                      ? draft.copyWith(clearVersion: true)
                                      : draft.copyWith(version: v.trim());
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: CfButton(
                                  label: 'Reset',
                                  variant: CfButtonVariant.secondary,
                                  onPressed: () =>
                                      Navigator.pop(ctx, DevOpsFilters.empty),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CfButton(
                                  label: 'Apply',
                                  onPressed: () => Navigator.pop(ctx, draft),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  } finally {
    statusController.dispose();
    versionController.dispose();
  }
}
