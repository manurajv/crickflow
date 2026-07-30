import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/ai_ops_enums.dart';
import '../models/managed_ai_ops.dart';
import '../providers/ai_ops_providers.dart';
import 'widgets/ai_ops_section_panels.dart';
import 'widgets/ai_ops_summary_cards.dart';
import 'widgets/ai_ops_toolbar.dart';
import 'widgets/ai_recommendations_panel.dart';

class AiOpsScreen extends ConsumerStatefulWidget {
  const AiOpsScreen({super.key});

  @override
  ConsumerState<AiOpsScreen> createState() => _AiOpsScreenState();
}

class _AiOpsScreenState extends ConsumerState<AiOpsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  AiOpsSettings? _draftSettings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'System',
        'AI Operations',
      ];
      ref.read(aiOpsHubControllerProvider.notifier).ensureBootstrapped();
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
    final state = ref.watch(aiOpsHubControllerProvider);
    final controller = ref.read(aiOpsHubControllerProvider.notifier);
    final appType = ref.watch(adminAppTypeProvider);
    final isSuperAdmin = appType == AdminAppType.superAdmin;
    final actor = ref.watch(adminSessionProvider).adminUser;
    final settings = _draftSettings ?? state.settings;

    return PermissionGate(
      permission: AdminPermission.canManageAiOps,
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'AI Operations Center',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuperAdmin
                  ? 'Intelligence & automation hub — recommendations never auto-mutate data'
                  : 'Organization-scoped recommendations only — admin approval required',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AiOpsSectionChips(
              section: state.section,
              onChanged: (s) async {
                _draftSettings = null;
                await controller.setSection(s);
                ref.read(breadcrumbProvider.notifier).state = [
                  'System',
                  'AI Operations',
                  s.label,
                ];
              },
            ),
            const SizedBox(height: 12),
            AiOpsToolbar(
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
                final next = await showAiOpsFilterDrawer(
                  context: context,
                  initial: state.filters,
                  isSuperAdmin: isSuperAdmin,
                );
                if (next != null) await controller.applyFilters(next);
              },
              onRefresh: () => controller.refresh(force: true),
              onManualScan: () => controller.runManualScan(),
              onScheduleScan: () => controller.scheduleScan(),
              onSeedDemo:
                  isSuperAdmin ? () => controller.seedDemoRecommendations() : null,
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
                state.recommendations.isEmpty &&
                state.section == AiOpsHubSection.dashboard)
              const SizedBox(
                height: 280,
                child: CfLoadingState(message: 'Loading AI Operations…'),
              )
            else
              _body(
                state: state,
                controller: controller,
                isSuperAdmin: isSuperAdmin,
                actor: actor,
                settings: settings,
              ),
          ],
        ),
      ),
    );
  }

  Widget _body({
    required AiOpsHubState state,
    required AiOpsHubController controller,
    required bool isSuperAdmin,
    required AdminUser? actor,
    required AiOpsSettings settings,
  }) {
    switch (state.section) {
      case AiOpsHubSection.dashboard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AiOpsSummaryCards(summary: state.summary),
            const SizedBox(height: 16),
            Text(
              'Pending recommendations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            AiRecommendationsPanel(
              items: state.recommendations
                  .where((r) => r.status == AiRecommendationStatus.pending)
                  .toList(),
              isLoading: state.isLoading,
              hasMore: state.hasMore,
              isLoadingMore: state.isLoadingMore,
              selectedId: state.selectedRecId,
              onSelect: controller.selectRecommendation,
              onLoadMore: controller.loadMore,
              onApprove: () => controller.resolveSelected(
                AiRecommendationStatus.accepted,
              ),
              onReject: () => controller.resolveSelected(
                AiRecommendationStatus.rejected,
              ),
              onArchive: () => controller.resolveSelected(
                AiRecommendationStatus.archived,
              ),
            ),
          ],
        );
      case AiOpsHubSection.insights:
        return AiInsightsGrid(insights: state.insights);
      case AiOpsHubSection.automationRules:
        return AiRulesPanel(
          rules: state.rules,
          onCreate: () async {
            final rule = await showRuleEditor(
              context: context,
              organizationId: actor?.organizationId,
            );
            if (rule != null) await controller.saveRule(rule);
          },
          onEdit: (r) async {
            final rule = await showRuleEditor(
              context: context,
              existing: r,
              organizationId: actor?.organizationId,
            );
            if (rule != null) await controller.saveRule(rule);
          },
          onEnable: (r) =>
              controller.setRuleStatus(r, AiRuleStatus.enabled),
          onDisable: (r) =>
              controller.setRuleStatus(r, AiRuleStatus.disabled),
          onDuplicate: controller.duplicateRule,
          onDelete: controller.deleteRule,
        );
      case AiOpsHubSection.aiJobs:
        return AiJobsPanel(jobs: state.jobs);
      case AiOpsHubSection.aiModels:
        return AiModelsPanel(models: state.models);
      case AiOpsHubSection.aiLogs:
        return AiLogsPanel(logs: state.logs);
      case AiOpsHubSection.aiSettings:
        return AiSettingsPanel(
          settings: settings,
          canEdit: isSuperAdmin,
          onChanged: (s) => setState(() => _draftSettings = s),
          onSave: () async {
            await controller.saveSettings(settings);
            setState(() => _draftSettings = null);
          },
        );
      case AiOpsHubSection.moderationAssistant:
      case AiOpsHubSection.smartReports:
      case AiOpsHubSection.fraudDetection:
      case AiOpsHubSection.duplicateDetection:
      case AiOpsHubSection.spamDetection:
      case AiOpsHubSection.recommendationCenter:
        return AiRecommendationsPanel(
          items: state.recommendations,
          isLoading: state.isLoading,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          selectedId: state.selectedRecId,
          onSelect: controller.selectRecommendation,
          onLoadMore: controller.loadMore,
          onApprove: () => controller.resolveSelected(
            AiRecommendationStatus.accepted,
          ),
          onReject: () => controller.resolveSelected(
            AiRecommendationStatus.rejected,
          ),
          onArchive: () => controller.resolveSelected(
            AiRecommendationStatus.archived,
          ),
          onIgnoreDuplicate: () => controller.resolveSelected(
            AiRecommendationStatus.rejected,
            duplicateDecision: DuplicateDecision.ignored,
            reason: 'Ignored duplicate',
          ),
          onMarkValid: () => controller.resolveSelected(
            AiRecommendationStatus.accepted,
            duplicateDecision: DuplicateDecision.markedValid,
            reason: 'Marked valid',
          ),
          emptyTitle: '${state.section.label} queue empty',
          emptyMessage:
              'Recommendations appear here for admin decision — never auto-applied.',
        );
    }
  }
}
