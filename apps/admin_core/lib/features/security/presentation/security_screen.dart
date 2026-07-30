import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../models/admin_permission.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shell/providers/shell_providers.dart';
import '../models/managed_security.dart';
import '../models/security_enums.dart';
import '../providers/security_providers.dart';
import 'widgets/security_chrome.dart';
import 'widgets/security_section_panels.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  SecurityPolicies? _draftPolicies;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(breadcrumbProvider.notifier).state = [
        'System',
        'Security Center',
      ];
      ref.read(securityHubControllerProvider.notifier).ensureBootstrapped();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(securityHubControllerProvider);
    final controller = ref.read(securityHubControllerProvider.notifier);
    final isSuperAdmin =
        ref.watch(adminAppTypeProvider) == AdminAppType.superAdmin;
    final policies = _draftPolicies ?? state.policies;

    return PermissionGate(
      permission: AdminPermission.canManageSecurity,
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              'Security Operations Center',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              isSuperAdmin
                  ? 'Platform security, access control, and recovery architecture'
                  : 'Organization-scoped security monitoring — no secrets exposed',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SocSectionChips(
              section: state.section,
              onChanged: (s) async {
                _draftPolicies = null;
                await controller.setSection(s);
                ref.read(breadcrumbProvider.notifier).state = [
                  'System',
                  'Security Center',
                  s.label,
                ];
              },
            ),
            const SizedBox(height: 12),
            SocToolbar(
              searchController: _search,
              onQueryChanged: (q) {
                controller.setQuery(q);
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  controller.refresh();
                });
              },
              filterActive: state.filters.hasActiveFilters,
              refreshing: state.isLoading,
              onFilter: () async {
                final next = await showSocFilterDrawer(
                  context: context,
                  initial: state.filters,
                  isSuperAdmin: isSuperAdmin,
                );
                if (next != null) await controller.applyFilters(next);
              },
              onRefresh: () => controller.refresh(force: true),
            ),
            const SizedBox(height: 16),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: Text(state.error!)),
                        CfButton(
                          label: 'Retry',
                          onPressed: () => controller.refresh(force: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (state.isLoading && state.section == SocHubSection.dashboard)
              const SizedBox(
                height: 280,
                child: CfLoadingState(message: 'Loading Security Center…'),
              )
            else ...[
              if (state.section == SocHubSection.dashboard) ...[
                SocSummaryCards(summary: state.summary),
                const SizedBox(height: 16),
              ],
              _sectionBody(
                state: state,
                controller: controller,
                isSuperAdmin: isSuperAdmin,
                policies: policies,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionBody({
    required SecurityHubState state,
    required SecurityHubController controller,
    required bool isSuperAdmin,
    required SecurityPolicies policies,
  }) {
    switch (state.section) {
      case SocHubSection.dashboard:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent alerts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            SocAlertsPanel(
              alerts: state.alerts.take(8).toList(),
              onResolve: (a) =>
                  controller.updateAlert(a, SocAlertStatus.resolved),
              onDismiss: (a) =>
                  controller.updateAlert(a, SocAlertStatus.dismissed),
            ),
          ],
        );
      case SocHubSection.roleManagement:
        return SocRolesPanel(
          roles: state.roles,
          canManage: isSuperAdmin,
          selectedId: state.selectedRoleId,
          onSelect: controller.selectRole,
          onCreate: () => _createRole(controller),
          onDuplicate: (r) => _duplicateRole(controller, r),
          onRename: (r) => _renameRole(controller, r),
          onArchive: controller.archiveRole,
          onDelete: controller.deleteRole,
        );
      case SocHubSection.permissionManagement:
        final role = state.selectedRole ??
            (state.roles.isEmpty ? null : state.roles.first);
        if (role == null) {
          return const Text('Select a role in Role Management first');
        }
        return Column(
          children: [
            if (state.roles.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final r in state.roles)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(r.label),
                          selected: state.selectedRoleId == r.id ||
                              (state.selectedRoleId == null &&
                                  r.id == role.id),
                          onSelected: (_) => controller.selectRole(r.id),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SocPermissionMatrix(
              role: state.selectedRole ?? role,
              canEdit: isSuperAdmin,
              onSave: (perms) => controller.updatePermissions(
                state.selectedRole ?? role,
                perms,
              ),
            ),
          ],
        );
      case SocHubSection.accessControl:
        return SocAccessPanel(
          grants: state.accessGrants,
          onAdd: () => _addAccess(controller),
        );
      case SocHubSection.loginSessions:
        return SocSessionsPanel(
          sessions: state.sessions,
          onTerminate: controller.terminateSession,
          onTerminateAll: controller.terminateAllFor,
        );
      case SocHubSection.activeDevices:
        return SocDevicesPanel(devices: state.devices);
      case SocHubSection.securityAlerts:
        return SocAlertsPanel(
          alerts: state.alerts,
          onResolve: (a) =>
              controller.updateAlert(a, SocAlertStatus.resolved),
          onDismiss: (a) =>
              controller.updateAlert(a, SocAlertStatus.dismissed),
        );
      case SocHubSection.threatDetection:
        return SocThreatsPanel(threats: state.threats);
      case SocHubSection.blockLists:
        return SocBlocksPanel(
          blocks: state.blocks,
          onAdd: () => _addBlock(controller),
          onUnblock: controller.unblock,
        );
      case SocHubSection.ipManagement:
        return SocIpPanel(
          rules: state.ipRules,
          canManage: isSuperAdmin,
          onAdd: () => _addIp(controller),
        );
      case SocHubSection.apiSecurity:
        return SocApiPanel(api: state.api);
      case SocHubSection.backupCenter:
        return SocBackupPanel(
          backups: state.backups,
          canManage: isSuperAdmin,
          onSchedule: controller.scheduleBackup,
        );
      case SocHubSection.restoreCenter:
        return SocRestorePanel(points: state.restorePoints);
      case SocHubSection.disasterRecovery:
        return SocDrPanel(plan: state.dr);
      case SocHubSection.securityPolicies:
        return SocPoliciesPanel(
          policies: policies,
          canEdit: isSuperAdmin,
          onChanged: (p) => setState(() => _draftPolicies = p),
          onSave: () async {
            await controller.savePolicies(policies);
            setState(() => _draftPolicies = null);
          },
        );
      case SocHubSection.compliance:
        return SocCompliancePanel(compliance: state.compliance);
    }
  }

  Future<void> _createRole(SecurityHubController controller) async {
    final id = TextEditingController();
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: id,
              decoration: const InputDecoration(
                labelText: 'Role ID (wire value)',
              ),
            ),
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok == true && id.text.trim().isNotEmpty) {
      await controller.createRole(
        id: id.text.trim(),
        label: label.text.trim().isEmpty ? id.text.trim() : label.text.trim(),
      );
    }
    id.dispose();
    label.dispose();
  }

  Future<void> _duplicateRole(
    SecurityHubController controller,
    SocRoleView role,
  ) async {
    final id = TextEditingController(text: '${role.id}_copy');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate role'),
        content: TextField(
          controller: id,
          decoration: const InputDecoration(labelText: 'New role ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
    if (ok == true && id.text.trim().isNotEmpty) {
      await controller.duplicateRole(role, id.text.trim());
    }
    id.dispose();
  }

  Future<void> _renameRole(
    SecurityHubController controller,
    SocRoleView role,
  ) async {
    final label = TextEditingController(text: role.label);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename role'),
        content: TextField(
          controller: label,
          decoration: const InputDecoration(labelText: 'Label'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && label.text.trim().isNotEmpty) {
      await controller.renameRole(role.id, label.text.trim());
    }
    label.dispose();
  }

  Future<void> _addBlock(SecurityHubController controller) async {
    final value = TextEditingController();
    final reason = TextEditingController();
    var kind = SocBlockKind.email;
    var duration = SocBlockDuration.permanent;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Block entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<SocBlockKind>(
                // ignore: deprecated_member_use
                value: kind,
                items: [
                  for (final k in SocBlockKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (v) => setLocal(() => kind = v ?? kind),
              ),
              TextField(
                controller: value,
                decoration: const InputDecoration(labelText: 'Value'),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              DropdownButtonFormField<SocBlockDuration>(
                // ignore: deprecated_member_use
                value: duration,
                items: [
                  for (final d in SocBlockDuration.values)
                    DropdownMenuItem(value: d, child: Text(d.label)),
                ],
                onChanged: (v) => setLocal(() => duration = v ?? duration),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && value.text.trim().isNotEmpty) {
      await controller.addBlock(
        ManagedBlockEntry(
          id: '',
          kind: kind,
          value: value.text.trim(),
          reason: reason.text.trim(),
          duration: duration,
          expiresAt: duration == SocBlockDuration.temporary
              ? DateTime.now().add(const Duration(days: 7))
              : null,
        ),
      );
    }
    value.dispose();
    reason.dispose();
  }

  Future<void> _addIp(SecurityHubController controller) async {
    final value = TextEditingController();
    final note = TextEditingController();
    var type = SocIpListType.blacklist;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('IP / country rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<SocIpListType>(
                // ignore: deprecated_member_use
                value: type,
                items: [
                  for (final t in SocIpListType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setLocal(() => type = v ?? type),
              ),
              TextField(
                controller: value,
                decoration: const InputDecoration(labelText: 'Value'),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && value.text.trim().isNotEmpty) {
      await controller.addIpRule(
        ManagedIpRule(
          id: '',
          listType: type,
          value: value.text.trim(),
          note: note.text.trim(),
        ),
      );
    }
    value.dispose();
    note.dispose();
  }

  Future<void> _addAccess(SecurityHubController controller) async {
    final email = TextEditingController();
    final module = TextEditingController();
    final note = TextEditingController();
    var kind = SocAccessKind.temporary;
    DateTime? expires = DateTime.now().add(const Duration(days: 7));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Grant access'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<SocAccessKind>(
                // ignore: deprecated_member_use
                value: kind,
                items: [
                  for (final k in SocAccessKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: (v) => setLocal(() => kind = v ?? kind),
              ),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Subject email'),
              ),
              TextField(
                controller: module,
                decoration: const InputDecoration(labelText: 'Module'),
              ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: expires ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setLocal(() => expires = d);
                },
                child: Text(
                  expires == null
                      ? 'Expiry'
                      : 'Expires ${expires!.toIso8601String().substring(0, 10)}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Grant'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && email.text.trim().isNotEmpty) {
      await controller.saveAccessGrant(
        ManagedAccessGrant(
          id: '',
          kind: kind,
          subjectEmail: email.text.trim(),
          module: module.text.trim(),
          note: note.text.trim(),
          expiresAt: expires,
        ),
      );
    }
    email.dispose();
    module.dispose();
    note.dispose();
  }
}
