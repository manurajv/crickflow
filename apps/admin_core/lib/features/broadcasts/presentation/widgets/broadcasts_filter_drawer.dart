import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../matches/models/match_enums.dart';
import '../../models/broadcast_enums.dart';
import '../../models/broadcast_filters.dart';

Future<BroadcastListFilters?> showBroadcastsFilterDrawer({
  required BuildContext context,
  required BroadcastListFilters initial,
}) {
  return showGeneralDialog<BroadcastListFilters>(
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
            child: _BroadcastsFilterForm(initial: initial),
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

class _BroadcastsFilterForm extends StatefulWidget {
  const _BroadcastsFilterForm({required this.initial});

  final BroadcastListFilters initial;

  @override
  State<_BroadcastsFilterForm> createState() => _BroadcastsFilterFormState();
}

class _BroadcastsFilterFormState extends State<_BroadcastsFilterForm> {
  late Set<ManagedBroadcastStatus> _statuses;
  late Set<ManagedStreamPlatform> _platforms;
  late Set<ManagedBroadcastHealth> _health;
  late Set<ManagedBroadcastVisibility> _visibilities;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  DateTime? _from;
  DateTime? _to;
  bool _includeDeleted = false;
  bool _includeArchived = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _statuses = {...i.statuses};
    _platforms = {...i.platforms};
    _health = {...i.health};
    _visibilities = {...i.visibilities};
    _country = TextEditingController(text: i.country ?? '');
    _state = TextEditingController(text: i.stateProvince ?? '');
    _city = TextEditingController(text: i.city ?? '');
    _from = i.from;
    _to = i.to;
    _includeDeleted = i.includeDeleted;
    _includeArchived = i.includeArchived;
  }

  @override
  void dispose() {
    _country.dispose();
    _state.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
                    for (final s in ManagedBroadcastStatus.values)
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
                Text('Platform', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in ManagedStreamPlatform.values)
                      FilterChip(
                        label: Text(p.label),
                        selected: _platforms.contains(p),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _platforms.add(p);
                          } else {
                            _platforms.remove(p);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Health', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final h in ManagedBroadcastHealth.values)
                      FilterChip(
                        label: Text(h.label),
                        selected: _health.contains(h),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _health.add(h);
                          } else {
                            _health.remove(h);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Visibility',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in ManagedBroadcastVisibility.values)
                      FilterChip(
                        label: Text(v.label),
                        selected: _visibilities.contains(v),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _visibilities.add(v);
                          } else {
                            _visibilities.remove(v);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                Text('Date range', style: Theme.of(context).textTheme.titleSmall),
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
                  title: const Text('Include soft-deleted'),
                  value: _includeDeleted,
                  onChanged: (v) => setState(() => _includeDeleted = v),
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
                      BroadcastListFilters.empty.copyWith(
                        query: widget.initial.query,
                        liveOnly: widget.initial.liveOnly,
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
                        BroadcastListFilters(
                          query: widget.initial.query,
                          statuses: _statuses,
                          platforms: _platforms,
                          health: _health,
                          visibilities: _visibilities,
                          liveOnly: widget.initial.liveOnly,
                          country: _country.text.trim().isEmpty
                              ? null
                              : _country.text.trim(),
                          stateProvince: _state.text.trim().isEmpty
                              ? null
                              : _state.text.trim(),
                          city: _city.text.trim().isEmpty
                              ? null
                              : _city.text.trim(),
                          from: _from,
                          to: _to,
                          includeDeleted: _includeDeleted,
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
