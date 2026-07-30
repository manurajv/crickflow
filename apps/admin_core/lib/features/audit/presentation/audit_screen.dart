import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../providers/audit_providers.dart';
import 'widgets/audit_chrome.dart';
import 'widgets/audit_detail_panel.dart';
import 'widgets/audit_filter_drawer.dart';
import 'widgets/audit_section_body.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'System',
        'Audit Logs',
      ];
      ref.read(auditHubControllerProvider.notifier).ensureBootstrapped();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    ref.read(auditHubControllerProvider.notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(auditHubControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditHubControllerProvider);
    final controller = ref.read(auditHubControllerProvider.notifier);
    final selected = ref.watch(selectedAuditLogProvider);
    final appType = ref.watch(adminAppTypeProvider);
    final isSuper = appType == AdminAppType.superAdmin;
    final showPanel = selected != null;

    return PermissionGate(
      permission: AdminPermission.canViewLogs,
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  showPanel ? 460 : 20,
                  32,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audit Center',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSuper
                                  ? 'Platform-wide activity monitoring and security audit trail'
                                  : 'Organization-scoped activity monitoring — platform logs are hidden',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      CfButton(
                        label: 'Refresh',
                        icon: Icons.refresh,
                        variant: CfButtonVariant.secondary,
                        onPressed:
                            state.isLoading ? null : controller.refresh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AuditSectionChips(
                    section: state.section,
                    onSelect: controller.setSection,
                  ),
                  const SizedBox(height: 16),
                  if (state.section != AuditHubSection.dashboard &&
                      state.section != AuditHubSection.timeline &&
                      state.section != AuditHubSection.exportCenter)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: _onQuery,
                            onSubmitted: (_) => controller.refresh(),
                            decoration: InputDecoration(
                              hintText:
                                  'Search user, action, target, IP, session…',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _search.clear();
                                        _onQuery('');
                                        controller.refresh();
                                      },
                                      icon: const Icon(Icons.clear),
                                    ),
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final next = await showAuditFilterDrawer(
                              context: context,
                              initial: state.filters.copyWith(
                                query: _search.text,
                              ),
                            );
                            if (next != null) {
                              _search.text = next.query;
                              await controller.applyFilters(next);
                            }
                          },
                          icon: Badge(
                            isLabelVisible: state.filters.hasActiveFilters,
                            smallSize: 8,
                            child: const Icon(Icons.filter_list),
                          ),
                          label: const Text('Filter'),
                        ),
                      ],
                    ),
                  if (state.section != AuditHubSection.dashboard &&
                      state.section != AuditHubSection.timeline &&
                      state.section != AuditHubSection.exportCenter)
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
                                onPressed: controller.refresh,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (state.isLoading && !state.bootstrapped)
                    const SizedBox(
                      height: 240,
                      child: CfLoadingState(message: 'Loading audit center…'),
                    )
                  else
                    const AuditSectionBody(),
                ],
              ),
            ),
          ),
          if (showPanel)
            Align(
              alignment: Alignment.centerRight,
              child: AuditDetailPanel(
                log: selected,
                onClose: () => controller.selectLog(null),
              ),
            ),
        ],
      ),
    );
  }
}
