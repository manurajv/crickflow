import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/moderation_enums.dart';
import '../../models/moderation_filters.dart';

Future<ModerationListFilters?> showModerationFilterDrawer({
  required BuildContext context,
  required ModerationListFilters initial,
  bool showSourceFilters = true,
}) {
  return showGeneralDialog<ModerationListFilters>(
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
            child: _ModerationFilterForm(
              initial: initial,
              showSourceFilters: showSourceFilters,
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

class _ModerationFilterForm extends StatefulWidget {
  const _ModerationFilterForm({
    required this.initial,
    required this.showSourceFilters,
  });

  final ModerationListFilters initial;
  final bool showSourceFilters;

  @override
  State<_ModerationFilterForm> createState() => _ModerationFilterFormState();
}

class _ModerationFilterFormState extends State<_ModerationFilterForm> {
  late Set<ManagedPostAdminStatus> _statuses;
  late Set<ModerationSource> _sources;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  DateTime? _from;
  DateTime? _to;
  bool _includeRemoved = false;
  bool _tournamentOnly = false;
  String? _mediaType;

  static const _mediaTypes = ['image', 'video', 'multiple', 'none'];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _statuses = {...i.statuses};
    _sources = {...i.sources};
    _country = TextEditingController(text: i.country ?? '');
    _state = TextEditingController(text: i.stateProvince ?? '');
    _city = TextEditingController(text: i.city ?? '');
    _from = i.from;
    _to = i.to;
    _includeRemoved = i.includeRemoved;
    _tournamentOnly = i.tournamentOnly;
    _mediaType = i.mediaType;
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
                    for (final s in ManagedPostAdminStatus.values)
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
                if (widget.showSourceFilters) ...[
                  const SizedBox(height: 16),
                  Text('Source', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final src in [
                        ModerationSource.community,
                        ModerationSource.discover,
                      ])
                        FilterChip(
                          label: Text(
                            src == ModerationSource.community
                                ? 'Community'
                                : 'Discover',
                          ),
                          selected: _sources.contains(src),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _sources.add(src);
                            } else {
                              _sources.remove(src);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text('Media type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in _mediaTypes)
                      FilterChip(
                        label: Text(m[0].toUpperCase() + m.substring(1)),
                        selected: _mediaType == m,
                        onSelected: (v) => setState(() {
                          _mediaType = v ? m : null;
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
                  title: const Text('Include removed'),
                  value: _includeRemoved,
                  onChanged: (v) => setState(() => _includeRemoved = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tournament posts only'),
                  value: _tournamentOnly,
                  onChanged: (v) => setState(() => _tournamentOnly = v),
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
                      ModerationListFilters.empty.copyWith(
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
                        ModerationListFilters(
                          query: widget.initial.query,
                          statuses: _statuses,
                          sources: _sources,
                          mediaType: _mediaType,
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
                          tournamentOnly: _tournamentOnly,
                          includeRemoved: _includeRemoved,
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
