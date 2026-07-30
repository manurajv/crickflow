import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/audit_log_view.dart';
import '../../providers/audit_providers.dart';
import 'audit_chrome.dart';
import 'audit_table.dart';

class AuditSectionBody extends ConsumerWidget {
  const AuditSectionBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditHubControllerProvider);
    final controller = ref.read(auditHubControllerProvider.notifier);

    return switch (state.section) {
      AuditHubSection.dashboard => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuditDashboardCards(stats: state.snapshot.stats),
            const SizedBox(height: 20),
            AuditSectionCard(
              title: 'Retention policy',
              subtitle:
                  'Configurable retention prepared for future automatic cleanup.',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in AuditRetentionPeriod.values)
                    Chip(
                      label: Text(r.label),
                      backgroundColor: r == state.snapshot.retention
                          ? AdminColors.primaryBlue.withValues(alpha: 0.15)
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AuditSectionCard(
              title: 'Recent activity',
              subtitle: 'Latest administrative actions across the platform.',
              child: state.snapshot.recent.isEmpty
                  ? const Text('No recent activity yet.')
                  : Column(
                      children: [
                        for (final l in state.snapshot.recent.take(8))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              l.actionLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${l.actorEmail} · ${l.module.label}',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.adminColors.textMuted,
                              ),
                            ),
                            trailing: AuditSeverityBadge(severity: l.severity),
                            onTap: () => controller.selectLog(l.id),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      AuditHubSection.timeline => const _TimelinePanel(),
      AuditHubSection.auditLogs ||
      AuditHubSection.loginHistory ||
      AuditHubSection.securityEvents ||
      AuditHubSection.permissionChanges ||
      AuditHubSection.dataChanges ||
      AuditHubSection.systemEvents =>
        AuditLogsTable(
          logs: controller.logsForSection(),
          isLoading: state.isLoading,
          hasMore: state.hasMore &&
              state.section == AuditHubSection.auditLogs,
          isLoadingMore: state.isLoadingMore,
          selectedId: state.selectedId,
          onSelect: (l) => controller.selectLog(l.id),
          onLoadMore: controller.loadMore,
        ),
      AuditHubSection.exportCenter => const _ExportPanel(),
    };
  }
}

class _TimelinePanel extends ConsumerWidget {
  const _TimelinePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditTimelineProvider);
    final colors = context.adminColors;
    final df = DateFormat.yMMMd().add_jm();
    final controller = ref.read(auditHubControllerProvider.notifier);

    return AuditSectionCard(
      title: 'Activity Timeline',
      subtitle: 'Realtime feed — newest first. Auto-updates without refresh.',
      child: async.when(
        loading: () => const CfLoadingState(message: 'Connecting timeline…'),
        error: (e, _) => Text('$e'),
        data: (logs) {
          if (logs.isEmpty) {
            return const CfEmptyState(
              icon: Icons.timeline,
              title: 'No activity yet',
              message: 'Administrative actions will appear here in realtime.',
            );
          }
          return Column(
            children: [
              for (final l in logs)
                _TimelineTile(
                  log: l,
                  timestamp: df.format(l.timestamp),
                  onTap: () => controller.selectLog(l.id),
                  colors: colors,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.log,
    required this.timestamp,
    required this.onTap,
    required this.colors,
  });

  final AuditLogView log;
  final String timestamp;
  final VoidCallback onTap;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AdminColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.card as Color, width: 2),
                  ),
                ),
                Container(
                  width: 2,
                  height: 48,
                  color: (colors.border as Color).withValues(alpha: 0.8),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${log.actorEmail} → ${log.targetLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted as Color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      AuditModuleBadge(module: log.module),
                      const SizedBox(width: 6),
                      Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textMuted as Color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AuditSeverityBadge(severity: log.severity),
          ],
        ),
      ),
    );
  }
}

class _ExportPanel extends ConsumerWidget {
  const _ExportPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(auditHubControllerProvider.notifier);
    return AuditSectionCard(
      title: 'Export Center',
      subtitle:
          'CSV and JSON are available now. Excel, PDF, and backup are prepared for later.',
      child: Column(
        children: [
          for (final format in AuditExportFormat.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_icon(format)),
              title: Text(format.label),
              trailing: format == AuditExportFormat.csv ||
                      format == AuditExportFormat.json
                  ? FilledButton(
                      onPressed: () async {
                        final text = format == AuditExportFormat.csv
                            ? controller.exportCsv()
                            : controller.exportJson();
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${format.label} copied to clipboard'),
                            ),
                          );
                        }
                      },
                      child: const Text('Copy'),
                    )
                  : const Chip(
                      label: Text('Coming soon'),
                      visualDensity: VisualDensity.compact,
                    ),
            ),
          const SizedBox(height: 12),
          Text(
            'Future alerts: critical security events, multiple failed logins, '
            'unauthorized access, mass deletions, permission escalation.',
            style: TextStyle(
              fontSize: 12,
              color: context.adminColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(AuditExportFormat f) => switch (f) {
        AuditExportFormat.csv => Icons.table_chart_outlined,
        AuditExportFormat.excel => Icons.grid_on_outlined,
        AuditExportFormat.pdf => Icons.picture_as_pdf_outlined,
        AuditExportFormat.json => Icons.data_object,
        AuditExportFormat.backup => Icons.backup_outlined,
      };
}
