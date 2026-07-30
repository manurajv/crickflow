import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/ground_enums.dart';
import '../../models/ground_filters.dart';

Future<GroundListFilters?> showGroundsFilterDrawer({
  required BuildContext context,
  required GroundListFilters initial,
}) {
  return showGeneralDialog<GroundListFilters>(
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
            child: _GroundsFilterForm(initial: initial),
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

class _GroundsFilterForm extends StatefulWidget {
  const _GroundsFilterForm({required this.initial});

  final GroundListFilters initial;

  @override
  State<_GroundsFilterForm> createState() => _GroundsFilterFormState();
}

class _GroundsFilterFormState extends State<_GroundsFilterForm> {
  late Set<ManagedGroundStatus> _statuses;
  late Set<ManagedGroundType> _types;
  late Set<ManagedGroundBallType> _balls;
  late Set<ManagedGroundPitchType> _pitches;
  late Set<ManagedGroundAvailability> _availability;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  bool _includeDeleted = false;
  bool _includeArchived = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _statuses = {...i.statuses};
    _types = {...i.groundTypes};
    _balls = {...i.ballTypes};
    _pitches = {...i.pitchTypes};
    _availability = {...i.availabilities};
    _country = TextEditingController(text: i.country ?? '');
    _state = TextEditingController(text: i.stateProvince ?? '');
    _city = TextEditingController(text: i.city ?? '');
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

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
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
                    for (final s in ManagedGroundStatus.values)
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
                Text('Ground type',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in ManagedGroundType.values)
                      FilterChip(
                        label: Text(t.label),
                        selected: _types.contains(t),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _types.add(t);
                          } else {
                            _types.remove(t);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Ball type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final b in ManagedGroundBallType.values)
                      FilterChip(
                        label: Text(b.label),
                        selected: _balls.contains(b),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _balls.add(b);
                          } else {
                            _balls.remove(b);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Pitch type',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in ManagedGroundPitchType.values)
                      FilterChip(
                        label: Text(p.label),
                        selected: _pitches.contains(p),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _pitches.add(p);
                          } else {
                            _pitches.remove(p);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Availability',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in ManagedGroundAvailability.values)
                      FilterChip(
                        label: Text(a.label),
                        selected: _availability.contains(a),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _availability.add(a);
                          } else {
                            _availability.remove(a);
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
                      GroundListFilters.empty.copyWith(
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
                        GroundListFilters(
                          query: widget.initial.query,
                          statuses: _statuses,
                          groundTypes: _types,
                          ballTypes: _balls,
                          pitchTypes: _pitches,
                          availabilities: _availability,
                          country: _country.text.trim().isEmpty
                              ? null
                              : _country.text.trim(),
                          stateProvince: _state.text.trim().isEmpty
                              ? null
                              : _state.text.trim(),
                          city: _city.text.trim().isEmpty
                              ? null
                              : _city.text.trim(),
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
