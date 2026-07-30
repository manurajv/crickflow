import 'package:cloud_firestore/cloud_firestore.dart';

import 'continuity_enums.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

class ContinuitySummary {
  const ContinuitySummary({
    this.latestBackupLabel = '—',
    this.lastSuccessLabel = '—',
    this.lastFailedLabel = '—',
    this.firestoreStatus = 'Monitor only',
    this.storageStatus = 'Monitor only',
    this.configStatus = 'Monitor only',
    this.estimatedSizeLabel = '—',
    this.recoveryReadiness = 'Architecture ready',
    this.recoveryScore = 0,
    this.environment = 'production',
    this.openRestores = 0,
    this.openMigrations = 0,
  });

  final String latestBackupLabel;
  final String lastSuccessLabel;
  final String lastFailedLabel;
  final String firestoreStatus;
  final String storageStatus;
  final String configStatus;
  final String estimatedSizeLabel;
  final String recoveryReadiness;
  final int recoveryScore;
  final String environment;
  final int openRestores;
  final int openMigrations;
}

class ManagedContinuityBackup {
  const ManagedContinuityBackup({
    required this.id,
    required this.type,
    this.environment = 'production',
    this.status = ContinuityJobStatus.planned,
    this.frequency = ContinuityFrequency.manual,
    this.createdByEmail = '',
    this.createdByUid = '',
    this.version = '',
    this.estimatedSizeLabel = '—',
    this.durationLabel = '—',
    this.collections = const [],
    this.integrityOk = false,
    this.note = '',
    this.createdAt,
  });

  final String id;
  final ContinuityBackupType type;
  final String environment;
  final ContinuityJobStatus status;
  final ContinuityFrequency frequency;
  final String createdByEmail;
  final String createdByUid;
  final String version;
  final String estimatedSizeLabel;
  final String durationLabel;
  final List<String> collections;
  final bool integrityOk;
  final String note;
  final DateTime? createdAt;

  factory ManagedContinuityBackup.fromMap(String id, Map<String, dynamic> map) {
    final cols = <String>[];
    final raw = map['collections'];
    if (raw is List) {
      cols.addAll(raw.map((e) => e.toString()));
    }
    return ManagedContinuityBackup(
      id: id,
      type: ContinuityBackupType.parse(map['type'] as String?),
      environment: (map['environment'] as String?) ?? 'production',
      status: ContinuityJobStatus.parse(map['status'] as String?),
      frequency: ContinuityFrequency.values.firstWhere(
        (f) => f.name == map['frequency'],
        orElse: () => ContinuityFrequency.manual,
      ),
      createdByEmail: (map['createdByEmail'] as String?) ?? '',
      createdByUid: (map['createdByUid'] as String?) ?? '',
      version: (map['version'] as String?) ?? '',
      estimatedSizeLabel: (map['estimatedSizeLabel'] as String?) ?? '—',
      durationLabel: (map['durationLabel'] as String?) ?? '—',
      collections: cols,
      integrityOk: map['integrityOk'] == true,
      note: (map['note'] as String?) ?? '',
      createdAt: _ts(map['createdAt']),
    );
  }
}

class ManagedContinuityRestore {
  const ManagedContinuityRestore({
    required this.id,
    required this.backupId,
    required this.scope,
    this.status = ContinuityJobStatus.awaitingConfirmation,
    this.environment = 'production',
    this.requestedByEmail = '',
    this.reason = '',
    this.validationNotes = const [],
    this.previewOnly = true,
    this.createdAt,
  });

  final String id;
  final String backupId;
  final ContinuityRestoreScope scope;
  final ContinuityJobStatus status;
  final String environment;
  final String requestedByEmail;
  final String reason;
  final List<String> validationNotes;
  final bool previewOnly;
  final DateTime? createdAt;

  factory ManagedContinuityRestore.fromMap(String id, Map<String, dynamic> map) {
    final notes = <String>[];
    final raw = map['validationNotes'];
    if (raw is List) notes.addAll(raw.map((e) => e.toString()));
    return ManagedContinuityRestore(
      id: id,
      backupId: (map['backupId'] as String?) ?? '',
      scope: ContinuityRestoreScope.parse(map['scope'] as String?),
      status: ContinuityJobStatus.parse(map['status'] as String?),
      environment: (map['environment'] as String?) ?? 'production',
      requestedByEmail: (map['requestedByEmail'] as String?) ?? '',
      reason: (map['reason'] as String?) ?? '',
      validationNotes: notes,
      previewOnly: map['previewOnly'] != false,
      createdAt: _ts(map['createdAt']),
    );
  }
}

