import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_env_config.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../core/logging/admin_logger.dart';
import '../../../models/admin_user.dart';
import '../models/continuity_enums.dart';
import '../models/continuity_filters.dart';
import '../models/managed_continuity.dart';

/// Business Continuity Center — metadata & workflows only.
///
/// Never triggers real Firebase export/import, never overwrites production data,
/// never stores secrets. Restores stay preview / awaitingConfirmation until a
/// future approved Cloud Function + typed Super Admin confirmation.
class ContinuityRepository {
  ContinuityRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _backups =>
      _db.collection(AdminCollections.adminContinuityBackups);
  CollectionReference<Map<String, dynamic>> get _restores =>
      _db.collection(AdminCollections.adminContinuityRestores);
  CollectionReference<Map<String, dynamic>> get _migrations =>
      _db.collection(AdminCollections.adminContinuityMigrations);
  CollectionReference<Map<String, dynamic>> get _plans =>
      _db.collection(AdminCollections.adminContinuityPlans);
  CollectionReference<Map<String, dynamic>> get _timeline =>
      _db.collection(AdminCollections.adminContinuityTimeline);
  DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection(AdminCollections.adminContinuitySettings).doc('global');
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<ContinuityPlatformSettings> fetchSettings() async {
    try {
      final snap = await _settings.get();
      if (snap.exists && snap.data() != null) {
        return ContinuityPlatformSettings.fromMap(snap.data()!);
      }
    } catch (e) {
      AdminLogger.debug('continuity settings read failed',
          module: 'continuity', error: e);
    }
    return const ContinuityPlatformSettings();
  }

  Future<ContinuitySummary> fetchSummary() async {
    final backups = await fetchBackups(limit: 40);
    final restores = await fetchRestores(limit: 20);
    final migrations = await fetchMigrations(limit: 20);

    ManagedContinuityBackup? latest;
    ManagedContinuityBackup? lastOk;
    ManagedContinuityBackup? lastFail;
    if (backups.isNotEmpty) latest = backups.first;
    for (final b in backups) {
      if (b.status == ContinuityJobStatus.success && lastOk == null) {
        lastOk = b;
      }
      if (b.status == ContinuityJobStatus.failed && lastFail == null) {
        lastFail = b;
      }
    }

    final score = _computeReadinessScore(backups, restores);

    return ContinuitySummary(
      latestBackupLabel: latest == null
          ? 'None yet'
          : '${latest.type.label} · ${latest.status.label}',
      lastSuccessLabel: lastOk?.id ?? '—',
      lastFailedLabel: lastFail?.id ?? '—',
      firestoreStatus: _statusForType(backups, ContinuityBackupType.firestore),
      storageStatus: _statusForType(backups, ContinuityBackupType.storage),
      configStatus: _statusForType(
        backups,
        ContinuityBackupType.platformSettings,
      ),
      estimatedSizeLabel: latest?.estimatedSizeLabel ?? '—',
      recoveryReadiness: score >= 70
          ? 'Ready (metadata)'
          : score >= 40
              ? 'Partial'
              : 'Needs backups',
      recoveryScore: score,
      environment: AdminEnvConfig.environment.label,
      openRestores: restores
          .where((r) =>
              r.status == ContinuityJobStatus.awaitingConfirmation ||
              r.status == ContinuityJobStatus.validating)
          .length,
      openMigrations: migrations
          .where((m) =>
              m.status == ContinuityJobStatus.planned ||
              m.status == ContinuityJobStatus.queued)
          .length,
    );
  }

  String _statusForType(
    List<ManagedContinuityBackup> backups,
    ContinuityBackupType type,
  ) {
    for (final b in backups) {
      if (b.type == type) return b.status.label;
    }
    return 'No metadata';
  }

  int _computeReadinessScore(
    List<ManagedContinuityBackup> backups,
    List<ManagedContinuityRestore> restores,
  ) {
    var score = 20;
    if (backups.any((b) => b.status == ContinuityJobStatus.success)) {
      score += 35;
    }
    if (backups.any((b) => b.integrityOk)) score += 20;
    if (backups.length >= 3) score += 15;
    if (restores.every((r) => r.previewOnly)) score += 10;
    return score.clamp(0, 100);
  }

