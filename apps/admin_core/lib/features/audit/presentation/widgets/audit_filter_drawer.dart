import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../models/audit_enums.dart';
import '../../models/audit_filters.dart';

Future<AuditListFilters?> showAuditFilterDrawer({
  required BuildContext context,
  required AuditListFilters initial,
}) {
  return showGeneralDialog<AuditListFilters>(
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
            child: _AuditFilterForm(initial: initial),
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

class _AuditFilterForm extends StatefulWidget {
  const _AuditFilterForm({required this.initial});

  final AuditListFilters initial;

  @override
  State<_AuditFilterForm> createState() => _AuditFilterFormState();
}

class _AuditFilterFormState extends State<_AuditFilterForm> {
  late Set<AuditModule> _modules;
  late Set<AuditSeverity> _severities;
  late Set<AuditStatus> _statuses;
  late TextEditingController _action;
  late TextEditingController _actor;
  late TextEditingController _role;
  late TextEditingController _org;
  late TextEditingController _country;
  late TextEditingController _state;
  late TextEditingController _city;
  late TextEditingController _platform;
  late TextEditingController _device;
  late TextEditingController _browser;
  DateTime? _from;
  DateTime? _to;

  static final _df = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _modules = {...i.modules};
    _severities = {...i.severities};
    _statuses = {...i.statuses};
    _action = TextEditingController(text: i.action ?? '');
    _actor = TextEditingController(text: i.actorEmail ?? '');
    _role = TextEditingController(text: i.role ?? '');
    _org = TextEditingController(text: i.organizationId ?? '');
    _country = TextEditingController(text: i.country ?? '');
    _state = TextEditingController(text: i.stateProvince ?? '');
    _city = TextEditingController(text: i.city ?? '');
    _platform = TextEditingController(text: i.platform ?? '');
    _device = TextEditingController(text: i.device ?? '');
    _browser = TextEditingController(text: i.browser ?? '');
    _from = i.from;
    _to = i.to;
  }

  @override
  void dispose() {
    _action.dispose();
    _actor.dispose();
    _role.dispose();
    _org.dispose();
    _country.dispose();
    _state.dispose();
    _city.dispose();
    _platform.dispose();
    _device.dispose();
    _browser.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_from ?? DateTime.now().subtract(const Duration(days: 30)))
          : (_to ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
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
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter Audit Logs',
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
                Text('Severity',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: colors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in AuditSeverity.values)
                      FilterChip(
                        label: Text(s.label),
                        selected: _severities.contains(s),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _severities.add(s);
                          } else {
                            _severities.remove(s);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Status',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: colors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in AuditStatus.values)
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
                Text('Module',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: colors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in AuditModule.values)
                      FilterChip(
                        label: Text(m.label),
                        selected: _modules.contains(m),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _modules.add(m);
                          } else {
                            _modules.remove(m);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _action,
                  decoration: const InputDecoration(labelText: 'Action'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _actor,
                  decoration: const InputDecoration(labelText: 'User (email)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _org,
                  decoration:
                      const InputDecoration(labelText: 'Organization ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _country,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _state,
                  decoration: const InputDecoration(labelText: 'State'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _platform,
                  decoration: const InputDecoration(labelText: 'Platform'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _device,
                  decoration: const InputDecoration(labelText: 'Device'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _browser,
                  decoration: const InputDecoration(labelText: 'Browser'),
                ),
                const SizedBox(height: 16),
                Text('Date Range',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: colors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pick(true),
                        child: Text(
                          _from == null ? 'From' : _df.format(_from!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pick(false),
                        child: Text(_to == null ? 'To' : _df.format(_to!)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _modules.clear();
                      _severities.clear();
                      _statuses.clear();
                      _action.clear();
                      _actor.clear();
                      _role.clear();
                      _org.clear();
                      _country.clear();
                      _state.clear();
                      _city.clear();
                      _platform.clear();
                      _device.clear();
                      _browser.clear();
                      _from = null;
                      _to = null;
                    });
                  },
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      AuditListFilters(
                        query: widget.initial.query,
                        modules: _modules,
                        severities: _severities,
                        statuses: _statuses,
                        action: _action.text.trim().isEmpty
                            ? null
                            : _action.text.trim(),
                        actorEmail: _actor.text.trim().isEmpty
                            ? null
                            : _actor.text.trim(),
                        role: _role.text.trim().isEmpty
                            ? null
                            : _role.text.trim(),
                        organizationId: _org.text.trim().isEmpty
                            ? null
                            : _org.text.trim(),
                        country: _country.text.trim().isEmpty
                            ? null
                            : _country.text.trim(),
                        stateProvince: _state.text.trim().isEmpty
                            ? null
                            : _state.text.trim(),
                        city: _city.text.trim().isEmpty
                            ? null
                            : _city.text.trim(),
                        platform: _platform.text.trim().isEmpty
                            ? null
                            : _platform.text.trim(),
                        device: _device.text.trim().isEmpty
                            ? null
                            : _device.text.trim(),
                        browser: _browser.text.trim().isEmpty
                            ? null
                            : _browser.text.trim(),
                        from: _from,
                        to: _to,
                      ),
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