class ManagedRecoveryPlan {
  const ManagedRecoveryPlan({
    required this.id,
    required this.kind,
    required this.title,
    this.summary = '',
    this.steps = const [],
    this.responsibleRoles = const ['Super Admin'],
    this.estimatedRecoveryTime = 'TBD',
    this.updatedAt,
  });

  final String id;
  final ContinuityPlanKind kind;
  final String title;
  final String summary;
  final List<String> steps;
  final List<String> responsibleRoles;
  final String estimatedRecoveryTime;
  final DateTime? updatedAt;

  factory ManagedRecoveryPlan.fromMap(String id, Map<String, dynamic> map) {
    List<String> lines(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return ManagedRecoveryPlan(
      id: id,
      kind: ContinuityPlanKind.parse(map['kind'] as String?),
      title: (map['title'] as String?) ?? 'Recovery plan',
      summary: (map['summary'] as String?) ?? '',
      steps: lines(map['steps']),
      responsibleRoles: lines(map['responsibleRoles']).isEmpty
          ? const ['Super Admin']
          : lines(map['responsibleRoles']),
      estimatedRecoveryTime:
          (map['estimatedRecoveryTime'] as String?) ?? 'TBD',
      updatedAt: _ts(map['updatedAt']),
    );
  }
}

class ManagedContinuityMigration {
  const ManagedContinuityMigration({
    required this.id,
    required this.kind,
    this.title = '',
    this.status = ContinuityJobStatus.planned,
    this.dryRun = true,
    this.rollbackPlan = '',
    this.createdByEmail = '',
    this.createdAt,
  });

  final String id;
  final ContinuityMigrationKind kind;
  final String title;
  final ContinuityJobStatus status;
  final bool dryRun;
  final String rollbackPlan;
  final String createdByEmail;
  final DateTime? createdAt;

  factory ManagedContinuityMigration.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return ManagedContinuityMigration(
      id: id,
      kind: ContinuityMigrationKind.parse(map['kind'] as String?),
      title: (map['title'] as String?) ?? '',
      status: ContinuityJobStatus.parse(map['status'] as String?),
      dryRun: map['dryRun'] != false,
      rollbackPlan: (map['rollbackPlan'] as String?) ?? '',
      createdByEmail: (map['createdByEmail'] as String?) ?? '',
      createdAt: _ts(map['createdAt']),
    );
  }
}

class ContinuityHealthCheck {
  const ContinuityHealthCheck({
    required this.id,
    required this.label,
    this.status = ContinuityHealthStatus.unknown,
    this.note = '',
  });

  final String id;
  final String label;
  final ContinuityHealthStatus status;
  final String note;
}

class ContinuityTimelineEvent {
  const ContinuityTimelineEvent({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.environment = '',
    this.createdAt,
  });

  final String id;
  final ContinuityTimelineKind kind;
  final String title;
  final String subtitle;
  final String environment;
  final DateTime? createdAt;

  factory ContinuityTimelineEvent.fromMap(String id, Map<String, dynamic> map) {
    return ContinuityTimelineEvent(
      id: id,
      kind: ContinuityTimelineKind.parse(map['kind'] as String?),
      title: (map['title'] as String?) ?? '',
      subtitle: (map['subtitle'] as String?) ?? '',
      environment: (map['environment'] as String?) ?? '',
      createdAt: _ts(map['createdAt']),
    );
  }
}

class ContinuityPlatformSettings {
  const ContinuityPlatformSettings({
    this.activeEnvironment = 'production',
    this.requireTypedConfirm = true,
    this.backupBeforeDeployReminder = true,
    this.recoveryScoreTarget = 80,
  });

  final String activeEnvironment;
  final bool requireTypedConfirm;
  final bool backupBeforeDeployReminder;
  final int recoveryScoreTarget;

  factory ContinuityPlatformSettings.fromMap(Map<String, dynamic> map) {
    return ContinuityPlatformSettings(
      activeEnvironment: (map['activeEnvironment'] as String?) ?? 'production',
      requireTypedConfirm: map['requireTypedConfirm'] != false,
      backupBeforeDeployReminder: map['backupBeforeDeployReminder'] != false,
      recoveryScoreTarget: (map['recoveryScoreTarget'] as num?)?.toInt() ?? 80,
    );
  }
}