  Future<List<ManagedContinuityBackup>> fetchBackups({
    ContinuityFilters filters = ContinuityFilters.empty,
    int limit = 50,
  }) async {
    try {
      final snap =
          await _backups.orderBy('createdAt', descending: true).limit(limit).get();
      var items = snap.docs
          .map((d) => ManagedContinuityBackup.fromMap(d.id, d.data()))
          .toList();
      return _filterBackups(items, filters);
    } catch (e) {
      AdminLogger.debug('continuity backups fetch failed',
          module: 'continuity', error: e);
      return const [];
    }
  }

  List<ManagedContinuityBackup> _filterBackups(
    List<ManagedContinuityBackup> items,
    ContinuityFilters filters,
  ) {
    var out = items;
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out
          .where((b) =>
              b.id.toLowerCase().contains(q) ||
              b.type.label.toLowerCase().contains(q) ||
              b.createdByEmail.toLowerCase().contains(q) ||
              b.note.toLowerCase().contains(q))
          .toList();
    }
    if (filters.environment != null && filters.environment!.isNotEmpty) {
      out = out.where((b) => b.environment == filters.environment).toList();
    }
    if (filters.status != null) {
      out = out.where((b) => b.status == filters.status).toList();
    }
    if (filters.backupType != null) {
      out = out.where((b) => b.type == filters.backupType).toList();
    }
    if (filters.createdBy != null && filters.createdBy!.isNotEmpty) {
      final c = filters.createdBy!.toLowerCase();
      out = out.where((b) => b.createdByEmail.toLowerCase().contains(c)).toList();
    }
    return out;
  }

  /// Queues backup **metadata** only — does not export Firestore/Storage.
  Future<String> queueBackup({
    required AdminUser actor,
    required ContinuityBackupType type,
    ContinuityFrequency frequency = ContinuityFrequency.manual,
    String environment = 'production',
    List<String> collections = const [],
    String? reason,
  }) async {
    final ref = _backups.doc();
    await ref.set({
      'type': type.wireValue,
      'status': ContinuityJobStatus.queued.wireValue,
      'frequency': frequency.wireValue,
      'environment': environment,
      'createdByEmail': actor.email,
      'createdByUid': actor.uid,
      'version': AdminEnvConfig.versionLabel,
      'estimatedSizeLabel': 'Pending worker',
      'durationLabel': '—',
      'collections': collections,
      'integrityOk': false,
      'note':
          'Metadata queued for future Cloud Backup / export worker. No data copied.',
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _writeAudit(
      action: 'continuity.backup_created',
      actor: actor,
      targetUid: ref.id,
      reason: reason ?? 'Backup metadata queued (${type.label})',
    );
    await _appendTimeline(
      kind: ContinuityTimelineKind.backupCreated,
      title: 'Backup queued: ${type.label}',
      subtitle: ref.id,
      environment: environment,
      actor: actor,
    );
    return ref.id;
  }

  Future<void> markBackupValidated({
    required AdminUser actor,
    required ManagedContinuityBackup backup,
    required bool integrityOk,
    String? note,
  }) async {
    await _backups.doc(backup.id).set({
      'integrityOk': integrityOk,
      'status': integrityOk
          ? ContinuityJobStatus.success.wireValue
          : ContinuityJobStatus.failed.wireValue,
      'note': ?note,
      'validatedAt': FieldValue.serverTimestamp(),
      'validatedBy': actor.uid,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: 'continuity.backup_validated',
      actor: actor,
      targetUid: backup.id,
      reason: integrityOk ? 'Integrity OK' : 'Integrity failed',
    );
    await _appendTimeline(
      kind: ContinuityTimelineKind.backupValidated,
      title: 'Backup validated: ${backup.id}',
      subtitle: integrityOk ? 'Integrity OK' : 'Failed checks',
      environment: backup.environment,
      actor: actor,
    );
  }

  /// Soft-delete flag only — rules may disallow hard delete.
  Future<void> archiveBackup({
    required AdminUser actor,
    required ManagedContinuityBackup backup,
    String? reason,
  }) async {
    await _backups.doc(backup.id).set({
      'status': ContinuityJobStatus.cancelled.wireValue,
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': actor.uid,
      'archiveReason': reason,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: 'continuity.backup_deleted',
      actor: actor,
      targetUid: backup.id,
      reason: reason ?? 'Backup archived (metadata)',
    );
    await _appendTimeline(
      kind: ContinuityTimelineKind.backupDeleted,
      title: 'Backup archived: ${backup.id}',
      environment: backup.environment,
      actor: actor,
    );
  }

  Future<List<ManagedContinuityRestore>> fetchRestores({int limit = 40}) async {
    try {
      final snap = await _restores
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => ManagedContinuityRestore.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Creates a **preview** restore request — never mutates production data.
  Future<String> requestRestorePreview({
    required AdminUser actor,
    required String backupId,
    required ContinuityRestoreScope scope,
    required String reason,
    String environment = 'production',
  }) async {
    final validation = <String>[
      'Backup integrity must be verified before any future apply',
      'Version compatibility check — architecture ready',
      'Collection mapping — architecture ready',
      'This request is PREVIEW ONLY — no automatic restore',
    ];
    final ref = _restores.doc();
    await ref.set({
      'backupId': backupId,
      'scope': scope.wireValue,
      'status': ContinuityJobStatus.awaitingConfirmation.wireValue,
      'environment': environment,
      'requestedByEmail': actor.email,
      'requestedByUid': actor.uid,
      'reason': reason,
      'validationNotes': validation,
      'previewOnly': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _writeAudit(
      action: 'continuity.restore_requested',
      actor: actor,
      targetUid: ref.id,
      reason: reason,
    );
    await _appendTimeline(
      kind: ContinuityTimelineKind.restoreRequested,
      title: 'Restore preview: ${scope.label}',
      subtitle: 'backup=$backupId',
      environment: environment,
      actor: actor,
    );
    return ref.id;
  }

  Future<List<ManagedRecoveryPlan>> fetchPlans() async {
    try {
      final snap = await _plans.limit(40).get();
      if (snap.docs.isEmpty) return defaultRecoveryPlans();
      return snap.docs
          .map((d) => ManagedRecoveryPlan.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return defaultRecoveryPlans();
    }
  }

  List<ManagedRecoveryPlan> defaultRecoveryPlans() => [
        for (final kind in ContinuityPlanKind.values)
          ManagedRecoveryPlan(
            id: 'plan_${kind.wireValue}',
            kind: kind,
            title: kind.label,
            summary:
                'Documented runbook — no automated recovery. Follow steps with Super Admin approval.',
            estimatedRecoveryTime: 'Variable',
            steps: [
              'Confirm incident scope and environment',
              'Identify latest validated backup metadata',
              'Run restore preview + validation checklist',
              'Obtain explicit Super Admin typed confirmation',
              'Execute approved Cloud worker (future) — never from this client',
              'Verify health checks and audit trail',
            ],
            responsibleRoles: const ['Super Admin', 'On-call'],
          ),
      ];

  Future<void> upsertPlan({
    required AdminUser actor,
    required ManagedRecoveryPlan plan,
  }) async {
    await _plans.doc(plan.id).set({
      'kind': plan.kind.wireValue,
      'title': plan.title,
      'summary': plan.summary,
      'steps': plan.steps,
      'responsibleRoles': plan.responsibleRoles,
      'estimatedRecoveryTime': plan.estimatedRecoveryTime,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor.uid,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: 'continuity.plan_updated',
      actor: actor,
      targetUid: plan.id,
      reason: plan.title,
    );
    await _appendTimeline(
      kind: ContinuityTimelineKind.planUpdated,
      title: 'Recovery plan updated: ${plan.title}',
      actor: actor,
    );
  }

  Future<List<ManagedContinuityMigration>> fetchMigrations({
    int limit = 40,
  }) async {
    try {
      final snap = await _migrations
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => ManagedContinuityMigration.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Dry-run migration metadata — never mutates collections.
  Future<String> queueMigrationDryRun({
    required AdminUser actor,
    required ContinuityMigrationKind kind,
    required String title,
    String rollbackPlan = 'Revert via previous config backup metadata',
  }) async {
    final ref = _migrations.doc();
    await ref.set({
      'kind': kind.wireValue,
      'title': title,
      'status': ContinuityJobStatus.planned.wireValue,
      'dryRun': true,
      'rollbackPlan': rollbackPlan,
      'createdByEmail': actor.email,
      'createdByUid': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _writeAudit(
      action: 'continuity.migration_started',
      actor: actor,
      targetUid: ref.id,
      reason: 'Dry-run only: $title',
    );
    await _appendTimeline(
      kind: ContinuityTimelineKind.migrationStarted,
      title: 'Migration dry-run: $title',
      actor: actor,
    );
    return ref.id;
  }

  List<ContinuityHealthCheck> healthChecks() => const [
        ContinuityHealthCheck(
          id: 'firestore',
          label: 'Firestore',
          status: ContinuityHealthStatus.unknown,
          note: 'Verify console + admin list loads',
        ),
        ContinuityHealthCheck(
          id: 'storage',
          label: 'Storage',
          status: ContinuityHealthStatus.unknown,
          note: 'Rules + bucket availability',
        ),
        ContinuityHealthCheck(
          id: 'hosting',
          label: 'Hosting',
          status: ContinuityHealthStatus.unknown,
          note: 'admin / superadmin domains + SSL',
        ),
        ContinuityHealthCheck(
          id: 'auth',
          label: 'Authentication',
          status: ContinuityHealthStatus.unknown,
          note: 'Authorized domains + providers',
        ),
        ContinuityHealthCheck(
          id: 'functions',
          label: 'Cloud Functions',
          status: ContinuityHealthStatus.unknown,
          note: 'Health only — no deploy from Continuity',
        ),
        ContinuityHealthCheck(
          id: 'remote_config',
          label: 'Remote Config',
          status: ContinuityHealthStatus.unknown,
          note: 'Mirror keys / settings',
        ),
        ContinuityHealthCheck(
          id: 'permissions',
          label: 'Permissions',
          status: ContinuityHealthStatus.unknown,
          note: 'admin_roles seeded',
        ),
        ContinuityHealthCheck(
          id: 'configuration',
          label: 'Configuration',
          status: ContinuityHealthStatus.unknown,
          note: 'Platform settings singleton',
        ),
      ];

  Future<void> recordHealthCheck({required AdminUser actor}) async {
    await _writeAudit(
      action: 'continuity.validation_performed',
      actor: actor,
      targetUid: 'health',
      reason: 'Health verification checklist opened',
    );
    await _appendTimeline(
      kind: ContinuityTimelineKind.healthChecked,
      title: 'Health verification recorded',
      actor: actor,
    );
  }

  Future<List<ContinuityTimelineEvent>> fetchTimeline({int limit = 50}) async {
    try {
      final snap = await _timeline
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => ContinuityTimelineEvent.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _appendTimeline({
    required ContinuityTimelineKind kind,
    required String title,
    String subtitle = '',
    String environment = '',
    required AdminUser actor,
  }) async {
    await _timeline.add({
      'kind': kind.wireValue,
      'title': title,
      'subtitle': subtitle,
      'environment': environment,
      'actorUid': actor.uid,
      'actorEmail': actor.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required String targetUid,
    String? reason,
  }) async {
    await _audit.add({
      'action': action,
      'actorUid': actor.uid,
      'actorEmail': actor.email,
      'targetUid': targetUid,
      'timestamp': FieldValue.serverTimestamp(),
      'reason': ?reason,
      'module': 'continuity',
      'organizationId': ?actor.organizationId,
    });
  }
}
