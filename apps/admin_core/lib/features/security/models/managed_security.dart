import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../../../models/admin_permission.dart';
import '../../../models/role_definition.dart';
import 'security_enums.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String _maskIp(String? ip) {
  if (ip == null || ip.isEmpty) return '—';
  final parts = ip.split('.');
  if (parts.length == 4) return '${parts[0]}.${parts[1]}.***.***';
  if (ip.length > 8) return '${ip.substring(0, 4)}…****';
  return '****';
}

class SecuritySummary extends Equatable {
  const SecuritySummary({
    this.securityScore = 75,
    this.criticalAlerts = 0,
    this.warnings = 0,
    this.blockedUsers = 0,
    this.blockedDevices = 0,
    this.blockedIps = 0,
    this.failedLoginsToday = 0,
    this.suspiciousActivities = 0,
    this.expiredSessions = 0,
    this.adminsOnline = 0,
  });

  final int securityScore;
  final int criticalAlerts;
  final int warnings;
  final int blockedUsers;
  final int blockedDevices;
  final int blockedIps;
  final int failedLoginsToday;
  final int suspiciousActivities;
  final int expiredSessions;
  final int adminsOnline;

  @override
  List<Object?> get props => [securityScore, criticalAlerts, failedLoginsToday];
}

class ManagedSecuritySession extends Equatable {
  const ManagedSecuritySession({
    required this.id,
    this.uid = '',
    this.email = '',
    this.roleId = '',
    this.ipMasked = '—',
    this.browser = '',
    this.os = '',
    this.country = '',
    this.stateProvince = '',
    this.city = '',
    this.lastLogin,
    this.expiresAt,
    this.active = true,
    this.organizationId,
  });

  final String id;
  final String uid;
  final String email;
  final String roleId;
  final String ipMasked;
  final String browser;
  final String os;
  final String country;
  final String stateProvince;
  final String city;
  final DateTime? lastLogin;
  final DateTime? expiresAt;
  final bool active;
  final String? organizationId;

  Duration? get duration {
    if (lastLogin == null) return null;
    final end = expiresAt ?? DateTime.now();
    return end.difference(lastLogin!);
  }

  factory ManagedSecuritySession.fromAuditMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final meta = map['metadata'];
    final m = meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
    final ts = _ts(map['timestamp']);
    final ip = (m['ipAddress'] ?? m['ip'] ?? '') as String;
    return ManagedSecuritySession(
      id: id,
      uid: (map['actorUid'] as String?) ?? (map['targetUid'] as String?) ?? '',
      email:
          (map['actorEmail'] as String?) ?? (map['targetEmail'] as String?) ?? '',
      roleId: (m['role'] ?? m['actorRole'] ?? '') as String,
      ipMasked: _maskIp(ip.isEmpty ? null : ip),
      browser: (m['browser'] ?? m['userAgent'] ?? m['platform'] ?? '') as String,
      os: (m['os'] ?? '') as String,
      country: (m['country'] ?? '') as String,
      stateProvince: (m['state'] ?? m['stateProvince'] ?? '') as String,
      city: (m['city'] ?? '') as String,
      lastLogin: ts,
      expiresAt: ts?.add(const Duration(hours: 12)),
      active: map['action'] == 'auth.login_success',
      organizationId: m['organizationId'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, uid, active, lastLogin];
}

class ManagedSecurityDevice extends Equatable {
  const ManagedSecurityDevice({
    required this.id,
    this.uid = '',
    this.email = '',
    this.deviceClass = 'Desktop',
    this.browser = '',
    this.browserVersion = '',
    this.os = '',
    this.lastActive,
    this.trusted = false,
    this.organizationId,
  });

  final String id;
  final String uid;
  final String email;
  final String deviceClass;
  final String browser;
  final String browserVersion;
  final String os;
  final DateTime? lastActive;
  final bool trusted;
  final String? organizationId;

