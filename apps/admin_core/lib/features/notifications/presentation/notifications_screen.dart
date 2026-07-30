import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/notification_enums.dart';
import '../providers/notifications_providers.dart';
import 'widgets/announcements_panel.dart';
import 'widgets/auto_notifications_table.dart';
import 'widgets/notification_composer_panel.dart';
import 'widgets/notification_detail_panel.dart';
import 'widgets/notifications_filter_drawer.dart';
import 'widgets/notifications_summary_cards.dart';
import 'widgets/notifications_table.dart';
import 'widgets/notifications_toolbar.dart';
import 'widgets/segments_panel.dart';
import 'widgets/templates_panel.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBreadcrumb(NotificationHubSection.dashboard);
    });
  }

  void _updateBreadcrumb(NotificationHubSection section) {
    ref.read(breadcrumbProvider.notifier).state = [
      'Platform',
      'Notifications',
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
    ref.read(notificationsHubControllerProvider.notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(notificationsHubControllerProvider.notifier).refresh();
    });
  }

  bool _usesCampaignTable(NotificationHubSection section) {
    return section == NotificationHubSection.dashboard ||
        section == NotificationHubSection.notifications ||
        section == NotificationHubSection.campaigns ||
        section == NotificationHubSection.scheduled ||
        section == NotificationHubSection.history ||
        section == NotificationHubSection.deliveryReports;
  }

  bool _showToolbarFilters(NotificationHubSection section) {
    return _usesCampaignTable(section);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsHubControllerProvider);
    final controller = ref.read(notificationsHubControllerProvider.notifier);
    final showDetailPanel =
        state.selectedId != null && !state.composerOpen;
    final showComposer = state.composerOpen;
    final rightPanelOpen = showDetailPanel || showComposer;

    return PermissionGate(
      permission: AdminPermission.canSendNotifications,
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
                    'Notifications',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage push notifications, campaigns, announcements, and delivery reports',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  NotificationsSummaryCards(summary: state.summary),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final section in NotificationHubSection.values)
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
                    NotificationsToolbar(
                      controller: _searchController,
                      onQueryChanged: _onQueryChanged,
                      onSearchSubmitted: controller.refresh,
                      filterActive: state.filters.hasActiveFilters,
                      refreshing: state.isLoading,
                      onCreate: () => controller.openComposer(),
                      onFilter: () async {
                        final next = await showNotificationsFilterDrawer(
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
                      onExport: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Export (CSV / Excel / PDF) coming soon',
                            ),
                          ),
                        );
                      },
                    )
                  else
                    NotificationsToolbar(
                      controller: _searchController,
                      onQueryChanged: (_) {},
                      onSearchSubmitted: () {},
                      filterActive: false,
                      refreshing: state.isLoading,
                      showCreate: state.section ==
                              NotificationHubSection.notifications ||
                          state.section == NotificationHubSection.dashboard,
                      onCreate: () => controller.openComposer(),
                      onFilter: () {},
                      onRefresh: controller.refresh,
                      onExport: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Export (CSV / Excel / PDF) coming soon',
                            ),
                          ),
                        );
                      },
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
            Align(
              alignment: Alignment.centerRight,
              child: NotificationDetailPanel(
                onClose: () => controller.selectCampaign(null),
              ),
            ),
          if (showComposer)
            Align(
              alignment: Alignment.centerRight,
              child: NotificationComposerPanel(
                onClose: () => controller.openComposer(open: false),
              ),
            ),
        ],
      ),
    );
  }

  String? _sectionSearchHint(NotificationHubSection section) {
    return switch (section) {
      NotificationHubSection.announcements => 'Search announcements…',
      NotificationHubSection.templates => 'Search templates…',
      NotificationHubSection.segments => 'Search segments…',
      NotificationHubSection.autoNotifications =>
        'Search auto notifications…',
      _ => null,
    };
  }

  Widget _buildSectionContent(
    NotificationsHubState state,
    NotificationsHubController controller,
  ) {
    switch (state.section) {
      case NotificationHubSection.dashboard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.summary.scheduled > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${state.summary.scheduled} notification(s) pending scheduled delivery',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.adminColors.info,
                      ),
                ),
              ),
            Text(
              'Recent campaigns',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            NotificationsTable(
              campaigns: state.campaigns,
              sort: state.sort,
              isLoading: state.isLoading,
              hasMore: false,
              isLoadingMore: false,
              selectedId: state.selectedId,
              onSort: controller.setSort,
              onSelect: (c) => controller.selectCampaign(c.id),
              onLoadMore: () {},
              emptyTitle: 'No recent campaigns',
              emptyMessage: 'Create a notification to get started.',
            ),
          ],
        );
      case NotificationHubSection.notifications:
      case NotificationHubSection.history:
        return NotificationsTable(
          campaigns: state.campaigns,
          sort: state.sort,
          isLoading: state.isLoading,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          selectedId: state.selectedId,
          onSort: controller.setSort,
          onSelect: (c) => controller.selectCampaign(c.id),
          onLoadMore: controller.loadMore,
          emptyTitle: state.section == NotificationHubSection.history
              ? 'No history'
              : 'No notifications found',
          emptyMessage: 'Try adjusting search or filters.',
        );
      case NotificationHubSection.campaigns:
        return NotificationsTable(
          campaigns: state.campaigns,
          sort: state.sort,
          isLoading: state.isLoading,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          selectedId: state.selectedId,
          onSort: controller.setSort,
          onSelect: (c) => controller.selectCampaign(c.id),
          onLoadMore: controller.loadMore,
          emptyTitle: 'No campaigns',
          emptyMessage: 'Campaign notifications will appear here.',
        );
      case NotificationHubSection.scheduled:
        return NotificationsTable(
          campaigns: state.campaigns,
          sort: state.sort,
          isLoading: state.isLoading,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          selectedId: state.selectedId,
          onSort: controller.setSort,
          onSelect: (c) => controller.selectCampaign(c.id),
          onLoadMore: controller.loadMore,
          emptyTitle: 'No scheduled notifications',
          emptyMessage: 'Schedule a notification to see it here.',
        );
      case NotificationHubSection.deliveryReports:
        return NotificationsTable(
          campaigns: state.campaigns,
          sort: state.sort,
          isLoading: state.isLoading,
          hasMore: state.hasMore,
          isLoadingMore: state.isLoadingMore,
          selectedId: state.selectedId,
          onSort: controller.setSort,
          onSelect: (c) => controller.selectCampaign(c.id),
          onLoadMore: controller.loadMore,
          showDeliveryMetrics: true,
          emptyTitle: 'No delivery reports',
          emptyMessage: 'Sent notifications with delivery data appear here.',
        );
      case NotificationHubSection.announcements:
        return AnnouncementsPanel(
          announcements: state.announcements,
          isLoading: state.isLoading,
        );
      case NotificationHubSection.templates:
        return TemplatesPanel(
          templates: state.templates,
          isLoading: state.isLoading,
        );
      case NotificationHubSection.segments:
        return SegmentsPanel(
          segments: state.segments,
          isLoading: state.isLoading,
        );
      case NotificationHubSection.autoNotifications:
        return AutoNotificationsTable(
          items: state.autoNotifications,
          isLoading: state.isLoading,
        );
    }
  }
}
