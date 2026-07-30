import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../shell/providers/shell_providers.dart';
import '../providers/teams_providers.dart';
import 'widgets/team_detail_panel.dart';
import 'widgets/teams_filter_drawer.dart';
import 'widgets/teams_table.dart';
import 'widgets/teams_toolbar.dart';

class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = [
        'Management',
        'Teams',
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
    ref.read(teamsListControllerProvider.notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(teamsListControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teamsListControllerProvider);
    final controller = ref.read(teamsListControllerProvider.notifier);
    final showPanel = state.selectedId != null;

    return PermissionGate(
      permission: AdminPermission.canManageTeams,
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
                    'Teams',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search, filter, and manage CrickFlow teams',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TeamsSummaryCards(summary: state.summary),
                  const SizedBox(height: 16),
                  TeamsToolbar(
                    controller: _searchController,
                    onQueryChanged: _onQueryChanged,
                    onSearchSubmitted: controller.refresh,
                    filterActive: state.filters.hasActiveFilters,
                    refreshing: state.isLoading,
                    onFilter: () async {
                      final next = await showTeamsFilterDrawer(
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
                  TeamsTable(
                    teams: state.teams,
                    sort: state.sort,
                    isLoading: state.isLoading,
                    hasMore: state.hasMore,
                    isLoadingMore: state.isLoadingMore,
                    selectedId: state.selectedId,
                    onSort: controller.setSort,
                    onSelect: (t) => controller.selectTeam(t.id),
                    onLoadMore: controller.loadMore,
                  ),
                ],
              ),
            ),
          ),
          if (showPanel)
            Align(
              alignment: Alignment.centerRight,
              child: TeamDetailPanel(
                onClose: () => controller.selectTeam(null),
              ),
            ),
        ],
      ),
    );
  }
}
