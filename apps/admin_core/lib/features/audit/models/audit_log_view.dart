import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../users/models/admin_audit_log.dart';
import 'audit_enums.dart';

/// Enriched view of an `admin_audit_logs` document for the Audit Center.
///
/// Backward-compatible with existing writes that only store core fields +
/// `metadata`. Derived fields (module, severity, status) are inferred from
/// action / metadata when not stored explicitly.
class AuditLogView extends Equatable {
  const AuditLogView({
    required this.id,
    required this.action,
    required this.actorUid,
    required this.actorEmail,
    required this.targetUid,
    required this.targetEmail,
    required this.timestamp,
    this.reason,
    this.metadata = const {},
    this.module = AuditModule.other,
    this.severity = AuditSeverity.info,
    this.status = AuditStatus.success,
    this.role = '',
    this.organizationId,
    this.ipAddress = '',
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.browser = '',
    this.operatingSystem = '',
    this.device = '',
    this.platform = '',
    this.userAgent = '',
    this.sessionId = '',
    this.oldValue,
    this.newValue,
    this.description = '',
  });

  final String id;
  final String action;
  final String actorUid;
  final String actorEmail;
  final String targetUid;
  final String targetEmail;
  final DateTime timestamp;
  final String? reason;
  final Map<String, dynamic> metadata;
  final AuditModule module;
  final AuditSeverity severity;
  final AuditStatus status;
  final String role;
  final String? organizationId;
  final String ipAddress;
  final String country;
  final String stateProvince;
  final String city;
  final String browser;
  final String operatingSystem;
  final String device;
  final String platform;
  final String userAgent;
  final String sessionId;
  final String? oldValue;
  final String? newValue;
  final String description;

  String get actionLabel =>
      action.replaceAll('.', ' › ').replaceAll('_', ' ');

  String get targetLabel =>
      targetEmail.isNotEmpty ? targetEmail : (targetUid.isEmpty ? '—' : targetUid);

