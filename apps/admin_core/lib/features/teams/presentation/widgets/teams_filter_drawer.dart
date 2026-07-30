import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/team_enums.dart';
import '../../models/team_filters.dart';

Future<TeamListFilters?> showTeamsFilterDrawer({
  required BuildContext context,
  required TeamListFilters initial,
}) {
  return showGeneralDialog<TeamListFilters>(
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
            child: _TeamsFilterForm(initial: initial),
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

class _TeamsFilterForm extends StatefulWidget {
  const _TeamsFilterForm({required this.initial});

  final TeamListFilters initial;

  @override
  State<_TeamsFilterForm> createState() => _TeamsFilterFormState();
}

class _TeamsFilterFormState extends State<_TeamsFilterForm> {
  late Set<ManagedTeamStatus> _statuses;
  late Set<ManagedTeamBallType> _balls;
  late Set<ManagedTeamCategory> _categories;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  late TextEditingController _minMembers;
  late TextEditingController _maxMembers;
  bool _includeDeleted = false;
  bool _includeArchived = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _statuses = {...i.statuses};
    _balls = {...i.ballTypes};
    _categories = {...i.categories};
    _country = TextEditingController(text: i.country ?? '');
    _state = TextEditingController(text: i.stateProvince ?? '');
    _city = TextEditingController(text: i.city ?? '');
    _minMembers = TextEditingController(
      text: i.minMembers?.toString() ?? '',
    );
    _maxMembers = TextEditingController(
      text: i.maxMembers?.toString() ?? '',
    );
    _includeDeleted = i.includeDeleted;
    _includeArchived = i.includeArchived;
  }

  @override
  void dispose() {
    _country.dispose();
    _state.dispose();
    _city.dispose();
    _minMembers.dispose();
    _maxMembers.dispose();
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
                    for (final s in ManagedTeamStatus.values)
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
                Text('Ball type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final b in ManagedTeamBallType.values)
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
                Text('Category', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in ManagedTeamCategory.values)
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
                Text(
                  'Members count',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minMembers,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Min'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxMembers,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Max'),
                      ),
                    ),
                  ],
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
                      TeamListFilters.empty.copyWith(
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
                        TeamListFilters(
                          query: widget.initial.query,
                          statuses: _statuses,
                          ballTypes: _balls,
                          categories: _categories,
                          country: _country.text.trim().isEmpty
                              ? null
                              : _country.text.trim(),
                          stateProvince: _state.text.trim().isEmpty
                              ? null
                              : _state.text.trim(),
                          city: _city.text.trim().isEmpty
                              ? null
                              : _city.text.trim(),
                          minMembers: int.tryParse(_minMembers.text.trim()),
                          maxMembers: int.tryParse(_maxMembers.text.trim()),
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
