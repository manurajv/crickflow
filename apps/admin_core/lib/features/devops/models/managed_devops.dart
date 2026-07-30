import 'package:cloud_firestore/cloud_firestore.dart';

import 'devops_enums.dart';

class DevOpsSummary {
  const DevOpsSummary({
    this.currentEnvironment = DevOpsEnvironment.development,
    this.currentVersion = '—',
    this.latestVersion = '—',
    this.lastDeploymentLabel = '—',
    this.deploymentStatus = DevOpsDeployStatus.queued,
    this.deploymentDurationLabel = '—',
    this.environmentHealth = 'Unknown',
    this.firebaseProject = 'crickflow-b06bc',
    this.hostingStatus = 'Monitor only',
    this.domainStatus = 'Monitor only',
    this.openReleases = 0,
    this.failedBuilds = 0,
    this.activeRollouts = 0,
  });

  final DevOpsEnvironment currentEnvironment;
  final String currentVersion;
  final String latestVersion;
  final String lastDeploymentLabel;
  final DevOpsDeployStatus deploymentStatus;
  final String deploymentDurationLabel;
  final String environmentHealth;
  final String firebaseProject;
  final String hostingStatus;
  final String domainStatus;
  final int openReleases;
  final int failedBuilds;
  final int activeRollouts;
}

class ManagedRelease {
  const ManagedRelease({
    required this.id,
    required this.version,
    required this.title,
    this.summary = '',
    this.newFeatures = const [],
    this.bugFixes = const [],
    this.breakingChanges = const [],
    this.knownIssues = const [],
    this.releaseType = DevOpsReleaseType.patch,
    this.status = DevOpsReleaseStatus.draft,
    this.environment = DevOpsEnvironment.staging,
    this.buildNumber,
    this.releaseDate,
    this.scheduledAt,
    this.authorEmail = '',
    this.authorUid = '',
    this.createdAt,
  });

  final String id;
  final String version;
  final String title;
  final String summary;
  final List<String> newFeatures;
  final List<String> bugFixes;
  final List<String> breakingChanges;
  final List<String> knownIssues;
  final DevOpsReleaseType releaseType;
  final DevOpsReleaseStatus status;
  final DevOpsEnvironment environment;
  final String? buildNumber;
  final DateTime? releaseDate;
  final DateTime? scheduledAt;
  final String authorEmail;
  final String authorUid;
  final DateTime? createdAt;

