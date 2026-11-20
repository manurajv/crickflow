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
                  ? 'Read-only. This console shows stored release and environment metadata; it does not deploy, roll back, or change infrastructure.\n'
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
          canEdit: false,
          onSave: (_) {},
        );
      case DevOpsHubSection.releases:
      case DevOpsHubSection.versionHistory:
        return DevOpsReleasesPanel(
          releases: state.releases,
          canManage: false,
          onCreate: () {},
          onDuplicate: (_) {},
          onStatus: (_, _) {},
          onSelect: controller.selectRelease,
          selectedId: state.selectedReleaseId,
        );
      case DevOpsHubSection.releaseNotes:
        return DevOpsReleasesPanel(
          releases: state.releases,
          canManage: false,
          onCreate: () {},
          onDuplicate: (_) {},
          onStatus: (_, _) {},
          onSelect: controller.selectRelease,
          selectedId: state.selectedReleaseId,
          showNotes: true,
        );
      case DevOpsHubSection.buildMonitor:
        return DevOpsBuildsPanel(builds: state.builds);
      case DevOpsHubSection.featureRollout:
        return DevOpsRolloutsPanel(
          rollouts: state.rollouts,
          canManage: false,
          onAdd: () {},
          onPause: (_) {},
          onPercent: (_, _) {},
        );
      case DevOpsHubSection.rollbackCenter:
        return DevOpsRollbackPanel(
          plans: state.rollbacks,
          canManage: false,
          onPrepare: () {},
        );
      case DevOpsHubSection.deploymentLogs:
        return DevOpsDeploymentsPanel(logs: state.deployments);
      case DevOpsHubSection.envVariables:
        return DevOpsEnvVarsPanel(
          vars: state.envVars,
          canManage: false,
          onAdd: () {},
        );
      case DevOpsHubSection.domains:
        return DevOpsDomainsPanel(domains: state.domains);
      case DevOpsHubSection.timeline:
        return DevOpsTimelinePanel(events: state.timeline);
      case DevOpsHubSection.qualityGates:
        return DevOpsQualityGatesPanel(
          settings: state.settings,
          canEdit: false,
          onToggle: (_, _) {},
        );
    }
  }
}