  factory ManagedSecurityDevice.fromMap(String id, Map<String, dynamic> map) {
    return ManagedSecurityDevice(
      id: id,
      uid: (map['uid'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      deviceClass: (map['deviceClass'] as String?) ?? 'Desktop',
      browser: (map['browser'] as String?) ?? '',
      browserVersion: (map['browserVersion'] as String?) ?? '',
      os: (map['os'] as String?) ?? '',
      lastActive: _ts(map['lastActive']),
      trusted: map['trusted'] as bool? ?? false,
      organizationId: map['organizationId'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'uid': uid,
        'email': email,
        'deviceClass': deviceClass,
        'browser': browser,
        'browserVersion': browserVersion,
        'os': os,
        'lastActive': FieldValue.serverTimestamp(),
        'trusted': trusted,
        if (organizationId != null) 'organizationId': organizationId,
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, uid, trusted, lastActive];
}

class ManagedSecurityAlert extends Equatable {
  const ManagedSecurityAlert({
    required this.id,
    required this.title,
    this.detail = '',
    this.severity = SocSeverity.warning,
    this.status = SocAlertStatus.open,
    this.affectedUid = '',
    this.affectedEmail = '',
    this.organizationId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String detail;
  final SocSeverity severity;
  final SocAlertStatus status;
  final String affectedUid;
  final String affectedEmail;
  final String? organizationId;
  final DateTime? createdAt;

  factory ManagedSecurityAlert.fromMap(String id, Map<String, dynamic> map) {
    return ManagedSecurityAlert(
      id: id,
      title: (map['title'] as String?) ?? '',
      detail: (map['detail'] as String?) ?? '',
      severity: SocSeverity.parse(map['severity'] as String?),
      status: SocAlertStatus.parse(map['status'] as String?),
      affectedUid: (map['affectedUid'] as String?) ?? '',
      affectedEmail: (map['affectedEmail'] as String?) ?? '',
      organizationId: map['organizationId'] as String?,
      createdAt: _ts(map['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'title': title,
        'detail': detail,
        'severity': severity.wireValue,
        'status': status.wireValue,
        'affectedUid': affectedUid,
        'affectedEmail': affectedEmail,
        if (organizationId != null) 'organizationId': organizationId,
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, severity, status];
}

class ManagedThreatRecommendation extends Equatable {
  const ManagedThreatRecommendation({
    required this.id,
    required this.kind,
    required this.title,
    this.recommendation = '',
    this.confidence = 0.5,
    this.severity = SocSeverity.warning,
  });

  final String id;
  final SocThreatKind kind;
  final String title;
  final String recommendation;
  final double confidence;
  final SocSeverity severity;

  @override
  List<Object?> get props => [id, kind, title];
}

class ManagedBlockEntry extends Equatable {
  const ManagedBlockEntry({
    required this.id,
    required this.kind,
    required this.value,
    this.reason = '',
    this.duration = SocBlockDuration.permanent,
    this.expiresAt,
    this.active = true,
    this.organizationId,
    this.createdAt,
  });

  final String id;
  final SocBlockKind kind;
  final String value;
  final String reason;
  final SocBlockDuration duration;
  final DateTime? expiresAt;
  final bool active;
  final String? organizationId;
  final DateTime? createdAt;

  /// Display value — emails/IPs partially masked in UI.
  String get displayValue {
    if (kind == SocBlockKind.ip) return _maskIp(value);
    if (kind == SocBlockKind.email && value.contains('@')) {
      final parts = value.split('@');
      final local = parts.first;
      final masked = local.length <= 2
          ? '**'
          : '${local.substring(0, 1)}***${local.substring(local.length - 1)}';
      return '$masked@${parts.last}';
    }
    return value;
  }

  factory ManagedBlockEntry.fromMap(String id, Map<String, dynamic> map) {
    return ManagedBlockEntry(
      id: id,
      kind: SocBlockKind.parse(map['kind'] as String?),
      value: (map['value'] as String?) ?? '',
      reason: (map['reason'] as String?) ?? '',
      duration: SocBlockDuration.parse(map['duration'] as String?),
      expiresAt: _ts(map['expiresAt']),
      active: map['active'] as bool? ?? true,
      organizationId: map['organizationId'] as String?,
      createdAt: _ts(map['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'kind': kind.wireValue,
        'value': value,
        'reason': reason,
        'duration': duration.wireValue,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        'active': active,
        if (organizationId != null) 'organizationId': organizationId,
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, kind, value, active];
}

class ManagedIpRule extends Equatable {
  const ManagedIpRule({
    required this.id,
    required this.listType,
    required this.value,
    this.note = '',
    this.active = true,
    this.createdAt,
  });

  final String id;
  final SocIpListType listType;
  final String value;
  final String note;
  final bool active;
  final DateTime? createdAt;

  String get displayValue =>
      listType == SocIpListType.whitelist || listType == SocIpListType.blacklist
          ? _maskIp(value)
          : value;

  factory ManagedIpRule.fromMap(String id, Map<String, dynamic> map) {
    return ManagedIpRule(
      id: id,
      listType: SocIpListType.parse(map['listType'] as String?),
      value: (map['value'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      active: map['active'] as bool? ?? true,
      createdAt: _ts(map['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'listType': listType.wireValue,
        'value': value,
        'note': note,
        'active': active,
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, listType, value];
}

class ManagedAccessGrant extends Equatable {
  const ManagedAccessGrant({
    required this.id,
    required this.kind,
    this.subjectEmail = '',
    this.subjectUid = '',
    this.module = '',
    this.organizationId,
    this.expiresAt,
    this.note = '',
    this.active = true,
    this.createdAt,
  });

  final String id;
  final SocAccessKind kind;
  final String subjectEmail;
  final String subjectUid;
  final String module;
  final String? organizationId;
  final DateTime? expiresAt;
  final String note;
  final bool active;
  final DateTime? createdAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory ManagedAccessGrant.fromMap(String id, Map<String, dynamic> map) {
    return ManagedAccessGrant(
      id: id,
      kind: SocAccessKind.parse(map['kind'] as String?),
      subjectEmail: (map['subjectEmail'] as String?) ?? '',
      subjectUid: (map['subjectUid'] as String?) ?? '',
      module: (map['module'] as String?) ?? '',
      organizationId: map['organizationId'] as String?,
      expiresAt: _ts(map['expiresAt']),
      note: (map['note'] as String?) ?? '',
      active: map['active'] as bool? ?? true,
      createdAt: _ts(map['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'kind': kind.wireValue,
        'subjectEmail': subjectEmail,
        'subjectUid': subjectUid,
        'module': module,
        if (organizationId != null) 'organizationId': organizationId,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        'note': note,
        'active': active,
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, kind, subjectEmail, expiresAt];
}

class ManagedBackupRecord extends Equatable {
  const ManagedBackupRecord({
    required this.id,
    required this.kind,
    this.status = SocBackupStatus.planned,
    this.note = 'Architecture ready — no automatic Firebase backup',
    this.scheduledAt,
    this.completedAt,
  });

  final String id;
  final SocBackupKind kind;
  final SocBackupStatus status;
  final String note;
  final DateTime? scheduledAt;
  final DateTime? completedAt;

  factory ManagedBackupRecord.fromMap(String id, Map<String, dynamic> map) {
    return ManagedBackupRecord(
      id: id,
      kind: SocBackupKind.parse(map['kind'] as String?),
      status: SocBackupStatus.parse(map['status'] as String?),
      note: (map['note'] as String?) ?? '',
      scheduledAt: _ts(map['scheduledAt']),
      completedAt: _ts(map['completedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'kind': kind.wireValue,
        'status': status.wireValue,
        'note': note,
        'scheduledAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, kind, status];
}

class ManagedRestorePoint extends Equatable {
  const ManagedRestorePoint({
    required this.id,
    required this.label,
    this.validated = false,
    this.previewNote = 'Preview only — no destructive restore from admin UI',
    this.createdAt,
  });

  final String id;
  final String label;
  final bool validated;
  final String previewNote;
  final DateTime? createdAt;

  factory ManagedRestorePoint.fromMap(String id, Map<String, dynamic> map) {
    return ManagedRestorePoint(
      id: id,
      label: (map['label'] as String?) ?? '',
      validated: map['validated'] as bool? ?? false,
      previewNote: (map['previewNote'] as String?) ?? '',
      createdAt: _ts(map['createdAt']),
    );
  }

  @override
  List<Object?> get props => [id, label, validated];
}

class SecurityPolicies extends Equatable {
  const SecurityPolicies({
    this.minPasswordLength = 8,
    this.sessionTimeoutMinutes = 720,
    this.require2fa = false,
    this.loginRestrictionsEnabled = false,
    this.accountLockoutThreshold = 5,
    this.updatedAt,
  });

  final int minPasswordLength;
  final int sessionTimeoutMinutes;
  final bool require2fa;
  final bool loginRestrictionsEnabled;
  final int accountLockoutThreshold;
  final DateTime? updatedAt;

  factory SecurityPolicies.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const SecurityPolicies();
    return SecurityPolicies(
      minPasswordLength: (map['minPasswordLength'] as num?)?.toInt() ?? 8,
      sessionTimeoutMinutes:
          (map['sessionTimeoutMinutes'] as num?)?.toInt() ?? 720,
      require2fa: map['require2fa'] as bool? ?? false,
      loginRestrictionsEnabled:
          map['loginRestrictionsEnabled'] as bool? ?? false,
      accountLockoutThreshold:
          (map['accountLockoutThreshold'] as num?)?.toInt() ?? 5,
      updatedAt: _ts(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'minPasswordLength': minPasswordLength,
        'sessionTimeoutMinutes': sessionTimeoutMinutes,
        'require2fa': require2fa,
        'loginRestrictionsEnabled': loginRestrictionsEnabled,
        'accountLockoutThreshold': accountLockoutThreshold,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  SecurityPolicies copyWith({
    int? minPasswordLength,
    int? sessionTimeoutMinutes,
    bool? require2fa,
    bool? loginRestrictionsEnabled,
    int? accountLockoutThreshold,
  }) {
    return SecurityPolicies(
      minPasswordLength: minPasswordLength ?? this.minPasswordLength,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      require2fa: require2fa ?? this.require2fa,
      loginRestrictionsEnabled:
          loginRestrictionsEnabled ?? this.loginRestrictionsEnabled,
      accountLockoutThreshold:
          accountLockoutThreshold ?? this.accountLockoutThreshold,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        minPasswordLength,
        sessionTimeoutMinutes,
        require2fa,
        loginRestrictionsEnabled,
        accountLockoutThreshold,
      ];
}

class ApiSecuritySnapshot extends Equatable {
  const ApiSecuritySnapshot({
    this.health = 'Healthy',
    this.authStatus = 'Active',
    this.rateLimitLabel = 'Configured (monitoring)',
    this.abuseSignals = 0,
    this.requestsSample = 0,
    this.failuresSample = 0,
    this.note =
        'Monitoring only — secrets, tokens, and keys are never displayed',
  });

  final String health;
  final String authStatus;
  final String rateLimitLabel;
  final int abuseSignals;
  final int requestsSample;
  final int failuresSample;
  final String note;

  @override
  List<Object?> get props => [health, abuseSignals, failuresSample];
}

class DisasterRecoveryPlan extends Equatable {
  const DisasterRecoveryPlan({
    this.summary = 'Architecture prepared for Cloud backup / restore workers',
    this.criticalSystems = const [
      'Firebase Auth',
      'Firestore',
      'Cloud Functions',
      'Hosting',
      'Storage',
    ],
    this.recoveryStatus = 'Not automated',
    this.lastBackupLabel = '—',
    this.estimatedRecoveryTime = 'TBD',
  });

  final String summary;
  final List<String> criticalSystems;
  final String recoveryStatus;
  final String lastBackupLabel;
  final String estimatedRecoveryTime;

  @override
  List<Object?> get props => [recoveryStatus, lastBackupLabel];
}

class ComplianceSnapshot extends Equatable {
  const ComplianceSnapshot({
    this.privacy = 'Prepared',
    this.googleApi = 'Prepared',
    this.dataRetention = 'Policy UI ready',
    this.consent = 'Future',
    this.auditReadiness = 'Audit Center linked',
    this.gdpr = 'Future GDPR support',
  });

  final String privacy;
  final String googleApi;
  final String dataRetention;
  final String consent;
  final String auditReadiness;
  final String gdpr;

  @override
  List<Object?> get props => [privacy, auditReadiness];
}

/// Role row for SOC Role Management (wraps [RoleDefinition]).
class SocRoleView extends Equatable {
  const SocRoleView({
    required this.definition,
    this.usageCount = 0,
    this.recordStatus = SocRoleRecordStatus.active,
  });

  final RoleDefinition definition;
  final int usageCount;
  final SocRoleRecordStatus recordStatus;

  String get id => definition.id;
  String get label => definition.label;
  bool get isSystem => definition.isSystem;
  Map<String, bool> get permissions => definition.permissions;
  Set<AdminPermission> get permissionSet => definition.permissionSet;

  @override
  List<Object?> get props => [id, usageCount, recordStatus];
}
