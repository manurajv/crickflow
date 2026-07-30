import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/managed_organization.dart';
import '../providers/organizations_providers.dart';
import 'widgets/organization_composer_panel.dart';
import 'widgets/organization_detail_panel.dart';
import 'widgets/organizations_filter_drawer.dart';
import 'widgets/organizations_table.dart';
import 'widgets/organizations_toolbar.dart';

class OrganizationsScreen extends ConsumerStatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  ConsumerState<OrganizationsScreen> createState() =>
      _OrganizationsScreenState();
}

class _OrganizationsScreenState extends ConsumerState<OrganizationsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = [
        'Management',
        'Organizations',
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
    ref.read(organizationsListControllerProvider.notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(organizationsListControllerProvider.notifier).refresh();
    });
  }

  ManagedOrganization? _editingOrg(OrganizationsListState state) {
    final id = state.editingId;
    if (id == null) return null;
    for (final o in state.organizations) {
      if (o.id == id) return o;
    }
    return ref.read(selectedManagedOrganizationProvider).asData?.value;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(organizationsListControllerProvider);
    final controller = ref.read(organizationsListControllerProvider.notifier);
    final showDetail = state.selectedId != null && !state.composerOpen;
    final showComposer = state.composerOpen;
    final showPanel = showDetail || showComposer;
    final editing = showComposer ? _editingOrg(state) : null;

    return PermissionGate(
      permission: AdminPermission.canManageOrganizations,
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  showPanel ? 540 : 20,
                  32,
                ),
                children: [
                  Text(
                    'Organizations',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage national boards, provincial boards, districts, clubs, academies, schools, universities, and more',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  OrganizationsSummaryCards(summary: state.summary),
                  const SizedBox(height: 16),
                  OrganizationsToolbar(
                    controller: _searchController,
                    onQueryChanged: _onQueryChanged,
                    onSearchSubmitted: controller.refresh,
                    filterActive: state.filters.hasActiveFilters,
                    refreshing: state.isLoading,
                    onFilter: () async {
                      final next = await showOrganizationsFilterDrawer(
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
                    onCreate: controller.openCreateComposer,
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
                  OrganizationsTable(
                    organizations: state.organizations,
                    sort: state.sort,
                    isLoading: state.isLoading,
                    hasMore: state.hasMore,
                    isLoadingMore: state.isLoadingMore,
                    selectedId: state.selectedId,
                    onSort: controller.setSort,
                    onSelect: (o) => controller.selectOrganization(o.id),
                    onLoadMore: controller.loadMore,
                  ),
                ],
              ),
            ),
          ),
          if (showComposer)
            Align(
              alignment: Alignment.centerRight,
              child: OrganizationComposerPanel(
                onClose: controller.closeComposer,
                existing: editing,
              ),
            )
          else if (showDetail)
            Align(
              alignment: Alignment.centerRight,
              child: OrganizationDetailPanel(
                onClose: () => controller.selectOrganization(null),
              ),
            ),
        ],
      ),
    );
  }
}
