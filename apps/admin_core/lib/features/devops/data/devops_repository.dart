import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/admin_collections.dart';
import '../../../core/logging/admin_logger.dart';
import '../../../models/admin_user.dart';
import '../models/devops_enums.dart';
import '../models/devops_filters.dart';
import '../models/managed_devops.dart';

/// DevOps & Release Center — metadata only.
///
/// Never triggers Firebase Hosting deploys, Cloud Build, or GitHub Actions.
/// Never stores or returns secrets, API keys, OAuth tokens, or service accounts.
class DevOpsRepository {
  DevOpsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _releases =>
      _db.collection(AdminCollections.adminDevopsReleases);
  CollectionReference<Map<String, dynamic>> get _deployments =>
      _db.collection(AdminCollections.adminDevopsDeployments);
  CollectionReference<Map<String, dynamic>> get _builds =>
      _db.collection(AdminCollections.adminDevopsBuilds);
  CollectionReference<Map<String, dynamic>> get _rollouts =>
      _db.collection(AdminCollections.adminDevopsRollouts);
  CollectionReference<Map<String, dynamic>> get _rollbacks =>
      _db.collection(AdminCollections.adminDevopsRollbacks);
  CollectionReference<Map<String, dynamic>> get _domains =>
      _db.collection(AdminCollections.adminDevopsDomains);
  CollectionReference<Map<String, dynamic>> get _envVars =>
      _db.collection(AdminCollections.adminDevopsEnvVars);
  CollectionReference<Map<String, dynamic>> get _timeline =>
      _db.collection(AdminCollections.adminDevopsTimeline);
  DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection(AdminCollections.adminDevopsSettings).doc('global');
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  Future<DevOpsPlatformSettings> fetchSettings() async {
    try {
      final snap = await _settings.get();
      if (snap.exists && snap.data() != null) {
        return DevOpsPlatformSettings.fromMap(snap.data()!);
      }
    } catch (e) {
      AdminLogger.debug('devops settings read failed', module: 'devops', error: e);
    }
    return const DevOpsPlatformSettings();
  }

