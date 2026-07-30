import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../models/analytics_enums.dart';
import '../../models/analytics_filters.dart';

class AnalyticsSectionChips extends StatelessWidget {
  const AnalyticsSectionChips({
    super.key,
    required this.section,
    required this.onChanged,
  });

  final AnalyticsHubSection section;
  final ValueChanged<AnalyticsHubSection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in AnalyticsHubSection.values) ...[
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

class AnalyticsToolbar extends StatelessWidget {
  const AnalyticsToolbar({
    super.key,
    required this.period,
    required this.onPeriodChanged,
    required this.onFilter,
    required this.onRefresh,
    required this.filterActive,
    required this.refreshing,
  });

  final AnalyticsPeriod period;
  final ValueChanged<AnalyticsPeriod> onPeriodChanged;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final bool filterActive;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final p in [
              AnalyticsPeriod.daily,
              AnalyticsPeriod.weekly,
              AnalyticsPeriod.monthly,
              AnalyticsPeriod.yearly,
            ])
              ChoiceChip(
                label: Text(p.label),
                selected: period == p,
                onSelected: (_) => onPeriodChanged(p),
              ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                'Read-only insights',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<AnalyticsFilters?> showAnalyticsFilterDrawer({
  required BuildContext context,
  required AnalyticsFilters initial,
  required bool isSuperAdmin,
}) {
  return showGeneralDialog<AnalyticsFilters>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Filters',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, anim, secondary) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: context.adminColors.surface,
          elevation: 12,
          child: SizedBox(
            width: 420,
            height: double.infinity,
            child: _AnalyticsFilterForm(
              initial: initial,
              isSuperAdmin: isSuperAdmin,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim, secondary, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

class _AnalyticsFilterForm extends StatefulWidget {
  const _AnalyticsFilterForm({
    required this.initial,
    required this.isSuperAdmin,
  });

  final AnalyticsFilters initial;
  final bool isSuperAdmin;

  @override
  State<_AnalyticsFilterForm> createState() => _AnalyticsFilterFormState();
}

class _AnalyticsFilterFormState extends State<_AnalyticsFilterForm> {
  late AnalyticsPeriod _period;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  late TextEditingController _orgId;
  late TextEditingController _tournamentId;
  late TextEditingController _matchType;
  late TextEditingController _ballType;
  late TextEditingController _platform;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _period = i.period;
    _country = TextEditingController(text: i.country ?? '');
    _state = TextEditingController(text: i.stateProvince ?? '');
    _city = TextEditingController(text: i.city ?? '');
    _orgId = TextEditingController(text: i.organizationId ?? '');
    _tournamentId = TextEditingController(text: i.tournamentId ?? '');
    _matchType = TextEditingController(text: i.matchType ?? '');
    _ballType = TextEditingController(text: i.ballType ?? '');
    _platform = TextEditingController(text: i.streamingPlatform ?? '');
    _from = i.from;
    _to = i.to;
  }

  @override
  void dispose() {
    _country.dispose();
    _state.dispose();
    _city.dispose();
    _orgId.dispose();
    _tournamentId.dispose();
    _matchType.dispose();
    _ballType.dispose();
    _platform.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() {
        _from = d;
        _period = AnalyticsPeriod.custom;
      });
    }
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() {
        _to = d;
        _period = AnalyticsPeriod.custom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Analytics filters',
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
                DropdownButtonFormField<AnalyticsPeriod>(
                  // ignore: deprecated_member_use
                  value: _period,
                  decoration: const InputDecoration(labelText: 'Period'),
                  items: [
                    for (final p in AnalyticsPeriod.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _period = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickFrom,
                        child: Text(
                          _from == null
                              ? 'From date'
                              : _from!.toIso8601String().split('T').first,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTo,
                        child: Text(
                          _to == null
                              ? 'To date'
                              : _to!.toIso8601String().split('T').first,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _country,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _state,
                  decoration:
                      const InputDecoration(labelText: 'State / Province'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                if (widget.isSuperAdmin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _orgId,
                    decoration: const InputDecoration(
                      labelText: 'Organization ID',
                      hintText: 'Optional org scope',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _tournamentId,
                  decoration:
                      const InputDecoration(labelText: 'Tournament ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _matchType,
                  decoration: const InputDecoration(labelText: 'Match type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ballType,
                  decoration: const InputDecoration(labelText: 'Ball type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _platform,
                  decoration: const InputDecoration(
                    labelText: 'Streaming platform',
                    hintText: 'youtube / facebook / rtmp',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CfButton(
                  label: 'Reset',
                  variant: CfButtonVariant.ghost,
                  onPressed: () => Navigator.pop(context, AnalyticsFilters.empty),
                ),
                const Spacer(),
                CfButton(
                  label: 'Apply',
                  onPressed: () {
                    Navigator.pop(
                      context,
                      AnalyticsFilters(
                        period: _period,
                        from: _from,
                        to: _to,
                        country: _nullIfEmpty(_country.text),
                        stateProvince: _nullIfEmpty(_state.text),
                        city: _nullIfEmpty(_city.text),
                        organizationId: widget.isSuperAdmin
                            ? _nullIfEmpty(_orgId.text)
                            : widget.initial.organizationId,
                        tournamentId: _nullIfEmpty(_tournamentId.text),
                        matchType: _nullIfEmpty(_matchType.text),
                        ballType: _nullIfEmpty(_ballType.text),
                        streamingPlatform: _nullIfEmpty(_platform.text),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _nullIfEmpty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
