import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_search_bar.dart';
import '../../models/monitoring_enums.dart';
import '../../models/monitoring_filters.dart';

class MonitoringSectionChips extends StatelessWidget {
  const MonitoringSectionChips({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final MonitoringHubSection section;
  final ValueChanged<MonitoringHubSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in MonitoringHubSection.values) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s.label),
                selected: section == s,
                onSelected: (_) => onChanged(s),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MonitoringToolbar extends StatelessWidget {
  const MonitoringToolbar({
    super.key,
    this.searchController,
    required this.onQueryChanged,
    required this.onFilter,
    required this.onRefresh,
    required this.filterActive,
    required this.refreshing,
  });

  final TextEditingController? searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final bool filterActive;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CfSearchBar(
              controller: searchController,
              hintText:
                  'Search errors, functions, jobs, collections, services…',
              onChanged: onQueryChanged,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onFilter,
                  icon: Badge(
                    isLabelVisible: filterActive,
                    smallSize: 8,
                    child: const Icon(Icons.filter_list),
                  ),
                  label: Text(compact ? 'Filters' : 'Advanced filters'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh metrics',
                  onPressed: refreshing ? null : onRefresh,
                  icon: refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
                Text(
                  'Monitoring only — no control actions',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.adminColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Future<MonitoringFilters?> showMonitoringFilterDrawer({
  required BuildContext context,
  required MonitoringFilters initial,
}) {
  return showModalBottomSheet<MonitoringFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _MonitoringFilterSheet(initial: initial),
  );
}

class _MonitoringFilterSheet extends StatefulWidget {
  const _MonitoringFilterSheet({required this.initial});

  final MonitoringFilters initial;

  @override
  State<_MonitoringFilterSheet> createState() => _MonitoringFilterSheetState();
}

class _MonitoringFilterSheetState extends State<_MonitoringFilterSheet> {
  late Set<MonitoringSeverity> _severities;
  late Set<FirebaseServiceId> _services;
  late final TextEditingController _module;
  late final TextEditingController _platform;
  MonitoringEnvironment? _environment;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _severities = {...widget.initial.severities};
    _services = {...widget.initial.services};
    _module = TextEditingController(text: widget.initial.module ?? '');
    _platform = TextEditingController(text: widget.initial.platform ?? '');
    _environment = widget.initial.environment;
    _from = widget.initial.from;
    _to = widget.initial.to;
  }

  @override
  void dispose() {
    _module.dispose();
    _platform.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _to = d);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'System filters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    'Severity',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in MonitoringSeverity.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _severities.contains(s),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _severities.add(s);
                              } else {
                                _severities.remove(s);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Service',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in FirebaseServiceId.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _services.contains(s),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _services.add(s);
                              } else {
                                _services.remove(s);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _module,
                    decoration: const InputDecoration(
                      labelText: 'Module',
                      hintText: 'auth, firestore, streaming…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MonitoringEnvironment?>(
                    // ignore: deprecated_member_use
                    value: _environment,
                    decoration: const InputDecoration(labelText: 'Environment'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Any'),
                      ),
                      for (final e in MonitoringEnvironment.values)
                        DropdownMenuItem(
                          value: e,
                          child: Text(e.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _environment = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _platform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                      hintText: 'android, ios, web…',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Date range',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _pickFrom,
                        child: Text(
                          _from == null
                              ? 'From'
                              : 'From ${_from!.toIso8601String().substring(0, 10)}',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _pickTo,
                        child: Text(
                          _to == null
                              ? 'To'
                              : 'To ${_to!.toIso8601String().substring(0, 10)}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, MonitoringFilters.empty);
                    },
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  CfButton(
                    label: 'Apply',
                    onPressed: () {
                      Navigator.pop(
                        context,
                        MonitoringFilters(
                          query: widget.initial.query,
                          severities: _severities,
                          services: _services,
                          module: _module.text.trim().isEmpty
                              ? null
                              : _module.text.trim(),
                          environment: _environment,
                          platform: _platform.text.trim().isEmpty
                              ? null
                              : _platform.text.trim(),
                          from: _from,
                          to: _to,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