  String get locationLabel {
    final parts = [
      if (city.isNotEmpty) city,
      if (stateProvince.isNotEmpty) stateProvince,
      if (country.isNotEmpty) country,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  bool get isLoginEvent =>
      action.startsWith('auth.login') ||
      action == AdminAuditActions.adminLogout ||
      action == AdminAuditActions.adminSessionBlocked;

  bool get isSecurityEvent =>
      action.startsWith('security.') ||
      action == AdminAuditActions.adminLoginFailed ||
      action == AdminAuditActions.adminSessionBlocked ||
      severity == AuditSeverity.critical ||
      (severity == AuditSeverity.high && action.contains('failed'));

  bool get isPermissionChange =>
      action.contains('role') ||
      action.contains('permission') ||
      action.contains('admin_linked') ||
      action.contains('admin_unlinked') ||
      action.contains('ownership') ||
      action.contains('organization_assigned') ||
      module == AuditModule.security && action.contains('escalation');

  bool get isDataChange {
    final a = action.toLowerCase();
    return a.contains('created') ||
        a.contains('edited') ||
        a.contains('updated') ||
        a.contains('deleted') ||
        a.contains('restored') ||
        a.contains('archived') ||
        a.contains('approved') ||
        a.contains('rejected');
  }

  bool get isSystemEvent =>
      module == AuditModule.settings ||
      module == AuditModule.system ||
      module == AuditModule.cms ||
      action.startsWith('maintenance.') ||
      action.startsWith('feature_flag.') ||
      action.startsWith('app_version.') ||
      action.startsWith('remote_config.');

  factory AuditLogView.fromEntry(AdminAuditLogEntry entry) {
    final meta = entry.metadata;
    final entity = meta['entity'] as String?;
    final module = AuditModule.parse(
      (meta['module'] as String?) ?? entity,
      action: entry.action,
    );
    final severity = AuditSeverity.parse(
      (meta['severity'] as String?) ?? _inferSeverity(entry.action),
    );
    final status = AuditStatus.parse(
      (meta['status'] as String?) ?? _inferStatus(entry.action),
    );

    return AuditLogView(
      id: entry.id,
      action: entry.action,
      actorUid: entry.actorUid,
      actorEmail: entry.actorEmail,
      targetUid: entry.targetUid,
      targetEmail: entry.targetEmail,
      timestamp: entry.timestamp,
      reason: entry.reason,
      metadata: meta,
      module: module,
      severity: severity,
      status: status,
      role: (meta['role'] as String?) ?? (meta['actorRole'] as String?) ?? '',
      organizationId: (meta['organizationId'] as String?)?.trim(),
      ipAddress: (meta['ipAddress'] as String?) ?? '',
      country: (meta['country'] as String?) ?? '',
      stateProvince: (meta['stateProvince'] as String?) ?? '',
      city: (meta['city'] as String?) ?? '',
      browser: (meta['browser'] as String?) ?? '',
      operatingSystem: (meta['operatingSystem'] as String?) ??
          (meta['os'] as String?) ??
          '',
      device: (meta['device'] as String?) ?? '',
      platform: (meta['platform'] as String?) ?? '',
      userAgent: (meta['userAgent'] as String?) ?? '',
      sessionId: (meta['sessionId'] as String?) ?? '',
      oldValue: meta['oldValue']?.toString(),
      newValue: meta['newValue']?.toString(),
      description: (meta['description'] as String?) ??
          entry.action.replaceAll('.', ' ').replaceAll('_', ' '),
    );
  }

  factory AuditLogView.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return AuditLogView.fromEntry(AdminAuditLogEntry.fromMap(id, map));
  }

  AdminAuditLogEntry toEntry() => AdminAuditLogEntry(
        id: id,
        action: action,
        actorUid: actorUid,
        actorEmail: actorEmail,
        targetUid: targetUid,
        targetEmail: targetEmail,
        timestamp: timestamp,
        reason: reason,
        metadata: metadata,
      );

  static String _inferSeverity(String action) {
    final a = action.toLowerCase();
    if (a.contains('banned') ||
        a.contains('blocked') ||
        a.contains('escalation') ||
        a.contains('suspicious') ||
        a.contains('critical')) {
      return AuditSeverity.critical.wireValue;
    }
    if (a.contains('failed') ||
        a.contains('suspended') ||
        a.contains('deleted') ||
        a.contains('rejected')) {
      return AuditSeverity.high.wireValue;
    }
    if (a.contains('password') ||
        a.contains('role') ||
        a.contains('permission') ||
        a.contains('maintenance.started')) {
      return AuditSeverity.warning.wireValue;
    }
    return AuditSeverity.info.wireValue;
  }

  static String _inferStatus(String action) {
    final a = action.toLowerCase();
    if (a.contains('failed')) return AuditStatus.failed.wireValue;
    if (a.contains('blocked')) return AuditStatus.blocked.wireValue;
    if (a.contains('expired')) return AuditStatus.expired.wireValue;
    return AuditStatus.success.wireValue;
  }

  @override
  List<Object?> get props => [id, action, timestamp, severity];
}

class AuditPageResult {
  const AuditPageResult({
    required this.logs,
    required this.hasMore,
    this.cursor,
  });

  final List<AuditLogView> logs;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
}

class AuditDashboardStats extends Equatable {
  const AuditDashboardStats({
    this.actionsToday = 0,
    this.failedActions = 0,
    this.securityEvents = 0,
    this.loginsToday = 0,
    this.activeAdmins = 0,
    this.permissionChanges = 0,
    this.suspiciousActivities = 0,
    this.criticalEvents = 0,
  });

  final int actionsToday;
  final int failedActions;
  final int securityEvents;
  final int loginsToday;
  final int activeAdmins;
  final int permissionChanges;
  final int suspiciousActivities;
  final int criticalEvents;

  @override
  List<Object?> get props => [
        actionsToday,
        failedActions,
        securityEvents,
        loginsToday,
        criticalEvents,
      ];
}

class AuditHubSnapshot extends Equatable {
  const AuditHubSnapshot({
    this.stats = const AuditDashboardStats(),
    this.recent = const [],
    this.retention = AuditRetentionPeriod.days90,
  });

  final AuditDashboardStats stats;
  final List<AuditLogView> recent;
  final AuditRetentionPeriod retention;

  @override
  List<Object?> get props => [stats, recent, retention];
}
