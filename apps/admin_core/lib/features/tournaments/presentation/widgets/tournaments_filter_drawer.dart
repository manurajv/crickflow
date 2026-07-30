import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/tournament_enums.dart';
import '../../models/tournament_filters.dart';

Future<TournamentListFilters?> showTournamentsFilterDrawer({
  required BuildContext context,
  required TournamentListFilters initial,
}) {
  return showGeneralDialog<TournamentListFilters>(
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
            child: _TournamentsFilterForm(initial: initial),
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

class _TournamentsFilterForm extends StatefulWidget {
  const _TournamentsFilterForm({required this.initial});

  final TournamentListFilters initial;

  @override
  State<_TournamentsFilterForm> createState() => _TournamentsFilterFormState();
}

class _TournamentsFilterFormState extends State<_TournamentsFilterForm> {
  late Set<ManagedTournamentStatus> _statuses;
  late Set<ManagedTournamentFormat> _formats;
  late Set<ManagedBallType> _balls;
  late Set<AdminTournamentApproval> _approvals;
  bool? _featured;
  bool? _paidEntry;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  bool _includeDeleted = false;
  bool _includeArchived = false;
  DateTime? _startFrom;
  DateTime? _startTo;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _statuses = {...i.statuses};
    _formats = {...i.formats};
    _balls = {...i.ballTypes};
    _approvals = {...i.approvals};
    _featured = i.featured;
    _paidEntry = i.paidEntry;
    _country = TextEditingController(text: i.country ?? '');
    _state = TextEditingController(text: i.stateProvince ?? '');
    _city = TextEditingController(text: i.city ?? '');
    _includeDeleted = i.includeDeleted;
    _includeArchived = i.includeArchived;
    _startFrom = i.startFrom;
    _startTo = i.startTo;
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
                    for (final s in ManagedTournamentStatus.values)
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
                Text('Format', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in ManagedTournamentFormat.values)
                      FilterChip(
                        label: Text(f.label),
                        selected: _formats.contains(f),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _formats.add(f);
                          } else {
                            _formats.remove(f);
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
                    for (final b in ManagedBallType.values)
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
                Text('Featured', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: _featured == null,
                      onSelected: (_) => setState(() => _featured = null),
                    ),
                    ChoiceChip(
                      label: const Text('Featured'),
                      selected: _featured == true,
                      onSelected: (_) => setState(() => _featured = true),
                    ),
                    ChoiceChip(
                      label: const Text('Not featured'),
                      selected: _featured == false,
                      onSelected: (_) => setState(() => _featured = false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Entry fee', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: _paidEntry == null,
                      onSelected: (_) => setState(() => _paidEntry = null),
                    ),
                    ChoiceChip(
                      label: const Text('Free'),
                      selected: _paidEntry == false,
                      onSelected: (_) => setState(() => _paidEntry = false),
                    ),
                    ChoiceChip(
                      label: const Text('Paid'),
                      selected: _paidEntry == true,
                      onSelected: (_) => setState(() => _paidEntry = true),
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
                      TournamentListFilters.empty
                          .copyWith(query: widget.initial.query),
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
                        TournamentListFilters(
                          query: widget.initial.query,
                          statuses: _statuses,
                          formats: _formats,
                          ballTypes: _balls,
                          featured: _featured,
                          paidEntry: _paidEntry,
                          country: _country.text.trim().isEmpty
                              ? null
                              : _country.text.trim(),
                          stateProvince: _state.text.trim().isEmpty
                              ? null
                              : _state.text.trim(),
                          city: _city.text.trim().isEmpty
                              ? null
                              : _city.text.trim(),
                          startFrom: _startFrom,
                          startTo: _startTo,
                          includeDeleted: _includeDeleted,
                          includeArchived: _includeArchived,
                          approvals: _approvals,
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
