import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/ads_enums.dart';
import '../../models/ads_filters.dart';

Future<AdsListFilters?> showAdsFilterDrawer({
  required BuildContext context,
  required AdsListFilters initial,
}) {
  return showGeneralDialog<AdsListFilters>(
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
            child: _AdsFilterForm(initial: initial),
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

class _AdsFilterForm extends StatefulWidget {
  const _AdsFilterForm({required this.initial});

  final AdsListFilters initial;

  @override
  State<_AdsFilterForm> createState() => _AdsFilterFormState();
}

class _AdsFilterFormState extends State<_AdsFilterForm> {
  late Set<ManagedAdStatus> _statuses;
  late Set<ManagedAdPlacement> _placements;
  late Set<ManagedAdMediaType> _mediaTypes;
  late Set<ManagedAdCampaignType> _campaignTypes;
  DateTime? _from;
  DateTime? _to;
  bool _pendingOnly = false;
  bool _includeArchived = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _statuses = {...i.statuses};
    _placements = {...i.placements};
    _mediaTypes = {...i.mediaTypes};
    _campaignTypes = {...i.campaignTypes};
    _from = i.from;
    _to = i.to;
    _pendingOnly = i.pendingOnly;
    _includeArchived = i.includeArchived;
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        if (from) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final dateFmt = DateFormat('yyyy-MM-dd');
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Status', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in ManagedAdStatus.values)
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
                const SizedBox(height: 16),
                Text('Placement',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in ManagedAdPlacement.values)
                      FilterChip(
                        label: Text(p.label),
                        selected: _placements.contains(p),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _placements.add(p);
                          } else {
                            _placements.remove(p);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Media type',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in ManagedAdMediaType.values)
                      FilterChip(
                        label: Text(m.label),
                        selected: _mediaTypes.contains(m),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _mediaTypes.add(m);
                          } else {
                            _mediaTypes.remove(m);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Campaign type',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in ManagedAdCampaignType.values)
                      FilterChip(
                        label: Text(t.label),
                        selected: _campaignTypes.contains(t),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _campaignTypes.add(t);
                          } else {
                            _campaignTypes.remove(t);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Date range',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(from: true),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _from == null ? 'From' : dateFmt.format(_from!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(from: false),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _to == null ? 'To' : dateFmt.format(_to!),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_from != null || _to != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _from = null;
                        _to = null;
                      }),
                      child: const Text('Clear dates'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pending approval only'),
                  value: _pendingOnly,
                  onChanged: (v) => setState(() => _pendingOnly = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include archived'),
                  value: _includeArchived,
                  onChanged: (v) => setState(() => _includeArchived = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      AdsListFilters.empty.copyWith(
                        query: widget.initial.query,
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        AdsListFilters(
                          query: widget.initial.query,
                          statuses: _statuses,
                          placements: _placements,
                          mediaTypes: _mediaTypes,
                          campaignTypes: _campaignTypes,
                          from: _from,
                          to: _to,
                          pendingOnly: _pendingOnly,
                          includeArchived: _includeArchived,
                        ),
                      );
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
