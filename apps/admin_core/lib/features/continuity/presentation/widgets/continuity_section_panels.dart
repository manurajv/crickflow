import 'package:flutter/material.dart';

import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_status_badge.dart';
import '../../models/continuity_enums.dart';
import '../../models/managed_continuity.dart';
import 'continuity_chrome.dart';

class ContinuityDashboardPanel extends StatelessWidget {
  const ContinuityDashboardPanel({
    super.key,
    required this.summary,
    required this.backups,
    required this.onQueueFull,
  });

  final ContinuitySummary summary;
  final List<ManagedContinuityBackup> backups;
  final VoidCallback onQueueFull;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContinuitySummaryCards(summary: summary),
        const SizedBox(height: 16),
        CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safeguards',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Never auto-restores or overwrites production data from this UI.\n'
                '• Backup actions write metadata for future Google Cloud / export workers.\n'
                '• Restores require preview + explicit Super Admin confirmation.\n'
                '• Recommend backup before deploy, migration, bulk delete, and config changes.',
              ),
              const SizedBox(height: 12),
              CfButton(
                label: 'Queue full-platform metadata backup',
                onPressed: onQueueFull,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Recent backups',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (backups.isEmpty)
          const CfEmptyState(
            icon: Icons.backup_outlined,
            title: 'No backup metadata yet',
            message: 'Queue a backup to create the first history row.',
          )
        else
          for (final b in backups.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${b.type.label} · ${b.id}'),
              subtitle: Text(
                '${b.environment} · ${continuityFormatTime(b.createdAt)}',
              ),
              trailing: CfStatusBadge(
                label: b.status.label,
                tone: continuityStatusTone(b.status),
              ),
            ),
      ],
    );
  }
}

class ContinuityBackupTypePanel extends StatelessWidget {
  const ContinuityBackupTypePanel({
    super.key,
    required this.title,
    required this.description,
    required this.type,
    required this.backups,
    required this.onQueue,
  });

  final String title;
  final String description;
  final ContinuityBackupType type;
  final List<ManagedContinuityBackup> backups;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final filtered = backups.where((b) => b.type == type).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(description),
              const SizedBox(height: 12),
              CfButton(label: 'Queue metadata backup', onPressed: onQueue),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          CfEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No ${type.label} backups',
            message: 'Queued jobs appear here after creation.',
          )
        else
          ContinuityBackupTable(
            backups: filtered,
            onValidate: null,
            onArchive: null,
          ),
      ],
    );
  }
}

class ContinuityBackupTable extends StatelessWidget {
  const ContinuityBackupTable({
    super.key,
    required this.backups,
    this.onValidate,
    this.onArchive,
  });

  final List<ManagedContinuityBackup> backups;
  final void Function(ManagedContinuityBackup backup, bool ok)? onValidate;
  final void Function(ManagedContinuityBackup backup)? onArchive;

  @override
  Widget build(BuildContext context) {
    if (backups.isEmpty) {
      return const CfEmptyState(
        icon: Icons.history,
        title: 'No backup history',
        message: 'Create a backup to populate this table.',
      );
    }
    return CfCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Backup ID')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Created By')),
            DataColumn(label: Text('Environment')),
            DataColumn(label: Text('Created')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Size')),
            DataColumn(label: Text('Duration')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final b in backups)
              DataRow(
                cells: [
                  DataCell(Text(b.id, style: const TextStyle(fontSize: 12))),
                  DataCell(Text(b.type.label)),
                  DataCell(Text(b.createdByEmail.isEmpty ? '—' : b.createdByEmail)),
                  DataCell(Text(b.environment)),
                  DataCell(Text(continuityFormatTime(b.createdAt))),
                  DataCell(
                    CfStatusBadge(
                      label: b.status.label,
                      tone: continuityStatusTone(b.status),
                    ),
                  ),
                  DataCell(Text(b.estimatedSizeLabel)),
                  DataCell(Text(b.durationLabel)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onValidate != null) ...[
                          TextButton(
                            onPressed: () => onValidate!(b, true),
                            child: const Text('Validate'),
                          ),
                          TextButton(
                            onPressed: () => onValidate!(b, false),
                            child: const Text('Fail'),
                          ),
                        ],
                        if (onArchive != null)
                          TextButton(
                            onPressed: () => onArchive!(b),
                            child: const Text('Archive'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class ContinuityRestorePanel extends StatelessWidget {
  const ContinuityRestorePanel({
    super.key,
    required this.restores,
    required this.backups,
    required this.onRequestPreview,
  });

  final List<ManagedContinuityRestore> restores;
  final List<ManagedContinuityBackup> backups;
  final VoidCallback onRequestPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Restore Center',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Restores are preview-only. No automatic overwrite of production data. '
                'Future apply requires typed confirmation and an approved Cloud worker.',
              ),
              const SizedBox(height: 12),
              CfButton(
                label: 'Request restore preview',
                variant: CfButtonVariant.danger,
                onPressed: backups.isEmpty ? null : onRequestPreview,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (restores.isEmpty)
          const CfEmptyState(
            icon: Icons.restore_outlined,
            title: 'No restore requests',
            message: 'Preview requests will list validation notes here.',
          )
        else
          for (final r in restores)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r.scope.label} · ${r.id}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      CfStatusBadge(
                        label: r.status.label,
                        tone: continuityStatusTone(r.status),
                      ),
                    ],
                  ),
                  Text('Backup: ${r.backupId}'),
                  Text('Preview only: ${r.previewOnly}'),
                  if (r.reason.isNotEmpty) Text('Reason: ${r.reason}'),
                  const SizedBox(height: 6),
                  for (final n in r.validationNotes) Text('• $n'),
                ],
              ),
            ),
            ),
      ],
    );
  }
}

