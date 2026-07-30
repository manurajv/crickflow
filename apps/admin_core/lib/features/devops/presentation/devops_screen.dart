import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/config/admin_env_config.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/devops_enums.dart';
import '../models/managed_devops.dart';
import '../providers/devops_providers.dart';
import 'widgets/devops_chrome.dart';
import 'widgets/devops_section_panels.dart';

class DevOpsScreen extends ConsumerStatefulWidget {
  const DevOpsScreen({super.key});

  @override
  ConsumerState<DevOpsScreen> createState() => _DevOpsScreenState();
}

class _DevOpsScreenState extends ConsumerState<DevOpsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'System',
        'DevOps & Releases',
      ];
      ref.read(devopsHubControllerProvider.notifier).ensureBootstrapped();
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
    final state = ref.watch(devopsHubControllerProvider);
    final controller = ref.read(devopsHubControllerProvider.notifier);
    final isSuperAdmin =
        ref.watch(adminAppTypeProvider) == AdminAppType.superAdmin;

    return PermissionGate(
      permission: AdminPermission.canManageDeployments,
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'DevOps & Release Center',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuperAdmin
                  ? 'Environments, releases, and deployment monitoring — never deploys automatically\n'
                      'Build: ${AdminEnvConfig.displayBanner} · CI: see docs/developer/cicd.md'
                  : 'Super Admin only',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            DevOpsSectionChips(
              section: state.section,
              onChanged: (s) async {
                await controller.setSection(s);
                ref.read(breadcrumbProvider.notifier).state = [
                  'System',
                  'DevOps & Releases',
                  s.label,
                ];
              },
            ),
            const SizedBox(height: 12),
            DevOpsToolbar(
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
                final next = await showDevOpsFilterDrawer(
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
            if (state.isLoading && state.section == DevOpsHubSection.dashboard)
              const SizedBox(
                height: 280,
                child: CfLoadingState(message: 'Loading DevOps Center…'),
              )
            else ...[
              if (state.section == DevOpsHubSection.dashboard) ...[
                DevOpsSummaryCards(summary: state.summary),
                const SizedBox(height: 16),
              ],
              _sectionBody(state: state, controller: controller),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionBody({
    required DevOpsHubState state,
    required DevOpsHubController controller,
  }) {
    switch (state.section) {
      case DevOpsHubSection.dashboard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent releases',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            DevOpsReleasesPanel(
              releases: state.releases,
              canManage: false,
              onCreate: () {},
              onDuplicate: (_) {},
              onStatus: (_, _) {},
              onSelect: controller.selectRelease,
              selectedId: state.selectedReleaseId,
            ),
            const SizedBox(height: 16),
            Text(
              'Timeline',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            DevOpsTimelinePanel(events: state.timeline),
          ],
        );
      case DevOpsHubSection.environments:
        return DevOpsEnvironmentsPanel(
          settings: state.settings,
          canEdit: true,
          onSave: controller.saveSettings,
        );
      case DevOpsHubSection.releases:
      case DevOpsHubSection.versionHistory:
        return DevOpsReleasesPanel(
          releases: state.releases,
          canManage: true,
          onCreate: () => _createRelease(controller),
          onDuplicate: controller.duplicateRelease,
          onStatus: controller.setReleaseStatus,
          onSelect: controller.selectRelease,
          selectedId: state.selectedReleaseId,
        );
      case DevOpsHubSection.releaseNotes:
        return DevOpsReleasesPanel(
          releases: state.releases,
          canManage: true,
          onCreate: () => _createRelease(controller),
          onDuplicate: controller.duplicateRelease,
          onStatus: controller.setReleaseStatus,
          onSelect: controller.selectRelease,
          selectedId: state.selectedReleaseId,
          showNotes: true,
        );
      case DevOpsHubSection.buildMonitor:
        return DevOpsBuildsPanel(builds: state.builds);
      case DevOpsHubSection.featureRollout:
        return DevOpsRolloutsPanel(
          rollouts: state.rollouts,
          canManage: true,
          onAdd: () => _addRollout(controller),
          onPause: (r) => controller.saveRollout(
            ManagedRollout(
              id: r.id,
              featureKey: r.featureKey,
              title: r.title,
              percent: r.percent,
              status: DevOpsRolloutStatus.paused,
              environment: r.environment,
              note: r.note,
            ),
          ),
          onPercent: (r, p) => controller.saveRollout(
            ManagedRollout(
              id: r.id,
              featureKey: r.featureKey,
              title: r.title,
              percent: p,
              status: DevOpsRolloutStatus.active,
              environment: r.environment,
              note: r.note,
            ),
          ),
        );
      case DevOpsHubSection.rollbackCenter:
        return DevOpsRollbackPanel(
          plans: state.rollbacks,
          canManage: true,
          onPrepare: () => _prepareRollback(controller, state),
        );
      case DevOpsHubSection.deploymentLogs:
        return DevOpsDeploymentsPanel(logs: state.deployments);
      case DevOpsHubSection.envVariables:
        return DevOpsEnvVarsPanel(
          vars: state.envVars,
          canManage: true,
          onAdd: () => _addEnvMeta(controller),
        );
      case DevOpsHubSection.domains:
        return DevOpsDomainsPanel(domains: state.domains);
      case DevOpsHubSection.timeline:
        return DevOpsTimelinePanel(events: state.timeline);
      case DevOpsHubSection.qualityGates:
        return DevOpsQualityGatesPanel(
          settings: state.settings,
          canEdit: true,
          onToggle: (gate, passed) {
            final gates = [
              for (final g in (state.settings.qualityGates.isEmpty
                  ? DevOpsPlatformSettings.defaultQualityGates
                  : state.settings.qualityGates))
                if (g.id == gate.id)
                  QualityGateItem(
                    id: g.id,
                    label: g.label,
                    passed: passed,
                    note: g.note,
                  )
                else
                  g,
            ];
            controller.saveSettings(
              DevOpsPlatformSettings(
                activeEnvironment: state.settings.activeEnvironment,
                currentVersion: state.settings.currentVersion,
                latestVersion: state.settings.latestVersion,
                firebaseProjectId: state.settings.firebaseProjectId,
                hostingNote: state.settings.hostingNote,
                qualityGates: gates,
              ),
            );
          },
        );
    }
  }

  Future<void> _createRelease(DevOpsHubController controller) async {
    final version = TextEditingController();
    final title = TextEditingController();
    final summary = TextEditingController();
    final features = TextEditingController();
    final fixes = TextEditingController();
    var type = DevOpsReleaseType.patch;
    var env = DevOpsEnvironment.staging;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Create release'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: version,
                    decoration: const InputDecoration(
                      labelText: 'Version',
                      hintText: '1.2.0',
                    ),
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: summary,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Summary'),
                  ),
                  TextField(
                    controller: features,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'New features (one per line)',
                    ),
                  ),
                  TextField(
                    controller: fixes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Bug fixes (one per line)',
                    ),
                  ),
                  DropdownButtonFormField<DevOpsReleaseType>(
                    // ignore: deprecated_member_use
                    value: type,
                    items: [
                      for (final t in DevOpsReleaseType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) => setLocal(() => type = v ?? type),
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),
                  DropdownButtonFormField<DevOpsEnvironment>(
                    // ignore: deprecated_member_use
                    value: env,
                    items: [
                      for (final e in DevOpsEnvironment.values)
                        DropdownMenuItem(value: e, child: Text(e.label)),
                    ],
                    onChanged: (v) => setLocal(() => env = v ?? env),
                    decoration: const InputDecoration(labelText: 'Environment'),
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create draft'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && version.text.trim().isNotEmpty) {
      await controller.createRelease(
        ManagedRelease(
          id: '',
          version: version.text.trim(),
          title: title.text.trim().isEmpty
              ? version.text.trim()
              : title.text.trim(),
          summary: summary.text.trim(),
          newFeatures: features.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          bugFixes: fixes.text
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          releaseType: type,
          status: DevOpsReleaseStatus.draft,
          environment: env,
        ),
      );
    }
    version.dispose();
    title.dispose();
    summary.dispose();
    features.dispose();
    fixes.dispose();
  }

  Future<void> _addRollout(DevOpsHubController controller) async {
    final key = TextEditingController();
    final title = TextEditingController();
    var percent = DevOpsRolloutPercent.internal;
    var env = DevOpsEnvironment.staging;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New rollout plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: key,
                decoration: const InputDecoration(labelText: 'Feature key'),
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              DropdownButtonFormField<DevOpsRolloutPercent>(
                // ignore: deprecated_member_use
                value: percent,
                items: [
                  for (final p in DevOpsRolloutPercent.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setLocal(() => percent = v ?? percent),
              ),
              DropdownButtonFormField<DevOpsEnvironment>(
                // ignore: deprecated_member_use
                value: env,
                items: [
                  for (final e in DevOpsEnvironment.values)
                    DropdownMenuItem(value: e, child: Text(e.label)),
                ],
                onChanged: (v) => setLocal(() => env = v ?? env),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && key.text.trim().isNotEmpty) {
      await controller.saveRollout(
        ManagedRollout(
          id: '',
          featureKey: key.text.trim(),
          title: title.text.trim().isEmpty ? key.text.trim() : title.text.trim(),
          percent: percent,
          status: DevOpsRolloutStatus.planned,
          environment: env,
        ),
      );
    }
    key.dispose();
    title.dispose();
  }

  Future<void> _prepareRollback(
    DevOpsHubController controller,
    DevOpsHubState state,
  ) async {
    final target = TextEditingController(text: state.settings.currentVersion);
    final from = TextEditingController(text: state.settings.latestVersion);
    final reason = TextEditingController();
    var env = DevOpsEnvironment.production;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Prepare rollback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Architecture only — does not roll back Hosting or Functions.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              TextField(
                controller: from,
                decoration: const InputDecoration(labelText: 'From version'),
              ),
              TextField(
                controller: target,
                decoration: const InputDecoration(labelText: 'Target version'),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              DropdownButtonFormField<DevOpsEnvironment>(
                // ignore: deprecated_member_use
                value: env,
                items: [
                  for (final e in DevOpsEnvironment.values)
                    DropdownMenuItem(value: e, child: Text(e.label)),
                ],
                onChanged: (v) => setLocal(() => env = v ?? env),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Prepare'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && target.text.trim().isNotEmpty) {
      await controller.prepareRollback(
        targetVersion: target.text.trim(),
        fromVersion: from.text.trim(),
        reason: reason.text.trim(),
        environment: env,
      );
    }
    target.dispose();
    from.dispose();
    reason.dispose();
  }

  Future<void> _addEnvMeta(DevOpsHubController controller) async {
    final key = TextEditingController();
    var env = DevOpsEnvironment.staging;
    var configured = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Register env key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Stores the key name only. Values are never saved.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              TextField(
                controller: key,
                decoration: const InputDecoration(labelText: 'Key name'),
              ),
              DropdownButtonFormField<DevOpsEnvironment>(
                // ignore: deprecated_member_use
                value: env,
                items: [
                  for (final e in DevOpsEnvironment.values)
                    DropdownMenuItem(value: e, child: Text(e.label)),
                ],
                onChanged: (v) => setLocal(() => env = v ?? env),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Configured'),
                value: configured,
                onChanged: (v) => setLocal(() => configured = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && key.text.trim().isNotEmpty) {
      await controller.upsertEnvVarMeta(
        key: key.text.trim(),
        environment: env,
        configured: configured,
      );
    }
    key.dispose();
  }
}
