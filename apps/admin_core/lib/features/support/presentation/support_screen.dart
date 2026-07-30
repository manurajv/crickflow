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
import '../models/support_enums.dart';
import '../providers/support_providers.dart';
import 'widgets/support_content_panels.dart';
import 'widgets/support_summary_cards.dart';
import 'widgets/support_ticket_detail_panel.dart';
import 'widgets/support_tickets_table.dart';
import 'widgets/support_toolbar.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'System',
        'Support Center',
      ];
      ref.read(supportHubControllerProvider.notifier).ensureBootstrapped();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool _isContentSection(SupportHubSection s) =>
      s == SupportHubSection.knowledgeBase ||
      s == SupportHubSection.faq ||
      s == SupportHubSection.announcements ||
      s == SupportHubSection.csat ||
      s == SupportHubSection.reports;

  bool _showsTicketTable(SupportHubSection s) =>
      !_isContentSection(s) || s == SupportHubSection.dashboard;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportHubControllerProvider);
    final controller = ref.read(supportHubControllerProvider.notifier);
    final appType = ref.watch(adminAppTypeProvider);
    final isSuperAdmin = appType == AdminAppType.superAdmin;
    final selected = state.selected;
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    return PermissionGate(
      permission: AdminPermission.canManageSupport,
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'Support Center',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuperAdmin
                  ? 'Platform help desk — all organizations'
                  : 'Organization-scoped tickets only — never private user chats',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SupportSectionChips(
              section: state.section,
              onChanged: (s) async {
                await controller.setSection(s);
                ref.read(breadcrumbProvider.notifier).state = [
                  'System',
                  'Support Center',
                  s.label,
                ];
              },
            ),
            const SizedBox(height: 12),
            SupportToolbar(
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
                final next = await showSupportFilterDrawer(
                  context: context,
                  initial: state.filters,
                  isSuperAdmin: isSuperAdmin,
                );
                if (next != null) await controller.applyFilters(next);
              },
              onRefresh: () => controller.refresh(force: true),
              onCreate: () async {
                await showCreateTicketDialog(
                  context: context,
                  onSubmit: ({
                    required subject,
                    required description,
                    required kind,
                    required category,
                    required priority,
                    stepsToReproduce = '',
                    logs = '',
                    rating,
                  }) async {
                    await controller.createTicket(
                      subject: subject,
                      description: description,
                      kind: kind,
                      category: category,
                      priority: priority,
                      stepsToReproduce: stepsToReproduce,
                      logs: logs,
                      rating: rating,
                    );
                  },
                );
              },
              onExport: () async {
                final csv = controller.exportCsv();
                if (csv.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nothing to export')),
                  );
                  return;
                }
                await showSupportExportSheet(context, csv);
              },
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
            if (state.section == SupportHubSection.dashboard ||
                state.section == SupportHubSection.csat) ...[
              SupportSummaryCards(summary: state.summary),
              const SizedBox(height: 16),
            ],
            if (state.isLoading &&
                state.tickets.isEmpty &&
                !_isContentSection(state.section))
              const SizedBox(
                height: 280,
                child: CfLoadingState(message: 'Loading support center…'),
              )
            else if (_isContentSection(state.section) &&
                state.section != SupportHubSection.dashboard)
              SupportContentPanels(
                section: state.section,
                kbArticles: state.kbArticles,
                faqs: state.faqs,
                announcements: state.announcements,
                summary: state.summary,
                reports: state.reports,
                onSaveKb: controller.saveKb,
                onSaveFaq: controller.saveFaq,
                onSaveAnnouncement: controller.saveAnnouncement,
              )
            else if (_showsTicketTable(state.section))
              LayoutBuilder(
                builder: (context, c) {
                  final table = SupportTicketsTable(
                    tickets: state.tickets,
                    sort: state.sort,
                    isLoading: state.isLoading,
                    hasMore: state.hasMore,
                    isLoadingMore: state.isLoadingMore,
                    selectedId: state.selectedId,
                    onSort: controller.setSort,
                    onSelect: controller.selectTicket,
                    onLoadMore: controller.loadMore,
                  );
                  if (!wide || selected == null) {
                    return Column(
                      children: [
                        table,
                        if (selected != null) ...[
                          const SizedBox(height: 16),
                          SupportTicketDetailPanel(
                            ticket: selected,
                            messages: state.messages,
                          ),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: table),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: SupportTicketDetailPanel(
                          ticket: selected,
                          messages: state.messages,
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
