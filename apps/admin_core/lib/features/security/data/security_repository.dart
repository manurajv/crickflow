import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_permission.dart';
import '../../../models/admin_user.dart';
import '../../../models/role_definition.dart';
import '../../../services/admin_role_service.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/managed_security.dart';
import '../models/security_enums.dart';
import '../models/security_filters.dart';

/// Security Operations Center data access.
///
/// Additive collections + existing `admin_roles` / `admin_audit_logs`.
/// Never stores or returns passwords, OAuth tokens, API keys, or Firebase secrets.
class SecurityRepository {
  SecurityRepository({
    FirebaseFirestore? firestore,
    AdminRoleService? roleService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _roles = roleService ?? AdminRoleService();

  final FirebaseFirestore _db;
  final AdminRoleService _roles;

  CollectionReference<Map<String, dynamic>> get _alerts =>
      _db.collection(AdminCollections.adminSecurityAlerts);
  CollectionReference<Map<String, dynamic>> get _blocks =>
      _db.collection(AdminCollections.adminSecurityBlocks);
  CollectionReference<Map<String, dynamic>> get _ips =>
      _db.collection(AdminCollections.adminSecurityIps);
  CollectionReference<Map<String, dynamic>> get _devices =>
      _db.collection(AdminCollections.adminSecurityDevices);
  CollectionReference<Map<String, dynamic>> get _grants =>
      _db.collection(AdminCollections.adminSecurityAccess);
  CollectionReference<Map<String, dynamic>> get _backups =>
      _db.collection(AdminCollections.adminSecurityBackups);
  CollectionReference<Map<String, dynamic>> get _restores =>
      _db.collection(AdminCollections.adminSecurityRestores);
  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection(AdminCollections.adminSecuritySessions);
  DocumentReference<Map<String, dynamic>> get _policiesDoc =>
      _db.collection(AdminCollections.adminSecurityPolicies).doc('global');
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<SecuritySummary> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final alerts = await fetchAlerts(appType: appType, actor: actor, limit: 80);
    final blocks = await fetchBlocks(appType: appType, actor: actor);
    final sessions = await fetchSessionsFromAudit(
      appType: appType,
      actor: actor,
      limit: 100,
    );

    var critical = 0;
    var warnings = 0;
    for (final a in alerts) {
      if (a.status == SocAlertStatus.resolved ||
          a.status == SocAlertStatus.dismissed) {
        continue;
      }
      if (a.severity == SocSeverity.critical || a.severity == SocSeverity.high) {
        critical++;
      } else if (a.severity == SocSeverity.warning) {
        warnings++;
      }
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    var failedToday = 0;
    var suspicious = 0;
    try {
      final snap = await _audit
          .orderBy('timestamp', descending: true)
          .limit(120)
          .get();
      for (final d in snap.docs) {
        final action = (d.data()['action'] as String?) ?? '';
        final ts = d.data()['timestamp'];
        final when = ts is Timestamp ? ts.toDate() : null;
        if (action.contains('login_failed') &&
            when != null &&
            !when.isBefore(today)) {
          failedToday++;
        }
        if (action.startsWith('security.') || action.contains('suspicious')) {
          suspicious++;
        }
      }
    } catch (_) {}

    final blockedUsers =
        blocks.where((b) => b.active && b.kind == SocBlockKind.user).length;
    final blockedDevices =
        blocks.where((b) => b.active && b.kind == SocBlockKind.device).length;
    final blockedIps =
        blocks.where((b) => b.active && b.kind == SocBlockKind.ip).length;

    final expired = sessions.where((s) {
      return s.expiresAt != null && DateTime.now().isAfter(s.expiresAt!);
    }).length;
    final online = sessions.where((s) => s.active).length.clamp(0, 50);

    // Score: start 100, subtract for open issues (capped).
    var score = 100;
    score -= (critical * 8).clamp(0, 40);
    score -= (warnings * 2).clamp(0, 20);
    score -= (failedToday > 10 ? 10 : failedToday);
    score = score.clamp(20, 100);

    return SecuritySummary(
      securityScore: score,
      criticalAlerts: critical,
      warnings: warnings,
      blockedUsers: blockedUsers,
      blockedDevices: blockedDevices,
      blockedIps: blockedIps,
      failedLoginsToday: failedToday,
      suspiciousActivities: suspicious,
      expiredSessions: expired,
      adminsOnline: online,
    );
  }

  // ---------------------------------------------------------------------------
  // Roles / permissions
  // ---------------------------------------------------------------------------

  Future<List<SocRoleView>> fetchRoles() async {
    final defs = await _roles.listAll(includeArchived: true);
    final views = <SocRoleView>[];
    for (final d in defs) {
      final usage = await _roles.countUsersWithRole(d.id);
      views.add(
        SocRoleView(
          definition: d,
          usageCount: usage,
          recordStatus: d.archived
              ? SocRoleRecordStatus.archived
              : SocRoleRecordStatus.active,
        ),
      );
    }
    return views;
  }

  Future<void> saveRole({
    required AdminUser actor,
    required RoleDefinition role,
  }) async {
    await _roles.saveRole(role);
    await _writeAudit(
      action: 'security.role_updated',
      actor: actor,
      targetUid: role.id,
      targetEmail: role.label,
      reason: 'Role saved',
    );
  }

  Future<void> createRole({
    required AdminUser actor,
    required String id,
    required String label,
    String? description,
    Map<String, bool>? permissions,
    AdminAppType? panel,
  }) async {
    final perms = permissions ??
        {
          for (final p in AdminPermission.values) p.name: false,
          AdminPermission.canViewProfile.name: true,
          AdminPermission.canViewDashboard.name: true,
        };
    final role = RoleDefinition(
      id: id,
      label: label,
      description: description ?? '',
      permissions: perms,
      allowedPanel: panel,
      isSystem: false,
    );
    await _roles.saveRole(role);
    await _writeAudit(
      action: 'security.role_created',
      actor: actor,
      targetUid: id,
      targetEmail: label,
    );
  }

  Future<void> duplicateRole({
    required AdminUser actor,
    required RoleDefinition source,
    required String newId,
  }) async {
    await _roles.duplicateRole(source, newId);
    await _writeAudit(
      action: 'security.role_duplicated',
      actor: actor,
      targetUid: newId,
      targetEmail: source.label,
    );
  }

  Future<void> renameRole({
    required AdminUser actor,
    required String roleId,
    required String label,
  }) async {
    await _roles.renameRole(roleId, label);
    await _writeAudit(
      action: 'security.role_renamed',
      actor: actor,
      targetUid: roleId,
      targetEmail: label,
    );
  }

  Future<void> archiveRole({
    required AdminUser actor,
    required String roleId,
  }) async {
    await _roles.archiveRole(roleId);
    await _writeAudit(
      action: 'security.role_archived',
      actor: actor,
      targetUid: roleId,
    );
  }

  Future<void> deleteRole({
    required AdminUser actor,
    required RoleDefinition role,
  }) async {
    await _roles.deleteRole(role.id, isSystem: role.isSystem);
    await _writeAudit(
      action: role.isSystem
          ? 'security.role_archived'
          : 'security.role_deleted',
      actor: actor,
      targetUid: role.id,
      targetEmail: role.label,
    );
  }

  Future<void> updateRolePermissions({
    required AdminUser actor,
    required RoleDefinition role,
    required Map<String, bool> permissions,
  }) async {
    await _roles.saveRole(role.copyWith(permissions: permissions));
    await _writeAudit(
      action: 'security.permission_changed',
      actor: actor,
      targetUid: role.id,
      targetEmail: role.label,
      reason: 'Permission matrix updated',
    );
  }

  // ---------------------------------------------------------------------------
  // Sessions (audit-derived + optional registry)
  // ---------------------------------------------------------------------------

  /// Org Admin must only see sessions tied to their organization.
  /// Platform / unscoped rows (`organizationId` null) are Super Admin only.
  List<ManagedSecuritySession> _scopeSessionsForOrg(
    List<ManagedSecuritySession> items, {
    required AdminAppType appType,
    required AdminUser? actor,
  }) {
    if (appType != AdminAppType.organizationAdmin) return items;
    final orgId = actor?.organizationId?.trim();
    if (orgId == null || orgId.isEmpty) return const [];
    return items.where((s) => s.organizationId == orgId).toList();
  }

  Future<List<ManagedSecuritySession>> fetchSessionsFromAudit({
    required AdminAppType appType,
    required AdminUser? actor,
    int limit = 50,
  }) async {
    try {
      final snap = await _audit
          .where('action', whereIn: [
            AdminAuditActions.adminLoginSuccess,
            AdminAuditActions.adminLogout,
            AdminAuditActions.adminLoginFailed,
          ])
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      var items = snap.docs
          .map((d) => ManagedSecuritySession.fromAuditMap(d.id, d.data()))
          .toList();
      return _scopeSessionsForOrg(items, appType: appType, actor: actor);
    } catch (_) {
      try {
        final snap = await _audit
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();
        final items = snap.docs
            .where((d) {
              final a = (d.data()['action'] as String?) ?? '';
              return a.startsWith('auth.');
            })
            .map((d) => ManagedSecuritySession.fromAuditMap(d.id, d.data()))
            .toList();
        return _scopeSessionsForOrg(items, appType: appType, actor: actor);
      } catch (_) {
        return const [];
      }
    }
  }

  Future<void> terminateSession({
    required AdminUser actor,
    required ManagedSecuritySession session,
  }) async {
    try {
      await _sessions.doc(session.id).set({
        'uid': session.uid,
        'email': session.email,
        'terminated': true,
        'terminatedAt': FieldValue.serverTimestamp(),
        'terminatedBy': actor.uid,
      }, SetOptions(merge: true));
    } catch (_) {}
    await _writeAudit(
      action: 'security.session_terminated',
      actor: actor,
      targetUid: session.uid,
      targetEmail: session.email,
      reason: 'Session terminated from SOC',
    );
  }

  Future<void> terminateAllSessions({
    required AdminUser actor,
    required String targetUid,
    required String targetEmail,
  }) async {
    await _writeAudit(
      action: 'security.sessions_terminated_all',
      actor: actor,
      targetUid: targetUid,
      targetEmail: targetEmail,
      reason: 'Terminate all sessions',
    );
  }

  // ---------------------------------------------------------------------------
  // Devices / alerts / threats / blocks / IPs
  // ---------------------------------------------------------------------------

  Future<List<ManagedSecurityDevice>> fetchDevices({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> q = _devices;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      q = q.where('organizationId', isEqualTo: orgId);
    }
    try {
      final snap =
          await q.orderBy('lastActive', descending: true).limit(80).get();
      return snap.docs
          .map((d) => ManagedSecurityDevice.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ManagedSecurityAlert>> fetchAlerts({
    required AdminAppType appType,
    required AdminUser? actor,
    int limit = 60,
    SecurityFilters filters = SecurityFilters.empty,
  }) async {
    Query<Map<String, dynamic>> q = _alerts;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      q = q.where('organizationId', isEqualTo: orgId);
    }
    try {
      final snap =
          await q.orderBy('createdAt', descending: true).limit(limit).get();
      var items = snap.docs
          .map((d) => ManagedSecurityAlert.fromMap(d.id, d.data()))
          .toList();
      items = _filterAlerts(items, filters);
      return items;
    } catch (_) {
      // Derive lightweight alerts from recent audit failures.
      return _alertsFromAudit(limit: 30);
    }
  }

  List<ManagedSecurityAlert> _filterAlerts(
    List<ManagedSecurityAlert> items,
    SecurityFilters filters,
  ) {
    Iterable<ManagedSecurityAlert> out = items;
    if (filters.severities.isNotEmpty) {
      out = out.where((a) => filters.severities.contains(a.severity));
    }
    if (filters.alertStatuses.isNotEmpty) {
      out = out.where((a) => filters.alertStatuses.contains(a.status));
    }
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((a) =>
          a.title.toLowerCase().contains(q) ||
          a.affectedEmail.toLowerCase().contains(q) ||
          a.detail.toLowerCase().contains(q));
    }
    return out.toList();
  }

  Future<List<ManagedSecurityAlert>> _alertsFromAudit({int limit = 30}) async {
    try {
      final snap =
          await _audit.orderBy('timestamp', descending: true).limit(80).get();
      final alerts = <ManagedSecurityAlert>[];
      for (final d in snap.docs) {
        final a = (d.data()['action'] as String?) ?? '';
        if (!a.contains('failed') &&
            !a.startsWith('security.') &&
            !a.contains('blocked')) {
          continue;
        }
        alerts.add(
          ManagedSecurityAlert(
            id: d.id,
            title: a.replaceAll('.', ' › ').replaceAll('_', ' '),
            detail: (d.data()['reason'] as String?) ?? '',
            severity: a.contains('suspicious') || a.contains('escalation')
                ? SocSeverity.critical
                : SocSeverity.warning,
            affectedUid: (d.data()['targetUid'] as String?) ?? '',
            affectedEmail: (d.data()['targetEmail'] as String?) ??
                (d.data()['actorEmail'] as String?) ??
                '',
            createdAt: d.data()['timestamp'] is Timestamp
                ? (d.data()['timestamp'] as Timestamp).toDate()
                : null,
          ),
        );
        if (alerts.length >= limit) break;
      }
      return alerts;
    } catch (_) {
      return const [];
    }
  }

  Future<void> updateAlertStatus({
    required AdminUser actor,
    required ManagedSecurityAlert alert,
    required SocAlertStatus status,
  }) async {
    try {
      await _alerts.doc(alert.id).set({
        'status': status.wireValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
    await _writeAudit(
      action: 'security.alert_${status.wireValue}',
      actor: actor,
      targetUid: alert.id,
      targetEmail: alert.title,
    );
  }

  List<ManagedThreatRecommendation> threatRecommendations() => const [
        ManagedThreatRecommendation(
          id: 'bf',
          kind: SocThreatKind.bruteForce,
          title: 'Brute force monitoring',
          recommendation:
              'Review failed login clusters. Future AI will score attempts.',
          confidence: 0.4,
          severity: SocSeverity.warning,
        ),
        ManagedThreatRecommendation(
          id: 'bot',
          kind: SocThreatKind.botActivity,
          title: 'Bot activity',
          recommendation:
              'Enable App Check / reCAPTCHA Enterprise when ready.',
          confidence: 0.3,
        ),
        ManagedThreatRecommendation(
          id: 'stuff',
          kind: SocThreatKind.credentialStuffing,
          title: 'Credential stuffing',
          recommendation: 'Watch multi-country login patterns in alerts.',
          confidence: 0.35,
          severity: SocSeverity.high,
        ),
        ManagedThreatRecommendation(
          id: 'ato',
          kind: SocThreatKind.accountTakeover,
          title: 'Account takeover signals',
          recommendation: 'Require re-verification on unknown devices (future).',
          confidence: 0.3,
          severity: SocSeverity.critical,
        ),
      ];

  Future<List<ManagedBlockEntry>> fetchBlocks({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> q = _blocks;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      q = q.where('organizationId', isEqualTo: orgId);
    }
    try {
      final snap =
          await q.orderBy('createdAt', descending: true).limit(100).get();
      return snap.docs
          .map((d) => ManagedBlockEntry.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addBlock({
    required AdminUser actor,
    required ManagedBlockEntry entry,
  }) async {
    await _blocks.add(entry.toCreateMap());
    await _writeAudit(
      action: 'security.block_added',
      actor: actor,
      targetUid: entry.kind.wireValue,
      targetEmail: entry.displayValue,
      reason: entry.reason,
      organizationId: entry.organizationId ?? actor.organizationId,
    );
  }

  Future<void> setBlockActive({
    required AdminUser actor,
    required ManagedBlockEntry entry,
    required bool active,
  }) async {
    await _blocks.doc(entry.id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _writeAudit(
      action: active ? 'security.block_added' : 'security.ip_unblocked',
      actor: actor,
      targetUid: entry.id,
      targetEmail: entry.displayValue,
      reason: active ? 'Re-blocked' : 'Unblocked',
    );
  }

  Future<List<ManagedIpRule>> fetchIpRules() async {
    try {
      final snap =
          await _ips.orderBy('createdAt', descending: true).limit(100).get();
      return snap.docs
          .map((d) => ManagedIpRule.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> addIpRule({
    required AdminUser actor,
    required ManagedIpRule rule,
  }) async {
    await _ips.add(rule.toCreateMap());
    await _writeAudit(
      action: rule.listType == SocIpListType.blacklist
          ? 'security.ip_blocked'
          : 'security.ip_rule_updated',
      actor: actor,
      targetUid: rule.listType.wireValue,
      targetEmail: rule.displayValue,
      reason: rule.note,
    );
  }

  Future<List<ManagedAccessGrant>> fetchAccessGrants({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> q = _grants;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      q = q.where('organizationId', isEqualTo: orgId);
    }
    try {
      final snap =
          await q.orderBy('createdAt', descending: true).limit(80).get();
      return snap.docs
          .map((d) => ManagedAccessGrant.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAccessGrant({
    required AdminUser actor,
    required ManagedAccessGrant grant,
  }) async {
    await _grants.add(grant.toCreateMap());
    await _writeAudit(
      action: 'security.access_granted',
      actor: actor,
      targetUid: grant.subjectUid,
      targetEmail: grant.subjectEmail,
      reason: '${grant.kind.label} · ${grant.note}',
      organizationId: grant.organizationId ?? actor.organizationId,
    );
  }

  // ---------------------------------------------------------------------------
  // Backup / restore / DR / policies / API / compliance
  // ---------------------------------------------------------------------------

  Future<List<ManagedBackupRecord>> fetchBackups() async {
    try {
      final snap =
          await _backups.orderBy('scheduledAt', descending: true).limit(50).get();
      return snap.docs
          .map((d) => ManagedBackupRecord.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return [
        for (final k in SocBackupKind.values)
          ManagedBackupRecord(
            id: k.wireValue,
            kind: k,
            status: SocBackupStatus.planned,
          ),
      ];
    }
  }

  Future<void> scheduleBackup({
    required AdminUser actor,
    required SocBackupKind kind,
  }) async {
    await _backups.add(
      ManagedBackupRecord(
        id: '',
        kind: kind,
        status: SocBackupStatus.scheduled,
        note: 'Queued for future Cloud Function — Firebase not modified',
      ).toCreateMap(),
    );
    await _writeAudit(
      action: 'security.backup_created',
      actor: actor,
      targetUid: kind.wireValue,
      targetEmail: kind.label,
      reason: 'Manual / scheduled backup request',
    );
  }

  Future<List<ManagedRestorePoint>> fetchRestorePoints() async {
    try {
      final snap =
          await _restores.orderBy('createdAt', descending: true).limit(40).get();
      return snap.docs
          .map((d) => ManagedRestorePoint.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [
        ManagedRestorePoint(
          id: 'architecture',
          label: 'No restore points yet',
          previewNote: 'Preview only — no destructive restore from admin UI',
        ),
      ];
    }
  }

  DisasterRecoveryPlan disasterPlan({String? lastBackupLabel}) =>
      DisasterRecoveryPlan(
        lastBackupLabel: lastBackupLabel ?? '—',
      );

  ApiSecuritySnapshot apiSnapshot({int failures = 0}) => ApiSecuritySnapshot(
        failuresSample: failures,
        requestsSample: 0,
        abuseSignals: failures > 20 ? 1 : 0,
      );

  ComplianceSnapshot complianceSnapshot() => const ComplianceSnapshot();

  Future<SecurityPolicies> fetchPolicies() async {
    try {
      final snap = await _policiesDoc.get();
      return SecurityPolicies.fromMap(snap.data());
    } catch (_) {
      return const SecurityPolicies();
    }
  }

  Future<void> savePolicies({
    required AdminUser actor,
    required SecurityPolicies policies,
  }) async {
    await _policiesDoc.set(policies.toMap(), SetOptions(merge: true));
    await _writeAudit(
      action: 'security.policy_updated',
      actor: actor,
      targetUid: 'global',
      targetEmail: 'Security policies',
    );
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    String targetUid = '',
    String targetEmail = '',
    String? reason,
    String? organizationId,
  }) async {
    try {
      final entry = AdminAuditLogEntry(
        id: '',
        action: action,
        actorUid: actor.uid,
        actorEmail: actor.email,
        targetUid: targetUid,
        targetEmail: targetEmail,
        timestamp: DateTime.now(),
        reason: reason,
        metadata: {
          'module': 'security',
          'entity': 'security',
          'role': actor.roleId,
          if ((organizationId ?? actor.organizationId) != null)
            'organizationId': organizationId ?? actor.organizationId,
        },
      );
      await _audit.add(entry.toMap());
    } catch (_) {}
  }
}