  Future<void> saveSettings({
    required AdminUser actor,
    required DevOpsPlatformSettings settings,
    List<QualityGateItem>? qualityGates,
  }) async {
    final gates = qualityGates ?? settings.qualityGates;
    await _settings.set({
      'activeEnvironment': settings.activeEnvironment.wireValue,
      'currentVersion': settings.currentVersion,
      'latestVersion': settings.latestVersion,
      'firebaseProjectId': settings.firebaseProjectId,
      'hostingNote': settings.hostingNote,
      'qualityGates': [
        for (final g in gates)
          {
            'id': g.id,
            'label': g.label,
            'passed': g.passed,
            'note': g.note,
          },
      ],
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor.uid,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: 'devops.environment_updated',
      actor: actor,
      targetUid: 'settings',
      reason: 'Platform DevOps settings updated',
    );
    await _appendTimeline(
      kind: DevOpsTimelineKind.environmentUpdated,
      title: 'Environment settings updated',
      environment: settings.activeEnvironment,
      actor: actor,
    );
  }

  Future<DevOpsSummary> fetchSummary() async {
    final settings = await fetchSettings();
    final releases = await fetchReleases(limit: 40);
    final builds = await fetchBuilds(limit: 20);
    final deployments = await fetchDeployments(limit: 20);
    final rollouts = await fetchRollouts(limit: 20);

    final open = releases
        .where(
          (r) =>
              r.status == DevOpsReleaseStatus.draft ||
              r.status == DevOpsReleaseStatus.scheduled,
        )
        .length;
    final failed = builds.where((b) => b.status == DevOpsBuildStatus.failed).length;
    final active = rollouts
        .where((r) => r.status == DevOpsRolloutStatus.active)
        .length;

    ManagedDeploymentLog? last;
    if (deployments.isNotEmpty) last = deployments.first;

    return DevOpsSummary(
      currentEnvironment: settings.activeEnvironment,
      currentVersion: settings.currentVersion,
      latestVersion: settings.latestVersion,
      lastDeploymentLabel: last?.label ?? '—',
      deploymentStatus: last?.status ?? DevOpsDeployStatus.queued,
      deploymentDurationLabel: last?.durationLabel ?? '—',
      environmentHealth: 'Monitor only',
      firebaseProject: settings.firebaseProjectId,
      hostingStatus: settings.hostingNote,
      domainStatus: 'Monitor only',
      openReleases: open,
      failedBuilds: failed,
      activeRollouts: active,
    );
  }

  Future<List<ManagedRelease>> fetchReleases({
    DevOpsFilters filters = DevOpsFilters.empty,
    int limit = 50,
  }) async {
    try {
      final snap =
          await _releases.orderBy('createdAt', descending: true).limit(80).get();
      var list = snap.docs
          .map((d) => ManagedRelease.fromMap(d.id, d.data()))
          .toList();
      list = _filterReleases(list, filters);
      return list.take(limit).toList();
    } catch (e) {
      AdminLogger.debug('fetchReleases failed', module: 'devops', error: e);
      return const [];
    }
  }

  List<ManagedRelease> _filterReleases(
    List<ManagedRelease> list,
    DevOpsFilters filters,
  ) {
    var out = list;
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out
          .where(
            (r) =>
                r.version.toLowerCase().contains(q) ||
                r.title.toLowerCase().contains(q) ||
                r.summary.toLowerCase().contains(q),
          )
          .toList();
    }
    if (filters.environment != null) {
      out = out.where((r) => r.environment == filters.environment).toList();
    }
    if (filters.releaseType != null) {
      out = out.where((r) => r.releaseType == filters.releaseType).toList();
    }
    if (filters.status != null) {
      out = out.where((r) => r.status.wireValue == filters.status).toList();
    }
    if (filters.version != null && filters.version!.isNotEmpty) {
      out = out.where((r) => r.version.contains(filters.version!)).toList();
    }
    if (filters.from != null) {
      out = out
          .where(
            (r) =>
                r.createdAt == null || !r.createdAt!.isBefore(filters.from!),
          )
          .toList();
    }
    if (filters.to != null) {
      out = out
          .where(
            (r) => r.createdAt == null || !r.createdAt!.isAfter(filters.to!),
          )
          .toList();
    }
    return out;
  }

  Future<String> createRelease({
    required AdminUser actor,
    required ManagedRelease draft,
  }) async {
    final ref = _releases.doc();
    await ref.set(
      draft.toCreateMap(authorUid: actor.uid, authorEmail: actor.email),
    );
    await _writeAudit(
      action: 'devops.release_created',
      actor: actor,
      targetUid: ref.id,
      targetEmail: draft.version,
      reason: draft.title,
    );
    await _appendTimeline(
      kind: DevOpsTimelineKind.versionCreated,
      title: 'Release ${draft.version} created',
      environment: draft.environment,
      actor: actor,
      detail: draft.title,
    );
    return ref.id;
  }

  Future<void> updateReleaseStatus({
    required AdminUser actor,
    required ManagedRelease release,
    required DevOpsReleaseStatus status,
  }) async {
    final patch = <String, dynamic>{
      'status': status.wireValue,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == DevOpsReleaseStatus.published) {
      patch['publishedAt'] = FieldValue.serverTimestamp();
    }
    await _releases.doc(release.id).set(patch, SetOptions(merge: true));
    final action = switch (status) {
      DevOpsReleaseStatus.published => 'devops.release_published',
      DevOpsReleaseStatus.cancelled => 'devops.release_cancelled',
      DevOpsReleaseStatus.archived => 'devops.release_archived',
      DevOpsReleaseStatus.scheduled => 'devops.release_scheduled',
      _ => 'devops.release_updated',
    };
    await _writeAudit(
      action: action,
      actor: actor,
      targetUid: release.id,
      targetEmail: release.version,
    );
    if (status == DevOpsReleaseStatus.published) {
      await _appendTimeline(
        kind: DevOpsTimelineKind.releasePublished,
        title: 'Release ${release.version} published',
        environment: release.environment,
        actor: actor,
      );
    }
  }

