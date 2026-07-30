import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_search_bar.dart';
import '../../../../shared/widgets/cf_status_badge.dart';
import '../../models/continuity_enums.dart';
import '../../models/continuity_filters.dart';
import '../../models/managed_continuity.dart';

class ContinuitySummaryCards extends StatelessWidget {
  const ContinuitySummaryCards({super.key, required this.summary});

  final ContinuitySummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Latest Backup', summary.latestBackupLabel, Icons.backup_outlined),
      ('Last Success', summary.lastSuccessLabel, Icons.check_circle_outline),
      ('Last Failed', summary.lastFailedLabel, Icons.error_outline),
      ('Firestore', summary.firestoreStatus, Icons.storage_outlined),
      ('Storage', summary.storageStatus, Icons.cloud_outlined),
      ('Configuration', summary.configStatus, Icons.settings_outlined),
      ('Est. Size', summary.estimatedSizeLabel, Icons.data_usage_outlined),
      ('Readiness', summary.recoveryReadiness, Icons.health_and_safety_outlined),
      ('Score', '${summary.recoveryScore}/100', Icons.scoreboard_outlined),
      ('Environment', summary.environment, Icons.layers_outlined),
      ('Open Restores', '${summary.openRestores}', Icons.restore_outlined),
      ('Open Migrations', '${summary.openMigrations}', Icons.swap_horiz_outlined),
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

class ContinuitySectionChips extends StatelessWidget {
  const ContinuitySectionChips({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final ContinuityHubSection section;
  final ValueChanged<ContinuityHubSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in ContinuityHubSection.values)
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

class ContinuityToolbar extends StatelessWidget {
  const ContinuityToolbar({
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
          hintText: 'Search backup ID, migration, restore, recovery plan…',
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            CfButton(
              label: filterActive ? 'Filters •' : 'Filters',
              variant: CfButtonVariant.secondary,
              onPressed: onFilter,
            ),
            const SizedBox(width: 8),
            CfButton(
              label: refreshing ? 'Refreshing…' : 'Refresh',
              variant: CfButtonVariant.ghost,
              onPressed: refreshing ? null : onRefresh,
            ),
          ],
        ),
      ],
    );
  }
}

String continuityFormatTime(DateTime? t) {
  if (t == null) return '—';
  return DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());
}

CfBadgeTone continuityStatusTone(ContinuityJobStatus s) => switch (s) {
      ContinuityJobStatus.success => CfBadgeTone.success,
      ContinuityJobStatus.failed => CfBadgeTone.danger,
      ContinuityJobStatus.running ||
      ContinuityJobStatus.validating ||
      ContinuityJobStatus.queued =>
        CfBadgeTone.warning,
      ContinuityJobStatus.awaitingConfirmation => CfBadgeTone.info,
      _ => CfBadgeTone.neutral,
    };

Future<ContinuityFilters?> showContinuityFilterDrawer({
  required BuildContext context,
  required ContinuityFilters initial,
}) async {
  var draft = initial;
  return showGeneralDialog<ContinuityFilters>(
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
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Environment',
                                hintText: 'production / staging…',
                              ),
                              controller: TextEditingController(
                                text: draft.environment ?? '',
                              ),
                              onChanged: (v) => setLocal(() {
                                draft = v.trim().isEmpty
                                    ? draft.copyWith(clearEnvironment: true)
                                    : draft.copyWith(environment: v.trim());
                              }),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<ContinuityJobStatus?>(
                              // ignore: deprecated_member_use
                              value: draft.status,
                              decoration:
                                  const InputDecoration(labelText: 'Status'),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Any'),
                                ),
                                for (final s in ContinuityJobStatus.values)
                                  DropdownMenuItem(
                                    value: s,
                                    child: Text(s.label),
                                  ),
                              ],
                              onChanged: (v) => setLocal(() {
                                draft = v == null
                                    ? draft.copyWith(clearStatus: true)
                                    : draft.copyWith(status: v);
                              }),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<ContinuityBackupType?>(
                              // ignore: deprecated_member_use
                              value: draft.backupType,
                              decoration: const InputDecoration(
                                labelText: 'Backup type',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Any'),
                                ),
                                for (final t in ContinuityBackupType.values)
                                  DropdownMenuItem(
                                    value: t,
                                    child: Text(t.label),
                                  ),
                              ],
                              onChanged: (v) => setLocal(() {
                                draft = v == null
                                    ? draft.copyWith(clearBackupType: true)
                                    : draft.copyWith(backupType: v);
                              }),
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
                                    Navigator.pop(ctx, ContinuityFilters.empty),
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
}
