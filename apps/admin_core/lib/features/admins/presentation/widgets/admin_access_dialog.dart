import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/admin_app_type.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../models/admin_permission.dart';
import '../../../../models/role_definition.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_status_badge.dart';
import '../../models/admin_account.dart';
import '../../providers/admin_accounts_providers.dart';

/// Opens the grant / edit access dialog. Returns true when saved.
Future<bool?> showAdminAccessDialog(
  BuildContext context, {
  AdminAccount? existing,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AdminAccessDialog(existing: existing),
  );
}

String panelLabel(RoleDefinition role) => switch (role.allowedPanel) {
  AdminAppType.superAdmin => 'Super Admin panel',
  null => 'No panel access (legacy role)',
};

enum _Override { roleDefault, allow, deny }

class AdminAccessDialog extends ConsumerStatefulWidget {
  const AdminAccessDialog({super.key, this.existing});

  final AdminAccount? existing;

  @override
  ConsumerState<AdminAccessDialog> createState() => _AdminAccessDialogState();
}

class _AdminAccessDialogState extends ConsumerState<AdminAccessDialog> {
  final _lookup = TextEditingController();
  final _name = TextEditingController();
  final _reason = TextEditingController();
  final _manualEmail = TextEditingController();

  AdminCandidate? _candidate;
  String? _roleId;
  late Map<String, bool> _overrides;
  bool _busy = false;
  bool _lookingUp = false;
  String? _error;
  String? _lookupMessage;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _overrides = {...?e?.permissionOverrides};
    if (e != null) {
      _candidate = AdminCandidate(
        uid: e.uid,
        email: e.email,
        displayName: e.displayName,
        photoUrl: e.photoUrl,
        existing: e,
        source: 'admin_users',
      );
      _roleId = e.roleId;
      _name.text = e.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _lookup.dispose();
    _name.dispose();
    _reason.dispose();
    _manualEmail.dispose();
    super.dispose();
  }