  Future<String> duplicateRelease({
    required AdminUser actor,
    required ManagedRelease source,
  }) async {
    final copy = ManagedRelease(
      id: '',
      version: '${source.version}-copy',
      title: '${source.title} (copy)',
      summary: source.summary,
      newFeatures: source.newFeatures,
      bugFixes: source.bugFixes,
      breakingChanges: source.breakingChanges,
      knownIssues: source.knownIssues,
      releaseType: source.releaseType,
      status: DevOpsReleaseStatus.draft,
      environment: source.environment,
      buildNumber: source.buildNumber,
    );
    return createRelease(actor: actor, draft: copy);
  }

  Future<List<ManagedDeploymentLog>> fetchDeployments({
    DevOpsFilters filters = DevOpsFilters.empty,
    int limit = 40,
  }) async {
    try {
      final snap = await _deployments
          .orderBy('startedAt', descending: true)
          .limit(60)
          .get();
      var list = snap.docs
          .map((d) => ManagedDeploymentLog.fromMap(d.id, d.data()))
          .toList();
      if (filters.environment != null) {
        list = list.where((d) => d.environment == filters.environment).toList();
      }
      if (filters.status != null) {
        list = list.where((d) => d.status.wireValue == filters.status).toList();
      }
      final q = filters.query.trim().toLowerCase();
      if (q.isNotEmpty) {
        list = list
            .where(
              (d) =>
                  d.label.toLowerCase().contains(q) ||
                  d.version.toLowerCase().contains(q),
            )
            .toList();
      }
      return list.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ManagedBuild>> fetchBuilds({int limit = 30}) async {
    try {
      final snap =
          await _builds.orderBy('startedAt', descending: true).limit(limit).get();
      return snap.docs
          .map((d) => ManagedBuild.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ManagedRollout>> fetchRollouts({int limit = 40}) async {
    try {
      final snap = await _rollouts.limit(limit).get();
      return snap.docs
          .map((d) => ManagedRollout.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String> saveRollout({
    required AdminUser actor,
    required ManagedRollout rollout,
  }) async {
    final ref = rollout.id.isEmpty ? _rollouts.doc() : _rollouts.doc(rollout.id);
    await ref.set({
      ...rollout.toMap(),
      if (rollout.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _writeAudit(
      action: 'devops.feature_rollout',
      actor: actor,
      targetUid: ref.id,
      targetEmail: rollout.featureKey,
      reason: '${rollout.percent.label} · ${rollout.status.label}',
    );
    await _appendTimeline(
      kind: DevOpsTimelineKind.featureEnabled,
      title: 'Rollout ${rollout.title} → ${rollout.percent.label}',
      environment: rollout.environment,
      actor: actor,
    );
    return ref.id;
  }

  Future<List<ManagedRollbackPlan>> fetchRollbacks({int limit = 30}) async {
    try {
      final snap = await _rollbacks
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => ManagedRollbackPlan.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Architecture only — records intent; never executes a production rollback.
  Future<String> prepareRollback({
    required AdminUser actor,
    required String targetVersion,
    required String fromVersion,
    required String reason,
    required DevOpsEnvironment environment,
  }) async {
    final ref = _rollbacks.doc();
    await ref.set({
      'targetVersion': targetVersion,
      'fromVersion': fromVersion,
      'reason': reason,
      'status': 'prepared',
      'environment': environment.wireValue,
      'createdBy': actor.email,
      'createdAt': FieldValue.serverTimestamp(),
      'note': 'Architecture only — no automatic rollback executed',
    });
    await _writeAudit(
      action: 'devops.rollback_prepared',
      actor: actor,
      targetUid: ref.id,
      targetEmail: targetVersion,
      reason: reason,
    );
    await _appendTimeline(
      kind: DevOpsTimelineKind.rollback,
      title: 'Rollback prepared → $targetVersion',
      environment: environment,
      actor: actor,
      detail: reason,
    );
    return ref.id;
  }

  Future<List<ManagedDomain>> fetchDomains() async {
    try {
      final snap = await _domains.limit(20).get();
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => ManagedDomain.fromMap(d.id, d.data()))
            .toList();
      }
    } catch (_) {}
    // Seed defaults as view models only (not written unless Super Admin saves).
    return const [
      ManagedDomain(
        id: 'admin',
        host: 'admin.crickflow.app',
        status: DevOpsDomainStatus.unknown,
        ssl: 'Monitor only',
        dns: 'Monitor only',
        note: 'Organization Admin Hosting target',
      ),
      ManagedDomain(
        id: 'superadmin',
        host: 'superadmin.crickflow.app',
        status: DevOpsDomainStatus.unknown,
        ssl: 'Monitor only',
        dns: 'Monitor only',
        note: 'Super Admin Hosting target',
      ),
    ];
  }

  Future<List<ManagedEnvVar>> fetchEnvVars({
    DevOpsEnvironment? environment,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _envVars;
      if (environment != null) {
        q = q.where('environment', isEqualTo: environment.wireValue);
      }
      final snap = await q.limit(80).get();
      return snap.docs
          .map((d) => ManagedEnvVar.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Registers env var *keys* only — never stores secret values.
  Future<void> upsertEnvVarMeta({
    required AdminUser actor,
    required String key,
    required DevOpsEnvironment environment,
    required bool configured,
    bool sensitive = true,
  }) async {
    final id = '${environment.wireValue}__$key';
    await _envVars.doc(id).set({
      'key': key,
      'environment': environment.wireValue,
      'configured': configured,
      'sensitive': sensitive,
      'validation': configured ? 'Configured' : 'Missing',
      // Never write raw secrets.
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor.uid,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: 'devops.env_var_meta_updated',
      actor: actor,
      targetUid: id,
      targetEmail: key,
      reason: 'Metadata only — value not stored',
    );
  }

  Future<List<ManagedTimelineEvent>> fetchTimeline({int limit = 40}) async {
    try {
      final snap =
          await _timeline.orderBy('at', descending: true).limit(limit).get();
      return snap.docs
          .map((d) => ManagedTimelineEvent.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> ensureDefaultDomains(AdminUser actor) async {
    final existing = await _domains.limit(1).get();
    if (existing.docs.isNotEmpty) return;
    for (final d in await fetchDomains()) {
      await _domains.doc(d.id).set({
        'host': d.host,
        'status': d.status.wireValue,
        'ssl': d.ssl,
        'dns': d.dns,
        'note': d.note,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await _writeAudit(
      action: 'devops.domains_seeded',
      actor: actor,
      targetUid: 'domains',
      reason: 'Default domain monitor entries',
    );
  }

  Future<void> _appendTimeline({
    required DevOpsTimelineKind kind,
    required String title,
    required DevOpsEnvironment environment,
    required AdminUser actor,
    String detail = '',
  }) async {
    try {
      await _timeline.add({
        'kind': kind.wireValue,
        'title': title,
        'environment': environment.wireValue,
        'detail': detail,
        'actorEmail': actor.email,
        'actorUid': actor.uid,
        'at': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AdminLogger.debug('timeline append failed', module: 'devops', error: e);
    }
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    required String targetUid,
    String? targetEmail,
    String? reason,
  }) async {
    try {
      await _audit.add({
        'action': action,
        'actorUid': actor.uid,
        'actorEmail': actor.email,
        'targetUid': targetUid,
        'targetEmail': targetEmail ?? '',
        'reason': reason ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'module': 'devops',
      });
    } catch (e) {
      AdminLogger.warning('audit write failed', module: 'devops', error: e);
    }
  }
}
