import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../../../shared/widgets/cf_search_bar.dart';
import '../../models/ai_ops_enums.dart';
import '../../models/ai_ops_filters.dart';
import '../../models/managed_ai_ops.dart';

class AiOpsSectionChips extends StatelessWidget {
  const AiOpsSectionChips({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final AiOpsHubSection section;
  final ValueChanged<AiOpsHubSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in AiOpsHubSection.values)
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

class AiOpsToolbar extends StatelessWidget {
  const AiOpsToolbar({
    super.key,
    this.searchController,
    required this.onQueryChanged,
    required this.onFilter,
    required this.onRefresh,
    required this.onManualScan,
    required this.onScheduleScan,
    required this.filterActive,
    required this.refreshing,
    this.onSeedDemo,
  });

  final TextEditingController? searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final VoidCallback onManualScan;
  final VoidCallback onScheduleScan;
  final bool filterActive;
  final bool refreshing;
  final VoidCallback? onSeedDemo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CfSearchBar(
          controller: searchController,
          hintText:
              'Search users, teams, tournaments, orgs, grounds, reports, recommendations…',
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
              label: const Text('Filters'),
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
            CfButton(
              label: 'Run Manual Scan',
              icon: Icons.radar,
              onPressed: onManualScan,
            ),
            OutlinedButton(
              onPressed: onScheduleScan,
              child: const Text('Schedule Scan'),
            ),
            if (onSeedDemo != null)
              TextButton(
                onPressed: onSeedDemo,
                child: const Text('Seed demo queue'),
              ),
            Text(
              'No continuous Firestore scans · batch jobs only',
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

Future<AiOpsFilters?> showAiOpsFilterDrawer({
  required BuildContext context,
  required AiOpsFilters initial,
  required bool isSuperAdmin,
}) {
  return showModalBottomSheet<AiOpsFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AiFilterSheet(
      initial: initial,
      isSuperAdmin: isSuperAdmin,
    ),
  );
}

class _AiFilterSheet extends StatefulWidget {
  const _AiFilterSheet({required this.initial, required this.isSuperAdmin});
  final AiOpsFilters initial;
  final bool isSuperAdmin;

  @override
  State<_AiFilterSheet> createState() => _AiFilterSheetState();
}

class _AiFilterSheetState extends State<_AiFilterSheet> {
  late Set<AiRecommendationCategory> _categories;
  late Set<AiRecommendationStatus> _statuses;
  late Set<AiConfidenceBand> _bands;
  late final TextEditingController _org;
  late final TextEditingController _country;
  late final TextEditingController _state;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _categories = {...widget.initial.categories};
    _statuses = {...widget.initial.statuses};
    _bands = {...widget.initial.confidenceBands};
    _org = TextEditingController(text: widget.initial.organizationId ?? '');
    _country = TextEditingController(text: widget.initial.country ?? '');
    _state = TextEditingController(text: widget.initial.stateProvince ?? '');
    _from = widget.initial.from;
    _to = widget.initial.to;
  }

  @override
  void dispose() {
    _org.dispose();
    _country.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI Operations filters',
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
                  Text('Category', style: Theme.of(context).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in AiRecommendationCategory.values)
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
                  Text('Status', style: Theme.of(context).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in AiRecommendationStatus.values)
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
                  Text(
                    'Confidence',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final b in AiConfidenceBand.values)
                        FilterChip(
                          label: Text(b.label),
                          selected: _bands.contains(b),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _bands.add(b);
                            } else {
                              _bands.remove(b);
                            }
                          }),
                        ),
                    ],
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
                    onPressed: () => Navigator.pop(context, AiOpsFilters.empty),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  CfButton(
                    label: 'Apply',
                    onPressed: () {
                      Navigator.pop(
                        context,
                        AiOpsFilters(
                          query: widget.initial.query,
                          categories: _categories,
                          statuses: _statuses,
                          confidenceBands: _bands,
                          organizationId: _org.text.trim().isEmpty
                              ? null
                              : _org.text.trim(),
                          country: _country.text.trim().isEmpty
                              ? null
                              : _country.text.trim(),
                          stateProvince: _state.text.trim().isEmpty
                              ? null
                              : _state.text.trim(),
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

class AiRulesPanel extends StatelessWidget {
  const AiRulesPanel({
    super.key,
    required this.rules,
    required this.onCreate,
    required this.onEdit,
    required this.onEnable,
    required this.onDisable,
    required this.onDuplicate,
    required this.onDelete,
  });

  final List<AiAutomationRule> rules;
  final VoidCallback onCreate;
  final ValueChanged<AiAutomationRule> onEdit;
  final ValueChanged<AiAutomationRule> onEnable;
  final ValueChanged<AiAutomationRule> onDisable;
  final ValueChanged<AiAutomationRule> onDuplicate;
  final ValueChanged<AiAutomationRule> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CfButton(
            label: 'Create Rule',
            icon: Icons.add,
            onPressed: onCreate,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Default execution is recommend-only. Auto-execute is future-gated.',
          style: TextStyle(fontSize: 12, color: context.adminColors.textMuted),
        ),
        const SizedBox(height: 12),
        if (rules.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 200,
              child: CfEmptyState(
                icon: Icons.rule,
                title: 'No automation rules',
                message: 'Create rules for reports, spam, streams, duplicates.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final r in rules)
                  Material(
                    child: ListTile(
                      title: Text(r.name),
                      subtitle: Text(
                        '${r.trigger.label} → ${r.action.label}\n'
                        'Threshold ${r.threshold} · ${r.executionMode.label} · ${r.status.label}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          switch (v) {
                            case 'edit':
                              onEdit(r);
                            case 'enable':
                              onEnable(r);
                            case 'disable':
                              onDisable(r);
                            case 'dup':
                              onDuplicate(r);
                            case 'del':
                              onDelete(r);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'enable',
                            child: Text('Enable'),
                          ),
                          const PopupMenuItem(
                            value: 'disable',
                            child: Text('Disable'),
                          ),
                          const PopupMenuItem(
                            value: 'dup',
                            child: Text('Duplicate'),
                          ),
                          const PopupMenuItem(
                            value: 'del',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                      onTap: () => onEdit(r),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<AiAutomationRule?> showRuleEditor({
  required BuildContext context,
  AiAutomationRule? existing,
  String? organizationId,
}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final desc = TextEditingController(text: existing?.description ?? '');
  var trigger = existing?.trigger ?? AiRuleTriggerType.reportThreshold;
  var action = existing?.action ?? AiRuleActionType.createRecommendation;
  var mode = existing?.executionMode ?? AiRuleExecutionMode.recommendOnly;
  var status = existing?.status ?? AiRuleStatus.draft;
  var threshold = existing?.threshold ?? 3;

  final result = await showDialog<AiAutomationRule>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing == null ? 'Create rule' : 'Edit rule'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: desc,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                DropdownButtonFormField<AiRuleTriggerType>(
                  // ignore: deprecated_member_use
                  value: trigger,
                  decoration: const InputDecoration(labelText: 'If / Trigger'),
                  items: [
                    for (final t in AiRuleTriggerType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) => setLocal(() => trigger = v ?? trigger),
                ),
                DropdownButtonFormField<AiRuleActionType>(
                  // ignore: deprecated_member_use
                  value: action,
                  decoration: const InputDecoration(labelText: 'Then / Action'),
                  items: [
                    for (final a in AiRuleActionType.values)
                      DropdownMenuItem(value: a, child: Text(a.label)),
                  ],
                  onChanged: (v) => setLocal(() => action = v ?? action),
                ),
                DropdownButtonFormField<AiRuleExecutionMode>(
                  // ignore: deprecated_member_use
                  value: mode,
                  decoration: const InputDecoration(labelText: 'Execution'),
                  items: [
                    for (final m in AiRuleExecutionMode.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (v) => setLocal(() => mode = v ?? mode),
                ),
                DropdownButtonFormField<AiRuleStatus>(
                  // ignore: deprecated_member_use
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final s in AiRuleStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) => setLocal(() => status = v ?? status),
                ),
                TextFormField(
                  initialValue: '$threshold',
                  decoration: const InputDecoration(labelText: 'Threshold X'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => threshold = int.tryParse(v) ?? threshold,
                ),
                const SizedBox(height: 8),
                Text(
                  'workflowGraph reserved for future visual builder',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).hintColor,
                  ),
                ),
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
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                AiAutomationRule(
                  id: existing?.id ?? '',
                  name: name.text.trim(),
                  description: desc.text.trim(),
                  status: status,
                  trigger: trigger,
                  action: action,
                  executionMode: mode,
                  threshold: threshold,
                  organizationId: existing?.organizationId ?? organizationId,
                  workflowGraph: existing?.workflowGraph.isNotEmpty == true
                      ? existing!.workflowGraph
                      : {
                          'version': 1,
                          'nodes': [
                            {'id': 'trigger', 'type': trigger.wireValue},
                            {'id': 'action', 'type': action.wireValue},
                          ],
                          'edges': [
                            {'from': 'trigger', 'to': 'action'},
                          ],
                        },
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  desc.dispose();
  return result;
}
