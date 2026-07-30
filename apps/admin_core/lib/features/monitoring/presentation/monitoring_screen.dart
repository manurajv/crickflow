import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../providers/monitoring_providers.dart';
import 'widgets/monitoring_section_body.dart';
import 'widgets/monitoring_toolbar.dart';

class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'System',
        'Monitoring',
      ];
      ref.read(monitoringHubControllerProvider.notifier).ensureBootstrapped();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monitoringHubControllerProvider);
    final controller = ref.read(monitoringHubControllerProvider.notifier);
    final repo = ref.watch(monitoringRepositoryProvider);
    final appType = ref.watch(adminAppTypeProvider);
    final isSuperAdmin = appType == AdminAppType.superAdmin;
    final errors = state.filteredErrors(repo);

    return PermissionGate(
      permission: AdminPermission.canViewSystemHealth,
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'System Operations Center',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuperAdmin
                  ? 'Platform health & Firebase service monitoring (read-only)'
                  : 'Organization-scoped health only — no global infrastructure metrics',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            MonitoringSectionChips(
              section: state.section,
              onChanged: (s) async {
                await controller.setSection(s);
                ref.read(breadcrumbProvider.notifier).state = [
                  'System',
                  'Monitoring',
                  s.label,
                ];
              },
            ),
            const SizedBox(height: 12),
            MonitoringToolbar(
              searchController: _search,
              onQueryChanged: controller.setQuery,
              filterActive: state.filters.hasActiveFilters,
              refreshing: state.isLoading,
              onFilter: () async {
                final next = await showMonitoringFilterDrawer(
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
            if (state.isLoading && state.snapshot == null)
              const SizedBox(
                height: 320,
                child: CfLoadingState(message: 'Loading system health…'),
              )
            else if (state.snapshot != null)
              MonitoringSectionBody(
                section: state.section,
                snapshot: state.snapshot!,
                filteredErrors: errors,
                searchQuery: state.filters.query,
              )
            else
              const SizedBox(
                height: 200,
                child: Center(child: Text('No monitoring data')),
              ),
          ],
        ),
      ),
    );
  }
}