  Future<void> _runLookup() async {
    final key = _lookup.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _lookingUp = true;
      _lookupMessage = null;
      _error = null;
    });
    try {
      final found = await ref.read(adminAccessControllerProvider).lookup(key);
      if (!mounted) return;
      setState(() {
        _candidate = found;
        if (found == null) {
          _lookupMessage = key.contains('@')
              ? 'No CrickFlow account uses this email yet. Ask the person to '
                    'sign in once (CrickFlow app, website, or this panel\'s login '
                    'page), then search again, or paste their Auth UID.'
              : 'No account found for this UID. Check the UID in Firebase '
                    'Console > Authentication.';
        } else if (found.existing != null) {
          final ex = found.existing!;
          _roleId = ex.roleId;
          _overrides = {...ex.permissionOverrides};
          _name.text = ex.displayName ?? '';
          _lookupMessage =
              'This person already has an admin profile (${ex.status.label}). '
              'Saving will update it.';
        } else {
          _name.text = found.displayName ?? '';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _lookupMessage = 'Lookup failed: $e');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  /// Manual UID entry when the person has no mobile profile document.
  void _useTypedUid() {
    final uid = _lookup.text.trim();
    if (uid.isEmpty || uid.contains('@')) return;
    setState(() {
      _candidate = AdminCandidate(uid: uid, email: '', source: 'uid');
      _lookupMessage = 'Using UID $uid. Add their email below for reference.';
    });
  }

  Future<void> _save(List<RoleDefinition> roles) async {
    final candidate = _candidate;
    if (candidate == null) {
      setState(() => _error = 'Find the person first (email or UID).');
      return;
    }
    RoleDefinition? role;
    for (final r in roles) {
      if (r.id == _roleId) role = r;
    }
    if (role == null) {
      setState(() => _error = 'Choose a role.');
      return;
    }
    final email = candidate.email.isNotEmpty
        ? candidate.email
        : _manualEmail.text.trim();

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminAccessControllerProvider)
          .saveAccess(
            candidate: AdminCandidate(
              uid: candidate.uid,
              email: email,
              displayName: candidate.displayName,
              photoUrl: candidate.photoUrl,
              existing: candidate.existing,
              source: candidate.source,
            ),
            role: role,
            permissionOverrides: Map.of(_overrides),
            displayName: _name.text.trim(),
            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final msg = e is StateError ? e.message : '$e';
      if (mounted) {
        setState(() {
          _busy = false;
          _error = msg.contains('permission-denied')
              ? 'Firestore denied the write. Only an active Super Admin can '
                    'change admin access.'
              : msg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(adminRoleOptionsProvider);
    final colors = context.adminColors;
    final width = MediaQuery.sizeOf(context).width;

    final roles = rolesAsync.asData?.value ?? const <RoleDefinition>[];
    RoleDefinition? role;
    for (final r in roles) {
      if (r.id == _roleId) role = r;
    }

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 600 ? 12 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  Icon(
                    _isEdit
                        ? Icons.manage_accounts_outlined
                        : Icons.person_add_alt_1_outlined,
                    color: colors.info,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit admin access' : 'Add administrator',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isEdit) ..._lookupSection(context),
                    if (_candidate != null) ...[
                      _CandidateCard(candidate: _candidate!),
                      if (_candidate!.email.isEmpty) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _manualEmail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email (for reference)',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _roleField(context, rolesAsync, roles),
                      if (role != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${panelLabel(role)}${role.description == null ? '' : ' · ${role.description}'}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted),
                        ),
                      ],
                      if (role != null) ...[
                        const SizedBox(height: 12),
                        _overridesSection(context, role),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reason,
                        decoration: const InputDecoration(
                          labelText: 'Reason (saved to the audit log)',
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: colors.error)),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  CfButton(
                    label: 'Cancel',
                    variant: CfButtonVariant.ghost,
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                  CfButton(
                    label: _isEdit || _candidate?.existing != null
                        ? 'Save changes'
                        : 'Grant access',
                    icon: Icons.check,
                    isLoading: _busy,
                    onPressed: _busy || _candidate == null
                        ? null
                        : () => _save(roles),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _lookupSection(BuildContext context) {
    final colors = context.adminColors;
    final looksLikeUid =
        _lookup.text.trim().isNotEmpty && !_lookup.text.contains('@');
    return [
      Text(
        'Find the person by the email they use for CrickFlow, or by their '
        'Firebase Auth UID.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _lookup,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email or UID',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _runLookup(),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CfButton(
              label: 'Find',
              variant: CfButtonVariant.secondary,
              isLoading: _lookingUp,
              onPressed: _lookingUp ? null : _runLookup,
            ),
          ),
        ],
      ),
      if (_lookupMessage != null) ...[
        const SizedBox(height: 8),
        Text(
          _lookupMessage!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
      if (_candidate == null && looksLikeUid && _lookupMessage != null) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: CfButton(
            label: 'Use this UID anyway',
            variant: CfButtonVariant.text,
            onPressed: _useTypedUid,
          ),
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget _roleField(
    BuildContext context,
    AsyncValue<List<RoleDefinition>> async,
    List<RoleDefinition> roles,
  ) {
    if (async.isLoading && roles.isEmpty) {
      return const LinearProgressIndicator();
    }
    roles = assignableAdminRoles(
      roles,
      currentRoleId: widget.existing?.roleId ?? _candidate?.existing?.roleId,
    );
    final hasCurrent = roles.any((r) => r.id == _roleId);
    return DropdownButtonFormField<String>(
      key: ValueKey('role-$_roleId-${roles.length}'),
      initialValue: hasCurrent ? _roleId : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Role'),
      items: [
        for (final r in roles)
          DropdownMenuItem(
            value: r.id,
            child: Text(
              '${r.label}  ·  ${panelLabel(r)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _busy ? null : (v) => setState(() => _roleId = v),
    );
  }

  Widget _overridesSection(BuildContext context, RoleDefinition role) {
    final colors = context.adminColors;
    final rolePerms = role.permissionSet;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('Permission overrides'),
        subtitle: Text(
          _overrides.isEmpty
              ? 'Using the role defaults'
              : '${_overrides.length} override(s) on top of ${role.label}',
          style: TextStyle(color: colors.textMuted),
        ),
        children: [
          for (final p in AdminPermission.values)
            _OverrideRow(
              permission: p,
              roleAllows: rolePerms.contains(p),
              value: switch (_overrides[p.name]) {
                true => _Override.allow,
                false => _Override.deny,
                null => _Override.roleDefault,
              },
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      switch (v) {
                        case _Override.roleDefault:
                          _overrides.remove(p.name);
                        case _Override.allow:
                          _overrides[p.name] = true;
                        case _Override.deny:
                          _overrides[p.name] = false;
                      }
                    }),
            ),
        ],
      ),
    );
  }
}

class _OverrideRow extends StatelessWidget {
  const _OverrideRow({
    required this.permission,
    required this.roleAllows,
    required this.value,
    required this.onChanged,
  });

  final AdminPermission permission;
  final bool roleAllows;
  final _Override value;
  final ValueChanged<_Override>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(permission.label),
                Text(
                  'Role default: ${roleAllows ? 'allowed' : 'denied'}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          SegmentedButton<_Override>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(
                value: _Override.roleDefault,
                label: Text('Default'),
              ),
              ButtonSegment(value: _Override.allow, label: Text('Allow')),
              ButtonSegment(value: _Override.deny, label: Text('Deny')),
            ],
            selected: {value},
            onSelectionChanged: onChanged == null
                ? null
                : (s) => onChanged!(s.first),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final AdminCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final name = candidate.displayName?.trim().isNotEmpty == true
        ? candidate.displayName!
        : (candidate.email.isNotEmpty ? candidate.email : candidate.uid);
    final existing = candidate.existing;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.info.withValues(alpha: 0.14),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(color: colors.info, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (candidate.email.isNotEmpty && candidate.email != name)
                  Text(candidate.email, overflow: TextOverflow.ellipsis),
                SelectableText(
                  'UID ${candidate.uid}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (existing != null)
            CfStatusBadge(
              label: existing.status.label,
              compact: true,
              tone: switch (existing.status) {
                AdminAccessStatus.active => CfBadgeTone.success,
                AdminAccessStatus.suspended => CfBadgeTone.warning,
                AdminAccessStatus.revoked => CfBadgeTone.danger,
              },
            ),
        ],
      ),
    );
  }
}
