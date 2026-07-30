import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/match_enums.dart';
import '../../models/match_filters.dart';

Future<MatchListFilters?> showMatchesFilterDrawer({
  required BuildContext context,
  required MatchListFilters initial,
}) {
  return showGeneralDialog<MatchListFilters>(
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
            child: _MatchesFilterForm(initial: initial),
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

class _MatchesFilterForm extends StatefulWidget {
  const _MatchesFilterForm({required this.initial});

  final MatchListFilters initial;

  @override
  State<_MatchesFilterForm> createState() => _MatchesFilterFormState();
}

class _MatchesFilterFormState extends State<_MatchesFilterForm> {
  late Set<ManagedMatchStatus> _statuses;
  late Set<ManagedBallType> _balls;
  late Set<ManagedMatchType> _types;
  late Set<ManagedCricketType> _formats;
  late Set<ManagedStreamPlatform> _platforms;
  bool? _streaming;
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
    _balls = {...i.ballTypes};
    _types = {...i.matchTypes};
    _formats = {...i.formats};
    _platforms = {...i.platforms};
    _streaming = i.streaming;
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
                    for (final s in ManagedMatchStatus.values)
                      FilterChip(
                        label: Text(s.label),
                        selected: _statuses.contains(s),
                        onSelected: (v) => setState(
                          () => v ? _statuses.add(s) : _statuses.remove(s),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Ball type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in ManagedBallType.values)
                      FilterChip(
                        label: Text(s.label),
                        selected: _balls.contains(s),
                        onSelected: (v) => setState(
                          () => v ? _balls.add(s) : _balls.remove(s),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Match type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in ManagedMatchType.values)
                      FilterChip(
                        label: Text(s.label),
                        selected: _types.contains(s),
                        onSelected: (v) => setState(
                          () => v ? _types.add(s) : _types.remove(s),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Format', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in ManagedCricketType.values)
                      FilterChip(
                        label: Text(s.label),
                        selected: _formats.contains(s),
                        onSelected: (v) => setState(
                          () => v ? _formats.add(s) : _formats.remove(s),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Streaming', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: _streaming == null,
                      onSelected: (_) => setState(() => _streaming = null),
                    ),
                    ChoiceChip(
                      label: const Text('Streaming'),
                      selected: _streaming == true,
                      onSelected: (_) => setState(() => _streaming = true),
                    ),
                    ChoiceChip(
                      label: const Text('Not Streaming'),
                      selected: _streaming == false,
                      onSelected: (_) => setState(() => _streaming = false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Platform', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in [
                      ManagedStreamPlatform.youtube,
                      ManagedStreamPlatform.facebook,
                      ManagedStreamPlatform.externalRtmp,
                      ManagedStreamPlatform.none,
                    ])
                      FilterChip(
                        label: Text(s.label),
                        selected: _platforms.contains(s),
                        onSelected: (v) => setState(
                          () => v ? _platforms.add(s) : _platforms.remove(s),
                        ),
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
                  decoration: const InputDecoration(labelText: 'State / Province'),
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
                      MatchListFilters.empty.copyWith(
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
                        MatchListFilters(
                          query: widget.initial.query,
                          statuses: _statuses,
                          ballTypes: _balls,
                          matchTypes: _types,
                          formats: _formats,
                          streaming: _streaming,
                          platforms: _platforms,
                          country:
                              _country.text.trim().isEmpty ? null : _country.text.trim(),
                          stateProvince:
                              _state.text.trim().isEmpty ? null : _state.text.trim(),
                          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
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
