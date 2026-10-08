import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../models/admin_role.dart';
import '../../../models/role_definition.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_card.dart';
import '../../../shared/widgets/cf_dialog.dart';
import '../../../shared/widgets/cf_empty_state.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../../shared/widgets/cf_page.dart';
import '../../../shared/widgets/cf_search_bar.dart';
import '../../../shared/widgets/cf_snackbar.dart';
import '../../../shared/widgets/cf_stat_tile.dart';
import '../../../shared/widgets/cf_status_badge.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/admin_account.dart';
import '../providers/admin_accounts_providers.dart';
import 'widgets/admin_access_dialog.dart';

/// Super Admin: list administrators and control their access.
class AdminsScreen extends ConsumerStatefulWidget {
  const AdminsScreen({super.key});

  @override
  ConsumerState<AdminsScreen> createState() => _AdminsScreenState();
}

enum _StatusFilter { all, active, suspended, revoked }

class _AdminsScreenState extends ConsumerState<AdminsScreen> {
  final _search = TextEditingController();
  _StatusFilter _filter = _StatusFilter.all;
  String _roleFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(breadcrumbProvider.notifier).state = [
        'Management',
        'Admins & Access',
      ];
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AdminAccount> _apply(List<AdminAccount> all) {
    final q = _search.text.trim().toLowerCase();
    return all
        .where((a) {
          final statusOk = switch (_filter) {
            _StatusFilter.all => true,
            _StatusFilter.active => a.status == AdminAccessStatus.active,
            _StatusFilter.suspended => a.status == AdminAccessStatus.suspended,
            _StatusFilter.revoked => a.status == AdminAccessStatus.revoked,
          };
          if (!statusOk) return false;
          if (_roleFilter.isNotEmpty && a.roleId != _roleFilter) return false;
          if (q.isEmpty) return true;
          return a.effectiveName.toLowerCase().contains(q) ||
              a.email.toLowerCase().contains(q) ||
              a.uid.toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  Future<void> _add() async {
    final ok = await showAdminAccessDialog(context);
    if (ok == true && mounted) CfSnack.success(context, 'Admin access saved');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(adminSessionProvider);
    final isSuper = session.adminUser?.isSuperAdmin == true;
    return PermissionGate(
      permission: AdminPermission.canManageSecurity,
      child: !isSuper
          ? const CfEmptyState(
              icon: Icons.lock_outline,
              title: 'Super Admin only',
              message: 'Only Super Admins can manage administrator access.',
            )
          : _body(context, session.adminUser!.uid),
    );
  }

  Widget _body(BuildContext context, String myUid) {
    final async = ref.watch(adminAccountsProvider);
    final rolesAsync = ref.watch(adminRoleOptionsProvider);
    final roleLabels = <String, String>{
      for (final r in rolesAsync.asData?.value ?? const <RoleDefinition>[])
        r.id: r.label,
    };
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 600 ? 12.0 : 20.0;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminAccountsProvider),
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 32),
        children: [
          CfPageHeader(
            title: 'Admins & Access',
            subtitle:
                'Grant, change, suspend, or revoke access to this panel '
                'for CrickFlow platform staff.',
            actions: [
              CfButton(
                label: 'Refresh',
                icon: Icons.refresh,
                variant: CfButtonVariant.ghost,
                onPressed: () => ref.invalidate(adminAccountsProvider),
              ),
              CfButton(
                label: 'Add admin',
                icon: Icons.person_add_alt_1_outlined,
                onPressed: _add,
              ),
            ],
          ),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 48),
              child: CfLoadingState(message: 'Loading administrators…'),
            ),
            error: (e, _) => CfErrorState(
              title: 'Could not load administrators',
              message: '$e',
              onRetry: () => ref.invalidate(adminAccountsProvider),
            ),
            data: (all) {
              final visible = _apply(all);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Summary(all: all),
                  const SizedBox(height: 16),
                  _toolbar(context, all, roleLabels),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: CfEmptyState(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'No administrators match',
                        message: 'Change the filters, or add an admin.',
                      ),
                    )
                  else
                    for (final a in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AdminRow(
                          account: a,
                          isMe: a.uid == myUid,
                          roleLabel:
                              roleLabels[a.roleId] ??
                              a.knownRole?.label ??
                              a.roleId,
                        ),
                      ),
                  const SizedBox(height: 12),
                  const _HowItWorks(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _toolbar(
    BuildContext context,
    List<AdminAccount> all,
    Map<String, String> roleLabels,
  ) {
    final roleIds = {for (final a in all) a.roleId}.toList()..sort();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: CfSearchBar(
            controller: _search,
            hintText: 'Search name, email, or UID…',
            onChanged: (_) => setState(() {}),
            onClear: () => setState(_search.clear),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in _StatusFilter.values)
              ChoiceChip(
                label: Text(switch (f) {
                  _StatusFilter.all => 'All',
                  _StatusFilter.active => 'Active',
                  _StatusFilter.suspended => 'Suspended',
                  _StatusFilter.revoked => 'Revoked',
                }),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
          ],
        ),
        if (roleIds.length > 1)
          DropdownButton<String>(
            value: _roleFilter,
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem(value: '', child: Text('All roles')),
              for (final id in roleIds)
                DropdownMenuItem(
                  value: id,
                  child: Text(
                    roleLabels[id] ?? AdminRole.tryParse(id)?.label ?? id,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _roleFilter = v ?? ''),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.all});

  final List<AdminAccount> all;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final active = all.where((a) => a.isActive).toList();
    final tiles = [
      CfStatTile(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Administrators',
        value: '${all.length}',
        compact: true,
      ),
      CfStatTile(
        icon: Icons.verified_user_outlined,
        title: 'Active',
        value: '${active.length}',
        accentColor: colors.success,
        compact: true,
      ),
      CfStatTile(
        icon: Icons.workspace_premium_outlined,
        title: 'Super Admins',
        value: '${active.where((a) => a.isSuperAdmin).length}',
        accentColor: AdminColors.gold,
        compact: true,
      ),
      CfStatTile(
        icon: Icons.support_agent_outlined,
        title: 'Platform staff',
        value: '${active.where((a) => !a.isSuperAdmin).length}',
        accentColor: colors.info,
        compact: true,
      ),
      CfStatTile(
        icon: Icons.block_outlined,
        title: 'Suspended / revoked',
        value: '${all.length - active.length}',
        accentColor: colors.warning,
        compact: true,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100
            ? 5
            : c.maxWidth >= 760
            ? 3
            : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

enum _RowAction { edit, suspend, reactivate, revoke, copyUid }

class _AdminRow extends ConsumerWidget {
  const _AdminRow({
    required this.account,
    required this.isMe,
    required this.roleLabel,
  });

  final AdminAccount account;
  final bool isMe;
  final String roleLabel;

  CfBadgeTone get _statusTone => switch (account.status) {
    AdminAccessStatus.active => CfBadgeTone.success,
    AdminAccessStatus.suspended => CfBadgeTone.warning,
    AdminAccessStatus.revoked => CfBadgeTone.danger,
  };

  Future<String?> _askReason(
    BuildContext context, {
    required String title,
    required String message,
    required String confirm,
    required bool danger,
  }) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reason (saved to the audit log)',
              ),
            ),
          ],
        ),
        actions: [
          CfButton(
            label: 'Cancel',
            variant: CfButtonVariant.ghost,
            onPressed: () => Navigator.pop(context, false),
          ),
          CfButton(
            label: confirm,
            variant: danger ? CfButtonVariant.danger : CfButtonVariant.primary,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    return ok == true ? text : null;
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _RowAction action,
  ) async {
    final controller = ref.read(adminAccessControllerProvider);
    try {
      switch (action) {
        case _RowAction.edit:
          final ok = await showAdminAccessDialog(context, existing: account);
          if (ok == true && context.mounted) {
            CfSnack.success(context, 'Access updated for ${account.email}');
          }
        case _RowAction.copyUid:
          await Clipboard.setData(ClipboardData(text: account.uid));
          if (context.mounted) CfSnack.info(context, 'UID copied');
        case _RowAction.suspend:
          final reason = await _askReason(
            context,
            title: 'Suspend ${account.effectiveName}?',
            message:
                'They are signed out of the admin panels right away and '
                'cannot sign back in until reactivated.',
            confirm: 'Suspend',
            danger: true,
          );
          if (reason == null) return;
          await controller.setStatus(
            account,
            AdminAccessStatus.suspended,
            reason: reason,
          );
          if (context.mounted) CfSnack.warning(context, 'Admin suspended');
        case _RowAction.revoke:
          final reason = await _askReason(
            context,
            title: 'Revoke access for ${account.effectiveName}?',
            message:
                'Removes all admin panel access. The profile is kept for '
                'the audit trail and can be restored later.',
            confirm: 'Revoke access',
            danger: true,
          );
          if (reason == null) return;
          await controller.setStatus(
            account,
            AdminAccessStatus.revoked,
            reason: reason,
          );
          if (context.mounted) CfSnack.warning(context, 'Access revoked');
        case _RowAction.reactivate:
          final ok = await showCfConfirmDialog(
            context: context,
            title: 'Restore access?',
            message: '${account.effectiveName} will regain $roleLabel access.',
            confirmLabel: 'Restore',
            kind: CfDialogKind.restore,
          );
          if (ok != true) return;
          await controller.setStatus(account, AdminAccessStatus.active);
          if (context.mounted) CfSnack.success(context, 'Access restored');
      }
    } catch (e) {
      if (!context.mounted) return;
      final msg = e is StateError ? e.message : '$e';
      CfSnack.error(
        context,
        msg.contains('permission-denied')
            ? 'Firestore denied the change. Only an active Super Admin can do '
                  'this.'
            : msg,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.adminColors;
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final updated = account.updatedAt == null
        ? null
        : DateFormat('MMM d, y').format(account.updatedAt!);

    final identity = Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor:
              (account.isSuperAdmin ? AdminColors.gold : colors.info)
                  .withValues(alpha: 0.16),
          child: Text(
            account.initials,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: account.isSuperAdmin ? AdminColors.goldDark : colors.info,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    account.effectiveName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (isMe)
                    const CfStatusBadge(
                      label: 'You',
                      compact: true,
                      tone: CfBadgeTone.primary,
                    ),
                ],
              ),
              if (account.email.isNotEmpty)
                Text(
                  account.email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );

    final meta = Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CfStatusBadge(
          label: roleLabel,
          compact: true,
          icon: account.isSuperAdmin
              ? Icons.workspace_premium_outlined
              : Icons.badge_outlined,
          tone: account.isSuperAdmin ? CfBadgeTone.primary : CfBadgeTone.info,
        ),
        if (account.permissionOverrides.isNotEmpty)
          CfStatusBadge(
            label: '${account.permissionOverrides.length} override(s)',
            compact: true,
            icon: Icons.tune,
          ),
        CfStatusBadge(
          label: account.status.label,
          compact: true,
          tone: _statusTone,
        ),
      ],
    );

    final menu = PopupMenuButton<_RowAction>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert),
      onSelected: (a) => _onAction(context, ref, a),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _RowAction.edit,
          child: const ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit role, scope & permissions'),
          ),
        ),
        if (!isMe && account.status == AdminAccessStatus.active) ...[
          const PopupMenuItem(
            value: _RowAction.suspend,
            child: ListTile(
              leading: Icon(Icons.pause_circle_outline),
              title: Text('Suspend'),
            ),
          ),
          const PopupMenuItem(
            value: _RowAction.revoke,
            child: ListTile(
              leading: Icon(Icons.person_remove_outlined),
              title: Text('Revoke access'),
            ),
          ),
        ],
        if (!isMe && account.status != AdminAccessStatus.active) ...[
          const PopupMenuItem(
            value: _RowAction.reactivate,
            child: ListTile(
              leading: Icon(Icons.play_circle_outline),
              title: Text('Restore access'),
            ),
          ),
          if (account.status == AdminAccessStatus.suspended)
            const PopupMenuItem(
              value: _RowAction.revoke,
              child: ListTile(
                leading: Icon(Icons.person_remove_outlined),
                title: Text('Revoke access'),
              ),
            ),
        ],
        const PopupMenuItem(
          value: _RowAction.copyUid,
          child: ListTile(
            leading: Icon(Icons.copy_outlined),
            title: Text('Copy UID'),
          ),
        ),
      ],
    );

    final footer = Text(
      [
        'UID ${account.uid}',
        if (updated != null) 'Updated $updated',
        if (!account.isActive && (account.statusReason?.isNotEmpty ?? false))
          'Reason: ${account.statusReason}',
      ].join('  ·  '),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: colors.textMuted),
    );

    return CfCard(
      variant: CfCardVariant.list,
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    menu,
                  ],
                ),
                const SizedBox(height: 8),
                meta,
                const SizedBox(height: 6),
                footer,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(flex: 5, child: identity),
                    const SizedBox(width: 12),
                    Expanded(flex: 6, child: meta),
                    menu,
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: footer,
                ),
              ],
            ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.textSecondary, height: 1.5);
    return CfCard(
      variant: CfCardVariant.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: colors.info, size: 20),
              const SizedBox(width: 8),
              Text(
                'How admin access works',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• This panel is for CrickFlow platform staff only. Organization, '
            'club and series admins are managed inside the CrickFlow mobile '
            'app, not here.\n'
            '• Super Admin: full platform access in this panel.\n'
            '• Staff roles (Moderator, Tournament Admin, Support, Viewer) sign '
            'in here too. Their role permissions (plus any per-person '
            'overrides) decide which sections they see and what they can '
            'change; Firestore rules enforce the same permissions.\n'
            '• To add someone, they need a CrickFlow sign-in first (mobile app, '
            'website, or Google / email on the admin login page). Then search '
            'their email here.\n'
            '• Suspend or revoke takes effect immediately; their open session '
            'is sent to the Access denied page.\n'
            '• You cannot change your own role or status, and the last active '
            'Super Admin cannot be removed.',
            style: style,
          ),
        ],
      ),
    );
  }
}
