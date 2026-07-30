import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../shell/providers/shell_providers.dart';
import '../providers/broadcasts_providers.dart';
import 'widgets/broadcast_detail_panel.dart';
import 'widgets/broadcasts_filter_drawer.dart';
import 'widgets/broadcasts_table.dart';
import 'widgets/broadcasts_toolbar.dart';

class BroadcastsScreen extends ConsumerStatefulWidget {
  const BroadcastsScreen({super.key});

  @override
  ConsumerState<BroadcastsScreen> createState() => _BroadcastsScreenState();
}

class _BroadcastsScreenState extends ConsumerState<BroadcastsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = [
        'Management',
        'Broadcasts',
      ];
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    ref.read(broadcastsListControllerProvider.notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(broadcastsListControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(broadcastsListControllerProvider);
    final controller = ref.read(broadcastsListControllerProvider.notifier);
    final showPanel = state.selectedId != null;

    return PermissionGate(
      permission: AdminPermission.canManageBroadcast,
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  showPanel ? 480 : 20,
                  32,
                ),
                children: [
                  Text(
                    'Broadcasts',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitor live streams and broadcast health — read-only stream control',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  BroadcastsSummaryCards(summary: state.summary),
                  const SizedBox(height: 16),
                  BroadcastsToolbar(
                    controller: _searchController,
                    onQueryChanged: _onQueryChanged,
                    onSearchSubmitted: controller.refresh,
                    filterActive: state.filters.hasActiveFilters,
                    refreshing: state.isLoading,
                    liveMonitor: state.liveMonitor,
                    onToggleLiveMonitor: controller.toggleLiveMonitor,
                    onFilter: () async {
                      final next = await showBroadcastsFilterDrawer(
                        context: context,
                        initial: state.filters.copyWith(
                          query: _searchController.text,
                          liveOnly: state.liveMonitor,
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
                  if (state.liveMonitor)
                    BroadcastsLiveList(
                      broadcasts: state.broadcasts,
                      isLoading: state.isLoading,
                      selectedId: state.selectedId,
                      onSelect: (b) => controller.selectBroadcast(b.id),
                    )
                  else
                    BroadcastsTable(
                      broadcasts: state.broadcasts,
                      sort: state.sort,
                      isLoading: state.isLoading,
                      hasMore: state.hasMore,
                      isLoadingMore: state.isLoadingMore,
                      selectedId: state.selectedId,
                      onSort: controller.setSort,
                      onSelect: (b) => controller.selectBroadcast(b.id),
                      onLoadMore: controller.loadMore,
                    ),
                ],
              ),
            ),
          ),
          if (showPanel)
            Align(
              alignment: Alignment.centerRight,
              child: BroadcastDetailPanel(
                onClose: () => controller.selectBroadcast(null),
              ),
            ),
        ],
      ),
    );
  }
}