class ContinuityPlansPanel extends StatelessWidget {
  const ContinuityPlansPanel({super.key, required this.plans});

  final List<ManagedRecoveryPlan> plans;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final p in plans)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CfCard(
            child: ExpansionTile(
              title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('ETA: ${p.estimatedRecoveryTime}'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.summary),
                      const SizedBox(height: 8),
                      Text('Roles: ${p.responsibleRoles.join(', ')}'),
                      const SizedBox(height: 8),
                      for (var i = 0; i < p.steps.length; i++)
                        Text('${i + 1}. ${p.steps[i]}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
      ],
    );
  }
}

class ContinuityMigrationPanel extends StatelessWidget {
  const ContinuityMigrationPanel({
    super.key,
    required this.title,
    required this.body,
    required this.migrations,
    required this.onDryRun,
  });

  final String title;
  final String body;
  final List<ManagedContinuityMigration> migrations;
  final VoidCallback onDryRun;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(body),
              const SizedBox(height: 12),
              CfButton(label: 'Queue dry-run', onPressed: onDryRun),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (migrations.isEmpty)
          const CfEmptyState(
            icon: Icons.swap_horiz,
            title: 'No migration jobs',
            message: 'Dry-runs appear here. Never auto-applies.',
          )
        else
          for (final m in migrations)
            ListTile(
              title: Text(m.title.isEmpty ? m.kind.label : m.title),
              subtitle: Text(
                '${m.kind.label} · dryRun=${m.dryRun} · ${m.status.label}',
              ),
              trailing: CfStatusBadge(
                label: m.status.label,
                tone: continuityStatusTone(m.status),
              ),
            ),
      ],
    );
  }
}

class ContinuityHealthPanel extends StatelessWidget {
  const ContinuityHealthPanel({
    super.key,
    required this.checks,
    required this.onRecord,
  });

  final List<ContinuityHealthCheck> checks;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify critical systems after incidents or restores. '
                'Status starts as Unknown until operators confirm in console.',
              ),
              const SizedBox(height: 12),
              CfButton(label: 'Record checklist review', onPressed: onRecord),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final c in checks)
          ListTile(
            leading: Icon(
              Icons.monitor_heart_outlined,
              color: switch (c.status) {
                ContinuityHealthStatus.healthy => Colors.green,
                ContinuityHealthStatus.critical => Colors.red,
                ContinuityHealthStatus.degraded => Colors.orange,
                ContinuityHealthStatus.unknown => Colors.grey,
              },
            ),
            title: Text(c.label),
            subtitle: Text(c.note),
            trailing: Text(c.status.label),
          ),
      ],
    );
  }
}

class ContinuityTimelinePanel extends StatelessWidget {
  const ContinuityTimelinePanel({super.key, required this.events});

  final List<ContinuityTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const CfEmptyState(
        icon: Icons.timeline,
        title: 'No continuity events',
        message: 'Backup, restore, and migration actions appear here.',
      );
    }
    return Column(
      children: [
        for (final e in events)
          ListTile(
            leading: const Icon(Icons.circle, size: 10),
            title: Text(e.title),
            subtitle: Text(
              '${e.kind.label}'
              '${e.subtitle.isEmpty ? '' : ' · ${e.subtitle}'}'
              ' · ${continuityFormatTime(e.createdAt)}',
            ),
          ),
      ],
    );
  }
}

class ContinuityDrPanel extends StatelessWidget {
  const ContinuityDrPanel({super.key, required this.summary});

  final ContinuitySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContinuitySummaryCards(summary: summary),
        const SizedBox(height: 16),
        CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Disaster Recovery',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text('Recovery score: ${summary.recoveryScore}/100'),
              Text('Readiness: ${summary.recoveryReadiness}'),
              const SizedBox(height: 8),
              const Text(
                'Architecture supports future Google Cloud Backup, multi-region '
                'replication, and BigQuery export without redesigning this hub. '
                'Automation is intentionally off.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
