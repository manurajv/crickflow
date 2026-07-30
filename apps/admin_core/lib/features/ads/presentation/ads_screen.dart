import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/ads_enums.dart';
import '../providers/ads_providers.dart';
import 'widgets/ad_composer_panel.dart';
import 'widgets/ad_detail_panel.dart';
import 'widgets/admob_config_panel.dart';
import 'widgets/ads_filter_drawer.dart';
import 'widgets/ads_placements_panel.dart';
import 'widgets/ads_revenue_panel.dart';
import 'widgets/ads_summary_cards.dart';
import 'widgets/ads_table.dart';
import 'widgets/ads_toolbar.dart';
import 'widgets/advertisers_panel.dart';
import 'widgets/sponsored_panel.dart';

class AdsScreen extends ConsumerStatefulWidget {
  const AdsScreen({super.key});

  @override
  ConsumerState<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends ConsumerState<AdsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateBreadcrumb(AdsHubSection.dashboard);
      ref.read(adsHubControllerProvider.notifier).ensureBootstrapped();
    });
  }

  void _updateBreadcrumb(AdsHubSection section) {
    ref.read(breadcrumbProvider.notifier).state = [
      'Platform',
      'Advertisements',
      section.label,
    ];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    ref.read(adsHubControllerProvider.notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(adsHubControllerProvider.notifier).refresh();
    });
  }

  bool _usesCampaignTable(AdsHubSection section) {
    return section == AdsHubSection.dashboard ||
        section == AdsHubSection.customAds ||
        section == AdsHubSection.campaigns ||
        section == AdsHubSection.history ||
        section == AdsHubSection.approvalQueue;
  }

  bool _showToolbarFilters(AdsHubSection section) {
    return _usesCampaignTable(section);
  }

  void _exportStub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export (CSV / Excel / PDF) coming soon'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adsHubControllerProvider);
    final controller = ref.read(adsHubControllerProvider.notifier);
    final showDetailPanel = state.selectedId != null && !state.composerOpen;
    final showComposer = state.composerOpen;
    final rightPanelOpen = showDetailPanel || showComposer;

    return PermissionGate(
      permission: AdminPermission.canManageAds,
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  rightPanelOpen ? 480 : 20,
                  32,
                ),
                children: [
                  Text(
                    'Advertisements',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage custom ads, AdMob config mirror, sponsored content, and campaign approvals',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  AdsSummaryCards(summary: state.summary),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final section in AdsHubSection.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(section.label),
                              selected: state.section == section,
                              onSelected: (_) {
                                controller.setSection(section);
                                _updateBreadcrumb(section);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_showToolbarFilters(state.section))
                    AdsToolbar(
                      controller: _searchController,
                      onQueryChanged: _onQueryChanged,
                      onSearchSubmitted: controller.refresh,
                      filterActive: state.filters.hasActiveFilters,
                      refreshing: state.isLoading,
                      onCreate: () => controller.openComposer(),
                      onFilter: () async {
                        final next = await showAdsFilterDrawer(
                          context: context,
                          initial: state.filters.copyWith(
                            query: _searchController.text,
                          ),
                        );
                        if (next != null) {
                          _searchController.text = next.query;
                          await controller.applyFilters(next);
                        }
                      },
                      onRefresh: controller.refresh,
                      onExport: _exportStub,
                    )
                  else
                    AdsToolbar(
                      controller: _searchController,
                      onQueryChanged: (_) {},
                      onSearchSubmitted: () {},
                      filterActive: false,
                      refreshing: state.isLoading,
                      showCreate: state.section == AdsHubSection.customAds ||
                          state.section == AdsHubSection.dashboard ||
                          state.section == AdsHubSection.campaigns,
                      showFilter: false,
                      onCreate: () => controller.openComposer(),
                      onFilter: () {},
                      onRefresh: controller.refresh,
                      onExport: _exportStub,
                      hintText: _sectionSearchHint(state.section),
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
                                onPressed: controller.refresh,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  _buildSectionContent(state, controller),
                ],
              ),
            ),
          ),
          if (showDetailPanel)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 460,
              child: AdDetailPanel(
                onClose: () => controller.selectCampaign(null),
              ),
            ),
          if (showComposer)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 460,
              child: AdComposerPanel(
                onClose: () => controller.openComposer(open: false),
              ),
            ),
        ],
      ),
    );
  }

  String? _sectionSearchHint(AdsHubSection section) {
    return switch (section) {
      AdsHubSection.advertisers => 'Search advertisers…',
      AdsHubSection.sponsored => 'Search sponsored content…',
      AdsHubSection.admobConfig => 'AdMob config (no search)',
      AdsHubSection.placements => 'Placements overview',
      AdsHubSection.revenue => 'Revenue analytics',
      _ => null,
    };
  }

  Widget _buildSectionContent(AdsHubState state, AdsHubController controller) {
    switch (state.section) {
      case AdsHubSection.dashboard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.summary.scheduledCampaigns > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${state.summary.scheduledCampaigns} campaign(s) scheduled',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.adminColors.info,
                      ),
                ),
              ),
            Text(
              'Recent advertisements',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            AdsTable(
              campaigns: state.campaigns,
              sort: state.sort,
              isLoading: state.isLoading,
              hasMore: false,
              isLoadingMore: false,
              selectedId: state.selectedId,
              onSort: controller.setSort,
              onSelect: (c) => controller.selectCampaign(c.id),
              onLoadMore: () {},
              emptyTitle: 'No recent advertisements',
              emptyMessage: 'Create an advertisement to get started.',
            ),
          ],
        );
      case AdsHubSection.customAds:
      case AdsHubSection.campaigns:
      case AdsHubSection.history:
        return AdsTable(
          campaigns: state.campaigns,
          sort: state.sort,
          isLoading: state.isLoading,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          selectedId: state.selectedId,
          onSort: controller.setSort,
          onSelect: (c) => controller.selectCampaign(c.id),
          onLoadMore: controller.loadMore,
          onDuplicate: (c) => controller.duplicate(c),
          emptyTitle: state.section == AdsHubSection.history
              ? 'No history'
              : 'No advertisements found',
          emptyMessage: 'Try adjusting search or filters.',
        );
      case AdsHubSection.approvalQueue:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.campaigns.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${state.campaigns.length} pending approval',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.adminColors.warning,
                      ),
                ),
              ),
            AdsTable(
              campaigns: state.campaigns,
              sort: state.sort,
              isLoading: state.isLoading,
              hasMore: state.hasMore,
              isLoadingMore: state.isLoadingMore,
              selectedId: state.selectedId,
              onSort: controller.setSort,
              onSelect: (c) => controller.selectCampaign(c.id),
              onLoadMore: controller.loadMore,
              emptyTitle: 'Approval queue empty',
              emptyMessage: 'No advertisements awaiting approval.',
            ),
          ],
        );
      case AdsHubSection.admobConfig:
        return AdmobConfigPanel(
          config: state.admobConfig,
          isLoading: state.isLoading,
        );
      case AdsHubSection.advertisers:
        return AdvertisersPanel(
          advertisers: state.advertisers,
          isLoading: state.isLoading,
        );
      case AdsHubSection.sponsored:
        return SponsoredPanel(
          items: state.sponsored,
          isLoading: state.isLoading,
        );
      case AdsHubSection.placements:
        return AdsPlacementsPanel(
          campaigns: state.campaigns,
          isLoading: state.isLoading,
        );
      case AdsHubSection.revenue:
        return AdsRevenuePanel(
          summary: state.summary,
          campaigns: state.campaigns,
          isLoading: state.isLoading,
        );
    }
  }
}
