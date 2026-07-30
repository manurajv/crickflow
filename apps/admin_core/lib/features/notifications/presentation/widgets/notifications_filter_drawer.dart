import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/notification_enums.dart';
import '../../models/notification_filters.dart';

Future<NotificationListFilters?> showNotificationsFilterDrawer({
  required BuildContext context,
  required NotificationListFilters initial,
}) {
  return showGeneralDialog<NotificationListFilters>(
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
            child: _NotificationsFilterForm(initial: initial),
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

class _NotificationsFilterForm extends StatefulWidget {
  const _NotificationsFilterForm({required this.initial});

  final NotificationListFilters initial;

  @override
  State<_NotificationsFilterForm> createState() =>
      _NotificationsFilterFormState();
}

class _NotificationsFilterFormState extends State<_NotificationsFilterForm> {
  late Set<ManagedNotificationType> _types;
  late Set<ManagedNotificationStatus> _statuses;
  late Set<ManagedNotificationAudience> _audiences;
  late Set<ManagedPlatformTarget> _platforms;
  DateTime? _from;
  DateTime? _to;
  bool _scheduledOnly = false;
  bool _includeArchived = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _types = {...i.types};
    _statuses = {...i.statuses};
    _audiences = {...i.audiences};
    _platforms = {...i.platforms};
    _from = i.from;
    _to = i.to;
    _scheduledOnly = i.scheduledOnly;
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
                Text('Type', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in ManagedNotificationType.values)
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
                Text('Status', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in ManagedNotificationStatus.values)
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
                Text('Audience',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in ManagedNotificationAudience.values)
                      FilterChip(
                        label: Text(a.label),
                        selected: _audiences.contains(a),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _audiences.add(a);
                          } else {
                            _audiences.remove(a);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Platform',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in ManagedPlatformTarget.values)
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
                  title: const Text('Scheduled only'),
                  value: _scheduledOnly,
                  onChanged: (v) => setState(() => _scheduledOnly = v),
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
                      NotificationListFilters.empty.copyWith(
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
                        NotificationListFilters(
                          query: widget.initial.query,
                          types: _types,
                          statuses: _statuses,
                          audiences: _audiences,
                          platforms: _platforms,
                          from: _from,
                          to: _to,
                          scheduledOnly: _scheduledOnly,
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
