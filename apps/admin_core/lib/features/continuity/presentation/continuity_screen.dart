import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/config/admin_env_config.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_card.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/continuity_enums.dart';
import '../models/managed_continuity.dart';
import '../providers/continuity_providers.dart';
import 'widgets/continuity_chrome.dart';
import 'widgets/continuity_section_panels.dart';

class ContinuityScreen extends ConsumerStatefulWidget {
  const ContinuityScreen({super.key});

  @override
  ConsumerState<ContinuityScreen> createState() => _ContinuityScreenState();
}

class _ContinuityScreenState extends ConsumerState<ContinuityScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'System',
        'Continuity & DR',
      ];
      ref.read(continuityHubControllerProvider.notifier).ensureBootstrapped();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(continuityHubControllerProvider);
    final controller = ref.read(continuityHubControllerProvider.notifier);
    final isSuperAdmin =
        ref.watch(adminAppTypeProvider) == AdminAppType.superAdmin;

    return PermissionGate(
      permission: AdminPermission.canManageContinuity,
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'Backup, Disaster Recovery & Continuity',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuperAdmin
                  ? 'Metadata workflows only — never auto-restores or overwrites production\n'
                      'Env: ${AdminEnvConfig.displayBanner} · See docs/developer/continuity.md'
                  : 'Super Admin only',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ContinuitySectionChips(
              section: state.section,
              onChanged: (s) async {
                await controller.setSection(s);
                ref.read(breadcrumbProvider.notifier).state = [
                  'System',
                  'Continuity & DR',
                  s.label,
                ];
              },
            ),
            const SizedBox(height: 12),
            ContinuityToolbar(
              searchController: _search,
              onQueryChanged: (q) {
                controller.setQuery(q);
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  controller.refresh();
                });
              },
              filterActive: state.filters.hasActiveFilters,
              refreshing: state.isLoading,
              onFilter: () async {
                final next = await showContinuityFilterDrawer(
                  context: context,
                  initial: state.filters,
                );
                if (next != null) await controller.applyFilters(next);
              },
              onRefresh: () => controller.refresh(force: true),
            ),
            const SizedBox(height: 16),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: Text(state.error!)),
                        CfButton(
                          label: 'Retry',
                          onPressed: () => controller.refresh(force: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (state.isLoading &&
                state.section == ContinuityHubSection.dashboard)
              const SizedBox(
                height: 280,
                child: CfLoadingState(message: 'Loading Continuity Center…'),
              )
            else
              _sectionBody(state: state, controller: controller),
          ],
        ),
      ),
    );
  }

  Widget _sectionBody({
    required ContinuityHubState state,
    required ContinuityHubController controller,
  }) {
    switch (state.section) {
      case ContinuityHubSection.dashboard:
        return ContinuityDashboardPanel(
          summary: state.summary,
          backups: state.backups,
          onQueueFull: () =>
              controller.queueBackup(ContinuityBackupType.fullPlatform),
        );
      case ContinuityHubSection.firestoreBackup:
        return ContinuityBackupTypePanel(
          title: 'Firestore Backup',
          description:
              'Queues Firestore export metadata for a future Cloud worker. '
              'Does not copy documents from this UI.',
          type: ContinuityBackupType.firestore,
          backups: state.backups,
          onQueue: () => controller.queueBackup(ContinuityBackupType.firestore),
        );
      case ContinuityHubSection.storageBackup:
        return ContinuityBackupTypePanel(
          title: 'Storage Backup',
          description:
              'Queues Storage snapshot metadata. Objects are never downloaded '
              'or rewritten from the admin client.',
          type: ContinuityBackupType.storage,
          backups: state.backups,
          onQueue: () => controller.queueBackup(ContinuityBackupType.storage),
        );
      case ContinuityHubSection.configBackup:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContinuityBackupTypePanel(
              title: 'Configuration & Remote Config Backup',
              description:
                  'Covers platform settings, Remote Config, CMS, roles, '
                  'permissions, feature flags, and app configuration metadata. '
                  'Secrets are never included.',
              type: ContinuityBackupType.platformSettings,
              backups: state.backups,
              onQueue: () =>
                  controller.queueBackup(ContinuityBackupType.platformSettings),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in [
                  ContinuityBackupType.remoteConfig,
                  ContinuityBackupType.cms,
                  ContinuityBackupType.roles,
                  ContinuityBackupType.permissions,
                  ContinuityBackupType.featureFlags,
                  ContinuityBackupType.appConfig,
                ])
                  CfButton(
                    label: 'Queue ${t.label}',
                    variant: CfButtonVariant.secondary,
                    onPressed: () => controller.queueBackup(t),
                  ),
              ],
            ),
          ],
        );
      case ContinuityHubSection.backupHistory:
        return ContinuityBackupTable(
          backups: state.backups,
          onValidate: (b, ok) => controller.validateBackup(b, ok),
          onArchive: (b) => _confirmArchive(controller, b),
        );
      case ContinuityHubSection.restoreCenter:
        return ContinuityRestorePanel(
          restores: state.restores,
          backups: state.backups,
          onRequestPreview: () => _requestRestorePreview(controller, state),
        );
      case ContinuityHubSection.recoveryPlans:
        return ContinuityPlansPanel(plans: state.plans);
      case ContinuityHubSection.disasterRecovery:
        return ContinuityDrPanel(summary: state.summary);
      case ContinuityHubSection.migrationCenter:
        return ContinuityMigrationPanel(
          title: 'Migration Center',
          body:
              'Architecture for schema, collection, configuration, and version '
              'migrations. Jobs default to dry-run. Never auto-applies.',
          migrations: state.migrations,
          onDryRun: () => _queueMigration(
            controller,
            ContinuityMigrationKind.schema,
            'Schema dry-run',
          ),
        );
      case ContinuityHubSection.importCenter:
        return const CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import Center',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Architecture ready for JSON, CSV, Excel, configuration files, '
                'and settings. No importer runs from this UI yet. Future workers '
                'must require Super Admin confirmation and validation before write.',
              ),
            ],
          ),
        );
      case ContinuityHubSection.exportCenter:
        return const CfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export Center',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Architecture ready for Firestore metadata, settings, '
                'configurations, users, organizations, teams, grounds, matches, '
                'audit logs, and analytics. Exports must never include API keys, '
                'OAuth tokens, or Firebase secrets.',
              ),
            ],
          ),
        );
      case ContinuityHubSection.healthVerification:
        return ContinuityHealthPanel(
          checks: state.health,
          onRecord: controller.recordHealth,
        );
      case ContinuityHubSection.timeline:
        return ContinuityTimelinePanel(events: state.timeline);
    }
  }

  Future<void> _confirmArchive(
    ContinuityHubController controller,
    ManagedContinuityBackup backup,
  ) async {
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive backup metadata?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soft-archives metadata for ${backup.id}. Does not delete cloud '
              'export objects. Type ARCHIVE to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              decoration: const InputDecoration(
                labelText: 'Confirmation',
                hintText: 'ARCHIVE',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (confirm.text.trim() == 'ARCHIVE') {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    confirm.dispose();
    if (ok == true) await controller.archiveBackup(backup);
  }

  Future<void> _requestRestorePreview(
    ContinuityHubController controller,
    ContinuityHubState state,
  ) async {
    if (state.backups.isEmpty) return;
    var backupId = state.backups.first.id;
    var scope = ContinuityRestoreScope.configuration;
    final reason = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Restore preview (safe)'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Creates a preview-only request. Production data is never '
                    'overwritten from this dialog.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: backupId,
                    decoration: const InputDecoration(labelText: 'Backup'),
                    items: [
                      for (final b in state.backups)
                        DropdownMenuItem(
                          value: b.id,
                          child: Text('${b.type.label} · ${b.id}'),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => backupId = v ?? backupId),
                  ),
                  DropdownButtonFormField<ContinuityRestoreScope>(
                    // ignore: deprecated_member_use
                    value: scope,
                    decoration: const InputDecoration(labelText: 'Scope'),
                    items: [
                      for (final s in ContinuityRestoreScope.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (v) => setLocal(() => scope = v ?? scope),
                  ),
                  TextField(
                    controller: reason,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason (required)',
                    ),
                  ),
                  TextField(
                    controller: confirm,
                    decoration: const InputDecoration(
                      labelText: 'Type PREVIEW to continue',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (confirm.text.trim() == 'PREVIEW' &&
                    reason.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Request preview'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await controller.requestRestorePreview(
        backupId: backupId,
        scope: scope,
        reason: reason.text.trim(),
      );
    }
    reason.dispose();
    confirm.dispose();
  }

  Future<void> _queueMigration(
    ContinuityHubController controller,
    ContinuityMigrationKind kind,
    String title,
  ) async {
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Queue migration dry-run'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Queues a dry-run for ${kind.label}. No production writes. '
              'Type DRYRUN to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              decoration: const InputDecoration(hintText: 'DRYRUN'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (confirm.text.trim() == 'DRYRUN') {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Queue'),
          ),
        ],
      ),
    );
    confirm.dispose();
    if (ok == true) {
      await controller.queueMigrationDryRun(kind: kind, title: title);
    }
  }
}
