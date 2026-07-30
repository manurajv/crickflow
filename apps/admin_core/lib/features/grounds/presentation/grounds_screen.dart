import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/ground_enums.dart';
import '../models/managed_ground.dart';
import '../providers/grounds_providers.dart';
import 'widgets/ground_detail_panel.dart';
import 'widgets/grounds_filter_drawer.dart';
import 'widgets/grounds_map_preview.dart';
import 'widgets/grounds_table.dart';
import 'widgets/grounds_toolbar.dart';

class GroundsScreen extends ConsumerStatefulWidget {
  const GroundsScreen({super.key});

  @override
  ConsumerState<GroundsScreen> createState() => _GroundsScreenState();
}

class _GroundsScreenState extends ConsumerState<GroundsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = [
        'Management',
        'Grounds',
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
    ref.read(groundsListControllerProvider.notifier).setQuery(value);
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(groundsListControllerProvider.notifier).refresh();
    });
  }

  Future<void> _addGround() async {
    final name = TextEditingController();
    final city = TextEditingController();
    final country = TextEditingController();
    final contact = TextEditingController();
    ManagedGroundType? groundType = ManagedGroundType.outdoor;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Add Ground'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Ground name *',
                      ),
                    ),
                    TextField(
                      controller: city,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                    TextField(
                      controller: country,
                      decoration: const InputDecoration(labelText: 'Country'),
                    ),
                    TextField(
                      controller: contact,
                      decoration:
                          const InputDecoration(labelText: 'Contact number'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ManagedGroundType?>(
                      initialValue: groundType,
                      decoration:
                          const InputDecoration(labelText: 'Ground type'),
                      items: [
                        for (final t in ManagedGroundType.values)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: (v) => setLocal(() => groundType = v),
                    ),
                  ],
                ),
              ),
              actions: [
                CfButton(
                  label: 'Cancel',
                  variant: CfButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context, false),
                ),
                CfButton(
                  label: 'Create',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || name.text.trim().isEmpty) return;

    final id = await ref.read(groundsListControllerProvider.notifier).createGround(
          ManagedGround(
            id: '',
            name: name.text.trim(),
            city: city.text.trim(),
            country: country.text.trim(),
            contactNumber: contact.text.trim(),
            groundType: groundType,
            adminStatus: ManagedGroundStatus.pendingVerification,
          ),
        );

    if (!mounted) return;
    if (id != null) {
      ref.read(groundsListControllerProvider.notifier).selectGround(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ground created')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groundsListControllerProvider);
    final controller = ref.read(groundsListControllerProvider.notifier);
    final showPanel = state.selectedId != null;

    return PermissionGate(
      permission: AdminPermission.canManageGrounds,
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
                    'Grounds',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Grounds from tournaments — unique venues chosen when creating tournaments',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  GroundsSummaryCards(summary: state.summary),
                  const SizedBox(height: 16),
                  GroundsToolbar(
                    controller: _searchController,
                    onQueryChanged: _onQueryChanged,
                    onSearchSubmitted: controller.refresh,
                    filterActive: state.filters.hasActiveFilters,
                    refreshing: state.isLoading,
                    mapView: state.mapView,
                    onToggleMap: controller.toggleMapView,
                    onAdd: _addGround,
                    onFilter: () async {
                      final next = await showGroundsFilterDrawer(
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
                  if (state.mapView)
                    GroundsMapPreview(
                      grounds: state.grounds,
                      selectedId: state.selectedId,
                      onSelect: (g) => controller.selectGround(g.id),
                    )
                  else
                    GroundsTable(
                      grounds: state.grounds,
                      sort: state.sort,
                      isLoading: state.isLoading,
                      hasMore: state.hasMore,
                      isLoadingMore: state.isLoadingMore,
                      selectedId: state.selectedId,
                      onSort: controller.setSort,
                      onSelect: (g) => controller.selectGround(g.id),
                      onLoadMore: controller.loadMore,
                    ),
                ],
              ),
            ),
          ),
          if (showPanel)
            Align(
              alignment: Alignment.centerRight,
              child: GroundDetailPanel(
                onClose: () => controller.selectGround(null),
              ),
            ),
        ],
      ),
    );
  }
}