  factory ManagedRelease.fromMap(String id, Map<String, dynamic> map) {
    List<String> lines(dynamic v) {
      if (v is List) {
        return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      if (v is String && v.trim().isNotEmpty) {
        return v.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ManagedRelease(
      id: id,
      version: (map['version'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      summary: (map['summary'] as String?) ?? '',
      newFeatures: lines(map['newFeatures']),
      bugFixes: lines(map['bugFixes']),
      breakingChanges: lines(map['breakingChanges']),
      knownIssues: lines(map['knownIssues']),
      releaseType: DevOpsReleaseType.parse(map['releaseType'] as String?),
      status: DevOpsReleaseStatus.parse(map['status'] as String?),
      environment: DevOpsEnvironment.parse(map['environment'] as String?),
      buildNumber: map['buildNumber'] as String?,
      releaseDate: ts(map['releaseDate'] ?? map['publishedAt']),
      scheduledAt: ts(map['scheduledAt']),
      authorEmail: (map['authorEmail'] as String?) ?? '',
      authorUid: (map['authorUid'] as String?) ?? '',
      createdAt: ts(map['createdAt']),
    );
  }

  Map<String, dynamic> toCreateMap({
    required String authorUid,
    required String authorEmail,
  }) =>
      {
        'version': version,
        'title': title,
        'summary': summary,
        'newFeatures': newFeatures,
        'bugFixes': bugFixes,
        'breakingChanges': breakingChanges,
        'knownIssues': knownIssues,
        'releaseType': releaseType.wireValue,
        'status': status.wireValue,
        'environment': environment.wireValue,
        'buildNumber': buildNumber,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'authorUid': authorUid,
        'authorEmail': authorEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class ManagedDeploymentLog {
  const ManagedDeploymentLog({
    required this.id,
    required this.label,
    this.environment = DevOpsEnvironment.staging,
    this.status = DevOpsDeployStatus.queued,
    this.version = '',
    this.triggeredBy = '',
    this.startedAt,
    this.completedAt,
    this.durationLabel = '—',
    this.message = '',
  });

  final String id;
  final String label;
  final DevOpsEnvironment environment;
  final DevOpsDeployStatus status;
  final String version;
  final String triggeredBy;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String durationLabel;
  final String message;

  factory ManagedDeploymentLog.fromMap(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ManagedDeploymentLog(
      id: id,
      label: (map['label'] as String?) ?? (map['version'] as String?) ?? id,
      environment: DevOpsEnvironment.parse(map['environment'] as String?),
      status: DevOpsDeployStatus.parse(map['status'] as String?),
      version: (map['version'] as String?) ?? '',
      triggeredBy: (map['triggeredBy'] as String?) ?? '',
      startedAt: ts(map['startedAt']),
      completedAt: ts(map['completedAt']),
      durationLabel: (map['durationLabel'] as String?) ?? '—',
      message: (map['message'] as String?) ?? '',
    );
  }
}

class ManagedBuild {
  const ManagedBuild({
    required this.id,
    required this.label,
    this.status = DevOpsBuildStatus.queued,
    this.environment = DevOpsEnvironment.staging,
    this.durationLabel = '—',
    this.version = '',
    this.startedAt,
    this.provider = 'Future CI/CD',
  });

  final String id;
  final String label;
  final DevOpsBuildStatus status;
  final DevOpsEnvironment environment;
  final String durationLabel;
  final String version;
  final DateTime? startedAt;
  final String provider;

  factory ManagedBuild.fromMap(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ManagedBuild(
      id: id,
      label: (map['label'] as String?) ?? id,
      status: DevOpsBuildStatus.parse(map['status'] as String?),
      environment: DevOpsEnvironment.parse(map['environment'] as String?),
      durationLabel: (map['durationLabel'] as String?) ?? '—',
      version: (map['version'] as String?) ?? '',
      startedAt: ts(map['startedAt']),
      provider: (map['provider'] as String?) ?? 'Future CI/CD',
    );
  }
}

class ManagedRollout {
  const ManagedRollout({
    required this.id,
    required this.featureKey,
    required this.title,
    this.percent = DevOpsRolloutPercent.internal,
    this.status = DevOpsRolloutStatus.planned,
    this.environment = DevOpsEnvironment.staging,
    this.note = '',
    this.updatedAt,
  });

  final String id;
  final String featureKey;
  final String title;
  final DevOpsRolloutPercent percent;
  final DevOpsRolloutStatus status;
  final DevOpsEnvironment environment;
  final String note;
  final DateTime? updatedAt;

  factory ManagedRollout.fromMap(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ManagedRollout(
      id: id,
      featureKey: (map['featureKey'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      percent: DevOpsRolloutPercent.parse(map['percent'] as String?),
      status: DevOpsRolloutStatus.parse(map['status'] as String?),
      environment: DevOpsEnvironment.parse(map['environment'] as String?),
      note: (map['note'] as String?) ?? '',
      updatedAt: ts(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'featureKey': featureKey,
        'title': title,
        'percent': percent.wireValue,
        'status': status.wireValue,
        'environment': environment.wireValue,
        'note': note,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class ManagedRollbackPlan {
  const ManagedRollbackPlan({
    required this.id,
    required this.targetVersion,
    this.fromVersion = '',
    this.reason = '',
    this.status = 'prepared',
    this.environment = DevOpsEnvironment.production,
    this.createdAt,
    this.createdBy = '',
  });

  final String id;
  final String targetVersion;
  final String fromVersion;
  final String reason;
  final String status;
  final DevOpsEnvironment environment;
  final DateTime? createdAt;
  final String createdBy;

  factory ManagedRollbackPlan.fromMap(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ManagedRollbackPlan(
      id: id,
      targetVersion: (map['targetVersion'] as String?) ?? '',
      fromVersion: (map['fromVersion'] as String?) ?? '',
      reason: (map['reason'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'prepared',
      environment: DevOpsEnvironment.parse(map['environment'] as String?),
      createdAt: ts(map['createdAt']),
      createdBy: (map['createdBy'] as String?) ?? '',
    );
  }
}

class ManagedDomain {
  const ManagedDomain({
    required this.id,
    required this.host,
    this.status = DevOpsDomainStatus.unknown,
    this.ssl = 'Unknown',
    this.dns = 'Unknown',
    this.lastChecked,
    this.certificateExpiry,
    this.note = '',
  });

  final String id;
  final String host;
  final DevOpsDomainStatus status;
  final String ssl;
  final String dns;
  final DateTime? lastChecked;
  final DateTime? certificateExpiry;
  final String note;

  factory ManagedDomain.fromMap(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ManagedDomain(
      id: id,
      host: (map['host'] as String?) ?? id,
      status: DevOpsDomainStatus.parse(map['status'] as String?),
      ssl: (map['ssl'] as String?) ?? 'Unknown',
      dns: (map['dns'] as String?) ?? 'Unknown',
      lastChecked: ts(map['lastChecked']),
      certificateExpiry: ts(map['certificateExpiry']),
      note: (map['note'] as String?) ?? '',
    );
  }
}

/// Env var metadata only — values are always masked in UI and storage.
class ManagedEnvVar {
  const ManagedEnvVar({
    required this.id,
    required this.key,
    required this.environment,
    this.maskedValue = '••••••••',
    this.configured = false,
    this.sensitive = true,
    this.validation = 'Present',
  });

  final String id;
  final String key;
  final DevOpsEnvironment environment;
  final String maskedValue;
  final bool configured;
  final bool sensitive;
  final String validation;

  factory ManagedEnvVar.fromMap(String id, Map<String, dynamic> map) {
    final key = (map['key'] as String?) ?? id;
    final sensitive = map['sensitive'] as bool? ?? true;
    return ManagedEnvVar(
      id: id,
      key: key,
      environment: DevOpsEnvironment.parse(map['environment'] as String?),
      maskedValue: sensitive
          ? '••••••••'
          : ((map['displayValue'] as String?) ?? '••••••••'),
      configured: map['configured'] as bool? ?? false,
      sensitive: sensitive,
      validation: (map['validation'] as String?) ?? 'Present',
    );
  }
}

class ManagedTimelineEvent {
  const ManagedTimelineEvent({
    required this.id,
    required this.title,
    this.kind = DevOpsTimelineKind.other,
    this.environment = DevOpsEnvironment.staging,
    this.detail = '',
    this.at,
    this.actorEmail = '',
  });

  final String id;
  final String title;
  final DevOpsTimelineKind kind;
  final DevOpsEnvironment environment;
  final String detail;
  final DateTime? at;
  final String actorEmail;

  factory ManagedTimelineEvent.fromMap(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ManagedTimelineEvent(
      id: id,
      title: (map['title'] as String?) ?? '',
      kind: DevOpsTimelineKind.parse(map['kind'] as String?),
      environment: DevOpsEnvironment.parse(map['environment'] as String?),
      detail: (map['detail'] as String?) ?? '',
      at: ts(map['at'] ?? map['createdAt']),
      actorEmail: (map['actorEmail'] as String?) ?? '',
    );
  }
}

class QualityGateItem {
  const QualityGateItem({
    required this.id,
    required this.label,
    this.passed = false,
    this.note = '',
  });

  final String id;
  final String label;
  final bool passed;
  final String note;
}

class DevOpsPlatformSettings {
  const DevOpsPlatformSettings({
    this.activeEnvironment = DevOpsEnvironment.development,
    this.currentVersion = '0.1.0',
    this.latestVersion = '0.1.0',
    this.firebaseProjectId = 'crickflow-b06bc',
    this.hostingNote = 'Monitor only — deploy via Firebase CLI / CI',
    this.qualityGates = const [],
  });

  final DevOpsEnvironment activeEnvironment;
  final String currentVersion;
  final String latestVersion;
  final String firebaseProjectId;
  final String hostingNote;
  final List<QualityGateItem> qualityGates;

  factory DevOpsPlatformSettings.fromMap(Map<String, dynamic> map) {
    final gatesRaw = map['qualityGates'];
    final gates = <QualityGateItem>[];
    if (gatesRaw is List) {
      for (final g in gatesRaw) {
        if (g is Map) {
          gates.add(
            QualityGateItem(
              id: (g['id'] as String?) ?? '',
              label: (g['label'] as String?) ?? '',
              passed: g['passed'] as bool? ?? false,
              note: (g['note'] as String?) ?? '',
            ),
          );
        }
      }
    }
    return DevOpsPlatformSettings(
      activeEnvironment:
          DevOpsEnvironment.parse(map['activeEnvironment'] as String?),
      currentVersion: (map['currentVersion'] as String?) ?? '0.1.0',
      latestVersion: (map['latestVersion'] as String?) ?? '0.1.0',
      firebaseProjectId:
          (map['firebaseProjectId'] as String?) ?? 'crickflow-b06bc',
      hostingNote: (map['hostingNote'] as String?) ??
          'Monitor only — deploy via Firebase CLI / CI',
      qualityGates: gates.isEmpty ? defaultQualityGates : gates,
    );
  }

  static const defaultQualityGates = [
    QualityGateItem(id: 'ci_analyze', label: 'CI: Flutter Analyze'),
    QualityGateItem(id: 'ci_format', label: 'CI: Format Check'),
    QualityGateItem(id: 'ci_tests', label: 'CI: Unit Tests'),
    QualityGateItem(id: 'ci_build', label: 'CI: Web Build'),
    QualityGateItem(id: 'ci_secrets', label: 'CI: Secret Scan'),
    QualityGateItem(id: 'auth', label: 'Authentication Verified'),
    QualityGateItem(id: 'perms', label: 'Permissions Verified'),
    QualityGateItem(id: 'fs_rules', label: 'Firestore Rules Verified'),
    QualityGateItem(id: 'storage_rules', label: 'Storage Rules Verified'),
    QualityGateItem(id: 'hosting', label: 'Hosting Healthy'),
    QualityGateItem(id: 'functions', label: 'Cloud Functions Healthy'),
    QualityGateItem(id: 'errors', label: 'No Critical Errors'),
    QualityGateItem(id: 'ready', label: 'Ready for Production'),
  ];
}
