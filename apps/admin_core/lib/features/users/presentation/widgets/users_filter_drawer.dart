import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../models/admin_role.dart';
import '../../models/user_account_status.dart';
import '../../models/user_filters.dart';

Future<UserListFilters?> showUsersFilterDrawer({
  required BuildContext context,
  required UserListFilters initial,
}) {
  return showGeneralDialog<UserListFilters>(
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
            child: _UsersFilterForm(initial: initial),
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

class _UsersFilterForm extends StatefulWidget {
  const _UsersFilterForm({required this.initial});

  final UserListFilters initial;

  @override
  State<_UsersFilterForm> createState() => _UsersFilterFormState();
}

class _UsersFilterFormState extends State<_UsersFilterForm> {
  late Set<UserAccountStatus> _statuses;
  late Set<AdminRole> _roles;
  bool? _verified;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  String? _gender;
  DateTime? _joinedFrom;
  DateTime? _joinedTo;
  DateTime? _lastLoginFrom;
  DateTime? _lastLoginTo;

  @override
  void initState() {
    super.initState();
    _statuses = {...widget.initial.statuses};
    _roles = {...widget.initial.adminRoles};
    _verified = widget.initial.verified;
    _country = TextEditingController(text: widget.initial.country ?? '');
    _state = TextEditingController(text: widget.initial.stateProvince ?? '');
    _city = TextEditingController(text: widget.initial.city ?? '');
    _gender = widget.initial.gender;
    _joinedFrom = widget.initial.joinedFrom;
    _joinedTo = widget.initial.joinedTo;
    _lastLoginFrom = widget.initial.lastLoginFrom;
    _lastLoginTo = widget.initial.lastLoginTo;
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
                    for (final s in UserAccountStatus.values)
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
                Text('Admin role', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in [
                      AdminRole.superAdmin,
                      AdminRole.admin,
                      AdminRole.moderator,
                      AdminRole.tournamentAdmin,
                      AdminRole.support,
                    ])
                      FilterChip(
                        label: Text(r.label),
                        selected: _roles.contains(r),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _roles.add(r);
                          } else {
                            _roles.remove(r);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Verification',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: _verified == null,
                      onSelected: (_) => setState(() => _verified = null),
                    ),
                    ChoiceChip(
                      label: const Text('Verified'),
                      selected: _verified == true,
                      onSelected: (_) => setState(() => _verified = true),
                    ),
                    ChoiceChip(
                      label: const Text('Not verified'),
                      selected: _verified == false,
                      onSelected: (_) => setState(() => _verified = false),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any')),
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 20),
                Text('Joined date',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _DateRangeRow(
                  from: _joinedFrom,
                  to: _joinedTo,
                  onFrom: (d) => setState(() => _joinedFrom = d),
                  onTo: (d) => setState(() => _joinedTo = d),
                ),
                const SizedBox(height: 16),
                Text('Last login',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _DateRangeRow(
                  from: _lastLoginFrom,
                  to: _lastLoginTo,
                  onFrom: (d) => setState(() => _lastLoginFrom = d),
                  onTo: (d) => setState(() => _lastLoginTo = d),
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
                      UserListFilters.empty.copyWith(query: widget.initial.query),
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
                        UserListFilters(
                          query: widget.initial.query,
                          statuses: _statuses,
                          adminRoles: _roles,
                          verified: _verified,
                          country: _country.text.trim().isEmpty
                              ? null
                              : _country.text.trim(),
                          stateProvince: _state.text.trim().isEmpty
                              ? null
                              : _state.text.trim(),
                          city: _city.text.trim().isEmpty
                              ? null
                              : _city.text.trim(),
                          gender: _gender,
                          joinedFrom: _joinedFrom,
                          joinedTo: _joinedTo,
                          lastLoginFrom: _lastLoginFrom,
                          lastLoginTo: _lastLoginTo,
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

class _DateRangeRow extends StatelessWidget {
  const _DateRangeRow({
    required this.from,
    required this.to,
    required this.onFrom,
    required this.onTo,
  });

  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime?> onFrom;
  final ValueChanged<DateTime?> onTo;

  Future<void> _pick(
    BuildContext context, {
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2018),
      lastDate: now.add(const Duration(days: 1)),
    );
    onPicked(picked);
  }

  String _label(DateTime? d) =>
      d == null ? 'Any' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pick(context, current: from, onPicked: onFrom),
            onLongPress: () => onFrom(null),
            child: Text('From: ${_label(from)}'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _pick(context, current: to, onPicked: onTo),
            onLongPress: () => onTo(null),
            child: Text('To: ${_label(to)}'),
          ),
        ),
      ],
    );
  }
}
