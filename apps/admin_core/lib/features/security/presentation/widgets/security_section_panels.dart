import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../models/admin_permission.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_empty_state.dart';
import '../../models/managed_security.dart';
import '../../models/security_enums.dart';
import 'security_chrome.dart';

class SocRolesPanel extends StatelessWidget {
  const SocRolesPanel({
    super.key,
    required this.roles,
    required this.canManage,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    required this.onDuplicate,
    required this.onRename,
    required this.onArchive,
    required this.onDelete,
  });

  final List<SocRoleView> roles;
  final bool canManage;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<SocRoleView> onDuplicate;
  final ValueChanged<SocRoleView> onRename;
  final ValueChanged<SocRoleView> onArchive;
  final ValueChanged<SocRoleView> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: CfButton(
              label: 'Create Role',
              icon: Icons.add,
              onPressed: onCreate,
            ),
          ),
        const SizedBox(height: 12),
        CfCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final r in roles)
                Material(
                  color: selectedId == r.id
                      ? context.adminColors.info.withValues(alpha: 0.08)
                      : null,
                  child: ListTile(
                    onTap: () => onSelect(r.id),
                    title: Text(r.label),
                    subtitle: Text(
                      '${r.id} · ${r.isSystem ? 'System' : 'Custom'} · '
                      '${r.recordStatus.wireValue} · ${r.usageCount} users',
                    ),
                    trailing: canManage
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
                                case 'dup':
                                  onDuplicate(r);
                                case 'rename':
                                  onRename(r);
                                case 'archive':
                                  onArchive(r);
                                case 'del':
                                  onDelete(r);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'dup',
                                child: Text('Duplicate'),
                              ),
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text('Archive'),
                              ),
                              const PopupMenuItem(
                                value: 'del',
                                child: Text('Delete'),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class SocPermissionMatrix extends StatelessWidget {
  const SocPermissionMatrix({
    super.key,
    required this.role,
    required this.canEdit,
    required this.onSave,
  });

  final SocRoleView role;
  final bool canEdit;
  final ValueChanged<Map<String, bool>> onSave;

  @override
  Widget build(BuildContext context) {
    final perms = Map<String, bool>.from(role.permissions);
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Permission matrix — ${role.label}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Current flags use AdminPermission. Future granular View/Create/Edit… '
            'actions map onto these modules.',
            style: TextStyle(fontSize: 12, color: context.adminColors.textMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in SocPermissionModule.values)
                Chip(label: Text(m.label)),
            ],
          ),
          const Divider(height: 24),
          ...AdminPermission.values.map((p) {
            return SwitchListTile(
              title: Text(p.label),
              subtitle: Text(p.name, style: const TextStyle(fontSize: 11)),
              value: perms[p.name] ?? false,
              onChanged: canEdit
                  ? (v) {
                      perms[p.name] = v;
                      onSave(Map<String, bool>.from(perms));
                    }
                  : null,
            );
          }),
          const SizedBox(height: 8),
          Text(
            'Future action types: ${SocPermissionAction.values.map((a) => a.label).join(', ')}',
            style: TextStyle(fontSize: 11, color: context.adminColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class SocSessionsPanel extends StatelessWidget {
  const SocSessionsPanel({
    super.key,
    required this.sessions,
    required this.onTerminate,
    required this.onTerminateAll,
  });

  final List<ManagedSecuritySession> sessions;
  final ValueChanged<ManagedSecuritySession> onTerminate;
  final ValueChanged<ManagedSecuritySession> onTerminateAll;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 200,
          child: CfEmptyState(
            icon: Icons.login,
            title: 'No session events',
            message: 'Derived from admin auth audit logs (IPs masked).',
          ),
        ),
      );
    }
    final fmt = DateFormat.yMMMd().add_jm();
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final s in sessions)
            Material(
              child: ListTile(
                title: Text(s.email.isEmpty ? s.uid : s.email),
                subtitle: Text(
                  '${s.active ? 'Active/login' : 'Event'} · IP ${s.ipMasked}\n'
                  '${s.browser.isEmpty ? '—' : s.browser} · '
                  '${s.country.isEmpty ? '—' : s.country}'
                  '${s.lastLogin == null ? '' : ' · ${fmt.format(s.lastLogin!)}'}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'one') onTerminate(s);
                    if (v == 'all') onTerminateAll(s);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'one',
                      child: Text('Terminate session'),
                    ),
                    PopupMenuItem(
                      value: 'all',
                      child: Text('Terminate all sessions'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SocDevicesPanel extends StatelessWidget {
  const SocDevicesPanel({super.key, required this.devices});
  final List<ManagedSecurityDevice> devices;

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 200,
          child: CfEmptyState(
            icon: Icons.devices,
            title: 'No registered devices',
            message:
                'Device registry ready. Future: trusted device + re-verification.',
          ),
        ),
      );
    }
    final fmt = DateFormat.yMMMd().add_jm();
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final d in devices)
            Material(
              child: ListTile(
                title: Text('${d.deviceClass} · ${d.browser}'),
                subtitle: Text(
                  '${d.os} ${d.browserVersion}\n'
                  '${d.email}'
                  '${d.lastActive == null ? '' : ' · ${fmt.format(d.lastActive!)}'}'
                  '${d.trusted ? ' · Trusted' : ''}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}

class SocAlertsPanel extends StatelessWidget {
  const SocAlertsPanel({
    super.key,
    required this.alerts,
    required this.onResolve,
    required this.onDismiss,
  });

  final List<ManagedSecurityAlert> alerts;
  final ValueChanged<ManagedSecurityAlert> onResolve;
  final ValueChanged<ManagedSecurityAlert> onDismiss;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const CfCard(
        child: SizedBox(
          height: 200,
          child: CfEmptyState(
            icon: Icons.notifications_active_outlined,
            title: 'No security alerts',
            message: 'Failed logins and security.* audit events appear here.',
          ),
        ),
      );
    }
    final fmt = DateFormat.yMMMd().add_jm();
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final a in alerts)
            Material(
              child: ListTile(
                leading: SocSeverityBadge(severity: a.severity),
                title: Text(a.title),
                subtitle: Text(
                  '${a.status.label} · ${a.affectedEmail.isEmpty ? '—' : a.affectedEmail}\n'
                  '${a.detail}'
                  '${a.createdAt == null ? '' : '\n${fmt.format(a.createdAt!)}'}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'resolve') onResolve(a);
                    if (v == 'dismiss') onDismiss(a);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'resolve', child: Text('Resolve')),
                    PopupMenuItem(value: 'dismiss', child: Text('Dismiss')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SocThreatsPanel extends StatelessWidget {
  const SocThreatsPanel({super.key, required this.threats});
  final List<ManagedThreatRecommendation> threats;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Recommendations only — admins decide. Future AI / App Check / reCAPTCHA.',
              style: TextStyle(
                fontSize: 12,
                color: context.adminColors.textMuted,
              ),
            ),
          ),
          for (final t in threats)
            Material(
              child: ListTile(
                leading: SocSeverityBadge(severity: t.severity),
                title: Text(t.title),
                subtitle: Text(
                  '${t.kind.label} · ${(t.confidence * 100).toStringAsFixed(0)}%\n'
                  '${t.recommendation}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}

class SocBlocksPanel extends StatelessWidget {
  const SocBlocksPanel({
    super.key,
    required this.blocks,
    required this.onAdd,
    required this.onUnblock,
  });

  final List<ManagedBlockEntry> blocks;
  final VoidCallback onAdd;
  final ValueChanged<ManagedBlockEntry> onUnblock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CfButton(label: 'Block entry', icon: Icons.block, onPressed: onAdd),
        ),
        const SizedBox(height: 12),
        if (blocks.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 180,
              child: CfEmptyState(
                icon: Icons.playlist_remove,
                title: 'Block list empty',
                message: 'Users, devices, emails, IPs, domains.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final b in blocks)
                  Material(
                    child: ListTile(
                      title: Text('${b.kind.label}: ${b.displayValue}'),
                      subtitle: Text(
                        '${b.duration.label} · ${b.active ? 'Active' : 'Inactive'}\n'
                        '${b.reason}',
                      ),
                      isThreeLine: true,
                      trailing: b.active
                          ? TextButton(
                              onPressed: () => onUnblock(b),
                              child: const Text('Unblock'),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class SocIpPanel extends StatelessWidget {
  const SocIpPanel({
    super.key,
    required this.rules,
    required this.canManage,
    required this.onAdd,
  });

  final List<ManagedIpRule> rules;
  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canManage)
          Align(
            alignment: Alignment.centerLeft,
            child: CfButton(
              label: 'Add IP / country rule',
              icon: Icons.add,
              onPressed: onAdd,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Geo restrictions & Cloud Armor integrations are future-ready.',
          style: TextStyle(fontSize: 12, color: context.adminColors.textMuted),
        ),
        const SizedBox(height: 12),
        if (rules.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 160,
              child: CfEmptyState(
                icon: Icons.public,
                title: 'No IP rules',
                message: 'Whitelist, blacklist, allowed / restricted countries.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final r in rules)
                  Material(
                    child: ListTile(
                      title: Text('${r.listType.label}: ${r.displayValue}'),
                      subtitle: Text(r.note),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class SocAccessPanel extends StatelessWidget {
  const SocAccessPanel({
    super.key,
    required this.grants,
    required this.onAdd,
  });

  final List<ManagedAccessGrant> grants;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: CfButton(
            label: 'Grant access',
            icon: Icons.vpn_key_outlined,
            onPressed: onAdd,
          ),
        ),
        const SizedBox(height: 12),
        if (grants.isEmpty)
          const CfCard(
            child: SizedBox(
              height: 160,
              child: CfEmptyState(
                icon: Icons.lock_clock,
                title: 'No access grants',
                message: 'Temporary / read-only / emergency access with expiry.',
              ),
            ),
          )
        else
          CfCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final g in grants)
                  Material(
                    child: ListTile(
                      title: Text('${g.kind.label} · ${g.subjectEmail}'),
                      subtitle: Text(
                        '${g.module.isEmpty ? '—' : g.module}'
                        '${g.expiresAt == null ? '' : ' · expires ${fmt.format(g.expiresAt!)}'}'
                        '${g.isExpired ? ' · EXPIRED' : ''}\n${g.note}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class SocBackupPanel extends StatelessWidget {
  const SocBackupPanel({
    super.key,
    required this.backups,
    required this.canManage,
    required this.onSchedule,
  });

  final List<ManagedBackupRecord> backups;
  final bool canManage;
  final ValueChanged<SocBackupKind> onSchedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (canManage)
          Wrap(
            spacing: 8,
            children: [
              for (final k in SocBackupKind.values)
                OutlinedButton(
                  onPressed: () => onSchedule(k),
                  child: Text('Schedule ${k.label}'),
                ),
            ],
          ),
        const SizedBox(height: 12),
        CfCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final b in backups)
                Material(
                  child: ListTile(
                    title: Text(b.kind.label),
                    subtitle: Text('${b.status.label}\n${b.note}'),
                    isThreeLine: true,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class SocRestorePanel extends StatelessWidget {
  const SocRestorePanel({super.key, required this.points});
  final List<ManagedRestorePoint> points;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No destructive restore actions from this UI.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.adminColors.warning,
              ),
            ),
          ),
          for (final p in points)
            Material(
              child: ListTile(
                title: Text(p.label),
                subtitle: Text(
                  '${p.validated ? 'Validated' : 'Unvalidated'}\n${p.previewNote}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}

class SocDrPanel extends StatelessWidget {
  const SocDrPanel({super.key, required this.plan});
  final DisasterRecoveryPlan plan;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disaster recovery',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(plan.summary),
          const SizedBox(height: 12),
          Text('Status: ${plan.recoveryStatus}'),
          Text('Last backup: ${plan.lastBackupLabel}'),
          Text('Est. recovery time: ${plan.estimatedRecoveryTime}'),
          const SizedBox(height: 12),
          Text('Critical systems',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final s in plan.criticalSystems) Text('• $s'),
        ],
      ),
    );
  }
}

class SocPoliciesPanel extends StatelessWidget {
  const SocPoliciesPanel({
    super.key,
    required this.policies,
    required this.canEdit,
    required this.onChanged,
    required this.onSave,
  });

  final SecurityPolicies policies;
  final bool canEdit;
  final ValueChanged<SecurityPolicies> onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Security policies',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Text('Min password length: ${policies.minPasswordLength}'),
          Slider(
            value: policies.minPasswordLength.toDouble(),
            min: 6,
            max: 24,
            divisions: 18,
            label: '${policies.minPasswordLength}',
            onChanged: canEdit
                ? (v) => onChanged(
                      policies.copyWith(minPasswordLength: v.round()),
                    )
                : null,
          ),
          Text('Session timeout: ${policies.sessionTimeoutMinutes} min'),
          Slider(
            value: policies.sessionTimeoutMinutes.toDouble().clamp(30, 2880),
            min: 30,
            max: 2880,
            divisions: 95,
            label: '${policies.sessionTimeoutMinutes}',
            onChanged: canEdit
                ? (v) => onChanged(
                      policies.copyWith(sessionTimeoutMinutes: v.round()),
                    )
                : null,
          ),
          SwitchListTile(
            title: const Text('Two-factor authentication (future)'),
            value: policies.require2fa,
            onChanged: canEdit
                ? (v) => onChanged(policies.copyWith(require2fa: v))
                : null,
          ),
          SwitchListTile(
            title: const Text('Login restrictions'),
            value: policies.loginRestrictionsEnabled,
            onChanged: canEdit
                ? (v) =>
                    onChanged(policies.copyWith(loginRestrictionsEnabled: v))
                : null,
          ),
          Text('Account lockout threshold: ${policies.accountLockoutThreshold}'),
          Slider(
            value: policies.accountLockoutThreshold.toDouble(),
            min: 3,
            max: 20,
            divisions: 17,
            onChanged: canEdit
                ? (v) => onChanged(
                      policies.copyWith(accountLockoutThreshold: v.round()),
                    )
                : null,
          ),
          if (canEdit) CfButton(label: 'Save policies', onPressed: onSave),
        ],
      ),
    );
  }
}

class SocApiPanel extends StatelessWidget {
  const SocApiPanel({super.key, required this.api});
  final ApiSecuritySnapshot api;

  @override
  Widget build(BuildContext context) {
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API security (monitoring only)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Text('Health: ${api.health}'),
          Text('Authentication: ${api.authStatus}'),
          Text('Rate limits: ${api.rateLimitLabel}'),
          Text('Abuse signals: ${api.abuseSignals}'),
          Text('Requests (sample): ${api.requestsSample}'),
          Text('Failures (sample): ${api.failuresSample}'),
          const SizedBox(height: 8),
          Text(
            api.note,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.adminColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class SocCompliancePanel extends StatelessWidget {
  const SocCompliancePanel({super.key, required this.compliance});
  final ComplianceSnapshot compliance;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Privacy compliance', compliance.privacy),
      ('Google API compliance', compliance.googleApi),
      ('Data retention', compliance.dataRetention),
      ('Consent status', compliance.consent),
      ('Audit readiness', compliance.auditReadiness),
      ('GDPR', compliance.gdpr),
    ];
    return CfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final r in rows)
            Material(
              child: ListTile(
                title: Text(r.$1),
                trailing: Text(
                  r.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
