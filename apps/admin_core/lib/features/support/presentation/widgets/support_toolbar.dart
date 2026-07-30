import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_search_bar.dart';
import '../../models/support_enums.dart';
import '../../models/support_filters.dart';

class SupportSectionChips extends StatelessWidget {
  const SupportSectionChips({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final SupportHubSection section;
  final ValueChanged<SupportHubSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in SupportHubSection.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s.label),
                selected: section == s,
                onSelected: (_) => onChanged(s),
              ),
            ),
        ],
      ),
    );
  }
}

class SupportToolbar extends StatelessWidget {
  const SupportToolbar({
    super.key,
    this.searchController,
    required this.onQueryChanged,
    required this.onFilter,
    required this.onRefresh,
    required this.onCreate,
    required this.onExport,
    required this.filterActive,
    required this.refreshing,
  });

  final TextEditingController? searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final VoidCallback onExport;
  final bool filterActive;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CfSearchBar(
          controller: searchController,
          hintText: 'Search ticket ID, user, email, phone, subject, category…',
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CfButton(
              label: 'Create Ticket',
              icon: Icons.add,
              onPressed: onCreate,
            ),
            OutlinedButton.icon(
              onPressed: onFilter,
              icon: Badge(
                isLabelVisible: filterActive,
                smallSize: 8,
                child: const Icon(Icons.filter_list),
              ),
              label: const Text('Filter'),
            ),
            IconButton.filledTonal(
              tooltip: 'Refresh',
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export'),
            ),
            Text(
              'Help desk only — not community chat',
              style: TextStyle(
                fontSize: 11,
                color: context.adminColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<SupportListFilters?> showSupportFilterDrawer({
  required BuildContext context,
  required SupportListFilters initial,
  required bool isSuperAdmin,
}) {
  return showModalBottomSheet<SupportListFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _SupportFilterSheet(
      initial: initial,
      isSuperAdmin: isSuperAdmin,
    ),
  );
}

class _SupportFilterSheet extends StatefulWidget {
  const _SupportFilterSheet({
    required this.initial,
    required this.isSuperAdmin,
  });

  final SupportListFilters initial;
  final bool isSuperAdmin;

  @override
  State<_SupportFilterSheet> createState() => _SupportFilterSheetState();
}

class _SupportFilterSheetState extends State<_SupportFilterSheet> {
  late Set<SupportTicketStatus> _statuses;
  late Set<SupportTicketPriority> _priorities;
  late Set<SupportTicketCategory> _categories;
  late final TextEditingController _assigned;
  late final TextEditingController _org;
  late final TextEditingController _country;
  late final TextEditingController _state;
  late final TextEditingController _platform;
  DateTime? _from;
  DateTime? _to;
  bool _unassigned = false;
  bool _overdue = false;

  @override
  void initState() {
    super.initState();
    _statuses = {...widget.initial.statuses};
    _priorities = {...widget.initial.priorities};
    _categories = {...widget.initial.categories};
    _assigned = TextEditingController(text: widget.initial.assignedToUid ?? '');
    _org = TextEditingController(text: widget.initial.organizationId ?? '');
    _country = TextEditingController(text: widget.initial.country ?? '');
    _state = TextEditingController(text: widget.initial.stateProvince ?? '');
    _platform = TextEditingController(text: widget.initial.platform ?? '');
    _from = widget.initial.from;
    _to = widget.initial.to;
    _unassigned = widget.initial.unassignedOnly;
    _overdue = widget.initial.overdueOnly;
  }

  @override
  void dispose() {
    _assigned.dispose();
    _org.dispose();
    _country.dispose();
    _state.dispose();
    _platform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Support filters',
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
                  Text('Status', style: Theme.of(context).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in SupportTicketStatus.values)
                        FilterChip(
                          label: Text(s.label),
                          selected: _statuses.contains(s),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _statuses.add(s);
                            } else {
                              _statuses.remove(s);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Priority', style: Theme.of(context).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in SupportTicketPriority.values)
                        FilterChip(
                          label: Text(p.label),
                          selected: _priorities.contains(p),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _priorities.add(p);
                            } else {
                              _priorities.remove(p);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Category', style: Theme.of(context).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in SupportTicketCategory.values)
                        FilterChip(
                          label: Text(c.label),
                          selected: _categories.contains(c),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _categories.add(c);
                            } else {
                              _categories.remove(c);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _assigned,
                    decoration: const InputDecoration(
                      labelText: 'Assigned agent UID',
                    ),
                  ),
                  if (widget.isSuperAdmin) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _org,
                      decoration: const InputDecoration(
                        labelText: 'Organization ID',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _country,
                    decoration: const InputDecoration(labelText: 'Country'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _state,
                    decoration: const InputDecoration(labelText: 'State'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _platform,
                    decoration: const InputDecoration(labelText: 'Platform'),
                  ),
                  SwitchListTile(
                    title: const Text('Unassigned only'),
                    value: _unassigned,
                    onChanged: (v) => setState(() => _unassigned = v),
                  ),
                  SwitchListTile(
                    title: const Text('Overdue SLA only'),
                    value: _overdue,
                    onChanged: (v) => setState(() => _overdue = v),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _from ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => _from = d);
                        },
                        child: Text(
                          _from == null
                              ? 'From'
                              : 'From ${_from!.toIso8601String().substring(0, 10)}',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _to ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => _to = d);
                        },
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
                    onPressed: () =>
                        Navigator.pop(context, SupportListFilters.empty),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  CfButton(
                    label: 'Apply',
                    onPressed: () {
                      Navigator.pop(
                        context,
                        SupportListFilters(
                          query: widget.initial.query,
                          statuses: _statuses,
                          priorities: _priorities,
                          categories: _categories,
                          assignedToUid: _assigned.text.trim().isEmpty
                              ? null
                              : _assigned.text.trim(),
                          organizationId: _org.text.trim().isEmpty
                              ? null
                              : _org.text.trim(),
                          country: _country.text.trim().isEmpty
                              ? null
                              : _country.text.trim(),
                          stateProvince: _state.text.trim().isEmpty
                              ? null
                              : _state.text.trim(),
                          platform: _platform.text.trim().isEmpty
                              ? null
                              : _platform.text.trim(),
                          from: _from,
                          to: _to,
                          unassignedOnly: _unassigned,
                          overdueOnly: _overdue,
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

Future<void> showCreateTicketDialog({
  required BuildContext context,
  required Future<void> Function({
    required String subject,
    required String description,
    required SupportTicketKind kind,
    required SupportTicketCategory category,
    required SupportTicketPriority priority,
    String stepsToReproduce,
    String logs,
    int? rating,
  }) onSubmit,
}) async {
  final subject = TextEditingController();
  final description = TextEditingController();
  final steps = TextEditingController();
  final logs = TextEditingController();
  var kind = SupportTicketKind.support;
  var category = SupportTicketCategory.support;
  var priority = SupportTicketPriority.medium;
  int? rating;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Create Ticket'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subject,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: description,
                      minLines: 3,
                      maxLines: 5,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<SupportTicketKind>(
                      // ignore: deprecated_member_use
                      value: kind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        for (final k in SupportTicketKind.values)
                          DropdownMenuItem(value: k, child: Text(k.label)),
                      ],
                      onChanged: (v) => setLocal(() => kind = v ?? kind),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<SupportTicketCategory>(
                      // ignore: deprecated_member_use
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in SupportTicketCategory.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: (v) =>
                          setLocal(() => category = v ?? category),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<SupportTicketPriority>(
                      // ignore: deprecated_member_use
                      value: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: [
                        for (final p in SupportTicketPriority.values)
                          DropdownMenuItem(value: p, child: Text(p.label)),
                      ],
                      onChanged: (v) =>
                          setLocal(() => priority = v ?? priority),
                    ),
                    if (kind == SupportTicketKind.bug) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: steps,
                        decoration: const InputDecoration(
                          labelText: 'Steps to reproduce',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: logs,
                        decoration: const InputDecoration(labelText: 'Logs'),
                      ),
                    ],
                    if (kind == SupportTicketKind.feedback) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: rating ?? 5,
                        decoration: const InputDecoration(labelText: 'Rating'),
                        items: [
                          for (var i = 1; i <= 5; i++)
                            DropdownMenuItem(value: i, child: Text('$i')),
                        ],
                        onChanged: (v) => setLocal(() => rating = v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (subject.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await onSubmit(
                    subject: subject.text,
                    description: description.text,
                    kind: kind,
                    category: category,
                    priority: priority,
                    stepsToReproduce: steps.text,
                    logs: logs.text,
                    rating: rating,
                  );
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );

  subject.dispose();
  description.dispose();
  steps.dispose();
  logs.dispose();
}

Future<void> showSupportExportSheet(BuildContext context, String csv) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Export',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('CSV'),
              subtitle: const Text('Copy to clipboard'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: csv));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV copied')),
                  );
                }
              },
            ),
            const ListTile(
              leading: Icon(Icons.grid_on_outlined),
              title: Text('Excel'),
              subtitle: Text('Prepared for later'),
            ),
            const ListTile(
              leading: Icon(Icons.picture_as_pdf_outlined),
              title: Text('PDF'),
              subtitle: Text('Prepared for later'),
            ),
          ],
        ),
      ),
    ),
  );
}
