import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/organization_enums.dart';
import '../../models/organization_filters.dart';

Future<OrganizationListFilters?> showOrganizationsFilterDrawer({
  required BuildContext context,
  required OrganizationListFilters initial,
}) {
  return showGeneralDialog<OrganizationListFilters>(
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
            child: _OrganizationsFilterForm(initial: initial),
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

class _OrganizationsFilterForm extends StatefulWidget {
  const _OrganizationsFilterForm({required this.initial});

  final OrganizationListFilters initial;

  @override
  State<_OrganizationsFilterForm> createState() =>
      _OrganizationsFilterFormState();
}

class _OrganizationsFilterFormState extends State<_OrganizationsFilterForm> {
  late Set<ManagedOrganizationStatus> _statuses;
  late Set<ManagedOrganizationType> _types;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  bool _includeDeleted = false;
  bool _includeArchived = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _statuses = {...i.statuses};
    _types = {...i.types};
    _country = TextEditingController(text: i.country ?? '');
    _state = TextEditingController(text: i.stateProvince ?? '');
    _city = TextEditingController(text: i.city ?? '');
    _includeDeleted = i.includeDeleted;
    _includeArchived = i.includeArchived;
    _dateFrom = i.registrationDateFrom;
    _dateTo = i.registrationDateTo;
  }

  @override
  void dispose() {
    _country.dispose();
    _state.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (_dateFrom ?? DateTime.now().subtract(const Duration(days: 365)))
        : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter Organizations',
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
                // Status
                _sectionLabel(context, 'Status'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in ManagedOrganizationStatus.values
                        .where((s) => s != ManagedOrganizationStatus.deleted))
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
                const SizedBox(height: 20),
                // Type
                _sectionLabel(context, 'Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in ManagedOrganizationType.values)
                      FilterChip(
                        label: Text(t.shortLabel),
                        tooltip: t.label,
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
                const SizedBox(height: 20),
                // Location
                _sectionLabel(context, 'Location'),
                const SizedBox(height: 8),
                TextField(
                  controller: _country,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _state,
                  decoration: const InputDecoration(
                    labelText: 'State / Province',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                // Registration Date
                _sectionLabel(context, 'Registration Date'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerButton(
                        label: _dateFrom != null
                            ? _dateFmt.format(_dateFrom!)
                            : 'From date',
                        onTap: () => _pickDate(true),
                        onClear: _dateFrom != null
                            ? () => setState(() => _dateFrom = null)
                            : null,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('—'),
                    ),
                    Expanded(
                      child: _DatePickerButton(
                        label: _dateTo != null
                            ? _dateFmt.format(_dateTo!)
                            : 'To date',
                        onTap: () => _pickDate(false),
                        onClear:
                            _dateTo != null ? () => setState(() => _dateTo = null) : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Include archived/deleted
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Archived'),
                  value: _includeArchived,
                  onChanged: (v) => setState(() => _includeArchived = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Include Deleted',
                    style: TextStyle(color: colors.error),
                  ),
                  value: _includeDeleted,
                  onChanged: (v) => setState(() => _includeDeleted = v ?? false),
                ),
              ],
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _statuses.clear();
                      _types.clear();
                      _country.clear();
                      _state.clear();
                      _city.clear();
                      _includeDeleted = false;
                      _includeArchived = false;
                      _dateFrom = null;
                      _dateTo = null;
                    });
                  },
                  child: const Text('Reset All'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      OrganizationListFilters(
                        query: widget.initial.query,
                        statuses: _statuses,
                        types: _types,
                        country: _country.text.trim().isEmpty
                            ? null
                            : _country.text.trim(),
                        stateProvince: _state.text.trim().isEmpty
                            ? null
                            : _state.text.trim(),
                        city: _city.text.trim().isEmpty
                            ? null
                            : _city.text.trim(),
                        registrationDateFrom: _dateFrom,
                        registrationDateTo: _dateTo,
                        includeDeleted: _includeDeleted,
                        includeArchived: _includeArchived,
                      ),
                    );
                  },
                  child: const Text('Apply Filters'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.5,
        color: context.adminColors.textMuted,
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.label,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        alignment: Alignment.centerLeft,
      ),
      onPressed: onTap,
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16),
            ),
        ],
      ),
    );
  }
}
