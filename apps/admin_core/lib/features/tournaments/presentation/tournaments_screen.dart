import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../shell/providers/shell_providers.dart';
import '../providers/tournaments_providers.dart';
import 'widgets/tournament_detail_panel.dart';
import 'widgets/tournaments_filter_drawer.dart';
import 'widgets/tournaments_table.dart';
import 'widgets/tournaments_toolbar.dart';

class TournamentsScreen extends ConsumerStatefulWidget {
  const TournamentsScreen({super.key});

  @override
  ConsumerState<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends ConsumerState<TournamentsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = [
        'Management',
        'Tournaments',
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
    ref.read(tournamentsListControllerProvider.notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(tournamentsListControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tournamentsListControllerProvider);
    final controller = ref.read(tournamentsListControllerProvider.notifier);
    final showPanel = state.selectedId != null;

    return PermissionGate(
      permission: AdminPermission.canManageTournaments,
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
                    'Tournaments',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search, filter, and manage CrickFlow tournaments',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TournamentsSummaryCards(summary: state.summary),
                  const SizedBox(height: 16),
                  TournamentsToolbar(
                    controller: _searchController,
                    onQueryChanged: _onQueryChanged,
                    onSearchSubmitted: controller.refresh,
                    filterActive: state.filters.hasActiveFilters,
                    refreshing: state.isLoading,
                    onFilter: () async {
                      final next = await showTournamentsFilterDrawer(
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
                  TournamentsTable(
                    tournaments: state.tournaments,
                    sort: state.sort,
                    isLoading: state.isLoading,
                    hasMore: state.hasMore,
                    isLoadingMore: state.isLoadingMore,
                    selectedId: state.selectedId,
                    onSort: controller.setSort,
                    onSelect: (t) => controller.selectTournament(t.id),
                    onLoadMore: controller.loadMore,
                  ),
                ],
              ),
            ),
          ),
          if (showPanel)
            Align(
              alignment: Alignment.centerRight,
              child: TournamentDetailPanel(
                onClose: () => controller.selectTournament(null),
              ),
            ),
        ],
      ),
    );
  }
}
