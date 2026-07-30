import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../shell/providers/shell_providers.dart';
import '../providers/players_providers.dart';
import 'widgets/player_detail_panel.dart';
import 'widgets/players_chrome.dart';
import 'widgets/players_table.dart';

class PlayersScreen extends ConsumerStatefulWidget {
  const PlayersScreen({super.key});

  @override
  ConsumerState<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends ConsumerState<PlayersScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = [
        'Management',
        'Players',
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
    ref.read(playersListControllerProvider.notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(playersListControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playersListControllerProvider);
    final controller = ref.read(playersListControllerProvider.notifier);
    final showPanel = state.selectedId != null;

    return PermissionGate(
      permission: AdminPermission.canManagePlayers,
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
                  Text(
                    'Players',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search, filter, and manage CrickFlow player profiles',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  PlayersSummaryCards(summary: state.summary),
                  const SizedBox(height: 16),
                  PlayersToolbar(
                    controller: _searchController,
                    onQueryChanged: _onQueryChanged,
                    onSearchSubmitted: controller.refresh,
                    filterActive: state.filters.hasActiveFilters,
                    refreshing: state.isLoading,
                    onFilter: () async {
                      final next = await showPlayersFilterDrawer(
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
                  PlayersTable(
                    players: state.players,
                    sort: state.sort,
                    isLoading: state.isLoading,
                    hasMore: state.hasMore,
                    isLoadingMore: state.isLoadingMore,
                    selectedId: state.selectedId,
                    onSort: controller.setSort,
                    onSelect: (p) => controller.selectPlayer(p.id),
                    onLoadMore: controller.loadMore,
                  ),
                ],
              ),
            ),
          ),
          if (showPanel)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: PlayerDetailPanel(
                onClose: () => controller.selectPlayer(null),
              ),
            ),
        ],
      ),
    );
  }
}
