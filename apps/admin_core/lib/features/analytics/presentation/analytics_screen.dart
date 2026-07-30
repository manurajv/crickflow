import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/analytics_enums.dart';
import '../providers/analytics_providers.dart';
import 'widgets/analytics_section_body.dart';
import 'widgets/analytics_toolbar.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'System',
        'Analytics',
      ];
      ref.read(analyticsHubControllerProvider.notifier).ensureBootstrapped();
    });
  }

  Future<void> _exportCsv() async {
    final csv =
        ref.read(analyticsHubControllerProvider.notifier).exportCsv();
    if (csv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export yet')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV copied to clipboard — paste into Sheets / Excel'),
      ),
    );
  }

  void _exportStub(AnalyticsExportFormat format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${format.label} export is prepared for later — use CSV for now',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsHubControllerProvider);
    final controller = ref.read(analyticsHubControllerProvider.notifier);
    final appType = ref.watch(adminAppTypeProvider);
    final isSuperAdmin = appType == AdminAppType.superAdmin;

    return PermissionGate(
      permission: AdminPermission.canViewAnalytics,
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'Analytics & Reports',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuperAdmin
                  ? 'Platform-wide insights (organization filter available)'
                  : 'Organization-scoped insights only — no global platform data',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AnalyticsSectionChips(
              section: state.section,
              onChanged: (s) async {
                await controller.setSection(s);
                ref.read(breadcrumbProvider.notifier).state = [
                  'System',
                  'Analytics',
                  s.label,
                ];
              },
            ),
            const SizedBox(height: 12),
            AnalyticsToolbar(
              period: state.filters.period,
              onPeriodChanged: controller.setPeriod,
              filterActive: state.filters.hasActiveFilters,
              refreshing: state.isLoading,
              onFilter: () async {
                final next = await showAnalyticsFilterDrawer(
                  context: context,
                  initial: state.filters,
                  isSuperAdmin: isSuperAdmin,
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
                child: CfLoadingState(message: 'Loading analytics…'),
              )
            else if (state.snapshot != null)
              AnalyticsSectionBody(
                section: state.section,
                snapshot: state.snapshot!,
                reportKind: state.reportKind,
                onReportKindChanged: controller.setReportKind,
                onExportCsv: _exportCsv,
                onExportStub: _exportStub,
              )
            else
              const SizedBox(
                height: 200,
                child: Center(child: Text('No analytics data')),
              ),
          ],
        ),
      ),
    );
  }
}
