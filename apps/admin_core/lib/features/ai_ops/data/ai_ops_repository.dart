import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/ai_ops_enums.dart';
import '../models/ai_ops_filters.dart';
import '../models/managed_ai_ops.dart';
import 'ai_provider_adapter.dart';

/// AI Operations data access — additive collections only.
///
/// Recommendations never auto-mutate user/mobile data. Admins must approve.
/// External AI providers plug in via [AiProviderAdapter] + Cloud Functions later.
/// Do not continuously scan Firestore — jobs are scheduled/batched.
class AiOpsRepository {
  AiOpsRepository({
    FirebaseFirestore? firestore,
    AiProviderAdapter? provider,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _provider = provider ?? RulesEngineAiAdapter();

  final FirebaseFirestore _db;
  AiProviderAdapter _provider;

  static const _pageSize = 25;

  CollectionReference<Map<String, dynamic>> get _recs =>
      _db.collection(AdminCollections.adminAiRecommendations);
  CollectionReference<Map<String, dynamic>> get _rules =>
      _db.collection(AdminCollections.adminAiRules);
  CollectionReference<Map<String, dynamic>> get _jobs =>
      _db.collection(AdminCollections.adminAiJobs);
  CollectionReference<Map<String, dynamic>> get _logs =>
      _db.collection(AdminCollections.adminAiLogs);
  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _db.collection(AdminCollections.adminAiSettings).doc('global');
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  void setProvider(AiProviderAdapter adapter) => _provider = adapter;

  AiProviderAdapter get provider => _provider;

  // ---------------------------------------------------------------------------
  // Recommendations
  // ---------------------------------------------------------------------------

  Future<AiOpsPageResult> fetchRecommendations({
    required AdminAppType appType,
    required AdminUser? actor,
    required AiOpsFilters filters,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = _pageSize,
    Set<AiRecommendationCategory>? forceCategories,
  }) async {
    Query<Map<String, dynamic>> query = _recs;

    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) {
        return const AiOpsPageResult(items: [], hasMore: false);
      }
      query = query.where('organizationId', isEqualTo: orgId);
    } else if (filters.organizationId?.isNotEmpty == true) {
      query = query.where(
        'organizationId',
        isEqualTo: filters.organizationId,
      );
    }

    final cats = forceCategories ?? filters.categories;
    if (cats.length == 1) {
      query = query.where('category', isEqualTo: cats.first.wireValue);
    }
    if (filters.statuses.length == 1) {
      query = query.where(
        'status',
        isEqualTo: filters.statuses.first.wireValue,
      );
    }

    query = query.orderBy('createdAt', descending: true);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.limit(limit + 1).get();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const AiOpsPageResult(items: [], hasMore: false);
      }
      try {
        snap = await _recs.limit(limit + 1).get();
      } catch (_) {
        return const AiOpsPageResult(items: [], hasMore: false);
      }
    }

    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final page = hasMore ? docs.sublist(0, limit) : docs;
    var items =
        page.map((d) => AiRecommendation.fromMap(d.id, d.data())).toList();
    items = _filterClient(items, filters, forceCategories);

    return AiOpsPageResult(
      items: items,
      hasMore: hasMore,
      lastDoc: page.isEmpty ? null : page.last,
    );
  }

  List<AiRecommendation> _filterClient(
    List<AiRecommendation> items,
    AiOpsFilters filters,
    Set<AiRecommendationCategory>? forceCategories,
  ) {
    Iterable<AiRecommendation> out = items;
    final cats = forceCategories ?? filters.categories;
    if (cats.isNotEmpty) {
      out = out.where((r) => cats.contains(r.category));
    }
    if (filters.statuses.isNotEmpty) {
      out = out.where((r) => filters.statuses.contains(r.status));
    }
    if (filters.confidenceBands.isNotEmpty) {
      out = out.where((r) => filters.confidenceBands.contains(r.confidenceBand));
    }
    if (filters.country?.trim().isNotEmpty == true) {
      final c = filters.country!.trim().toLowerCase();
      out = out.where((r) => r.country.toLowerCase().contains(c));
    }
    if (filters.stateProvince?.trim().isNotEmpty == true) {
      final s = filters.stateProvince!.trim().toLowerCase();
      out = out.where((r) => r.stateProvince.toLowerCase().contains(s));
    }
    if (filters.from != null) {
      out = out.where(
        (r) => r.createdAt == null || !r.createdAt!.isBefore(filters.from!),
      );
    }
    if (filters.to != null) {
      out = out.where(
        (r) => r.createdAt == null || !r.createdAt!.isAfter(filters.to!),
      );
    }
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((r) {
        return r.title.toLowerCase().contains(q) ||
            r.reason.toLowerCase().contains(q) ||
            r.entityLabel.toLowerCase().contains(q) ||
            r.entityId.toLowerCase().contains(q) ||
            r.category.label.toLowerCase().contains(q) ||
            r.suggestedAction.toLowerCase().contains(q);
      });
    }
    return out.toList();
  }

  Future<AiOpsSummary> fetchSummary({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final page = await fetchRecommendations(
      appType: appType,
      actor: actor,
      filters: AiOpsFilters.empty,
      limit: 150,
    );
    final rules = await fetchRules(appType: appType, actor: actor);
    var pending = 0;
    var spam = 0;
    var dupUser = 0;
    var dupTeam = 0;
    var dupGround = 0;
    var fraud = 0;
    var resolved = 0;
    for (final r in page.items) {
      if (r.status == AiRecommendationStatus.pending) pending++;
      if (r.status == AiRecommendationStatus.accepted ||
          r.status == AiRecommendationStatus.executed ||
          r.status == AiRecommendationStatus.rejected) {
        resolved++;
      }
      if (r.category == AiRecommendationCategory.spam) spam++;
      if (r.category == AiRecommendationCategory.fraud) fraud++;
      if (r.category == AiRecommendationCategory.duplicate) {
        switch (r.entityType) {
          case AiEntityType.user:
            dupUser++;
          case AiEntityType.team:
            dupTeam++;
          case AiEntityType.ground:
            dupGround++;
          default:
            break;
        }
      }
    }
    return AiOpsSummary(
      suggestions: page.items.length,
      pendingReviews: pending,
      spamDetected: spam,
      duplicateAccounts: dupUser,
      duplicateTeams: dupTeam,
      duplicateGrounds: dupGround,
      fraudAlerts: fraud,
      automationRules: rules.where((r) => r.status == AiRuleStatus.enabled).length,
      resolvedRecommendations: resolved,
    );
  }

  Future<List<AiInsightCard>> fetchInsights({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    final orgId = appType == AdminAppType.organizationAdmin
        ? actor?.organizationId
        : null;
    return _provider.generateInsights(organizationId: orgId);
  }

  Future<void> resolveRecommendation({
    required AiRecommendation rec,
    required AdminUser actor,
    required AiRecommendationStatus status,
    DuplicateDecision? duplicateDecision,
    String? reason,
  }) async {
    // Never auto-mutate underlying user/team/ground documents here.
    // Acceptance only marks the recommendation; execution hooks come later.
    await _recs.doc(rec.id).update({
      'status': status.wireValue,
      if (duplicateDecision != null)
        'duplicateDecision': duplicateDecision.wireValue,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedByUid': actor.uid,
      'resolvedByEmail': actor.email,
      'updatedAt': FieldValue.serverTimestamp(),
      'resolveReason': ?reason,
    });

    final logAction = switch (status) {
      AiRecommendationStatus.accepted => AiLogAction.recommendationAccepted,
      AiRecommendationStatus.rejected => AiLogAction.recommendationRejected,
      AiRecommendationStatus.executed => AiLogAction.recommendationExecuted,
      AiRecommendationStatus.archived => AiLogAction.recommendationArchived,
      _ => AiLogAction.other,
    };
    await _appendLog(
      action: logAction,
      actor: actor,
      recommendation: rec.title,
      status: status,
      organizationId: rec.organizationId ?? actor.organizationId,
      detail: reason ?? '',
    );
    await _writeAudit(
      action: 'ai.recommendation_${status.wireValue}',
      actor: actor,
      targetUid: rec.id,
      targetEmail: rec.title,
      reason: reason,
      organizationId: rec.organizationId,
    );
  }

  Future<AiRecommendation> seedSampleRecommendation({
    required AdminUser actor,
    required AiRecommendationCategory category,
    required String title,
    required String reason,
    AiEntityType entityType = AiEntityType.other,
    double confidence = 0.7,
    double? similarity,
    AiReportPriority? priority,
    String suggestedAction = 'Review and decide',
  }) async {
    final draft = AiRecommendation(
      id: '',
      title: title,
      reason: reason,
      category: category,
      confidence: confidence,
      entityType: entityType,
      entityLabel: title,
      organizationId: actor.organizationId,
      similarityPercent: similarity,
      reportPriority: priority,
      suggestedAction: suggestedAction,
      provider: _provider.providerId,
    );
    final ref = await _recs.add(draft.toCreateMap());
    await _appendLog(
      action: AiLogAction.recommendationCreated,
      actor: actor,
      recommendation: title,
      status: AiRecommendationStatus.pending,
      organizationId: actor.organizationId,
    );
    final snap = await ref.get();
    return AiRecommendation.fromMap(ref.id, snap.data() ?? {});
  }

  // ---------------------------------------------------------------------------
  // Rules
  // ---------------------------------------------------------------------------

  Future<List<AiAutomationRule>> fetchRules({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> query = _rules;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      query = query.where('organizationId', isEqualTo: orgId);
    }
    try {
      final snap =
          await query.orderBy('updatedAt', descending: true).limit(100).get();
      return snap.docs
          .map((d) => AiAutomationRule.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      try {
        final snap = await _rules.limit(100).get();
        var items = snap.docs
            .map((d) => AiAutomationRule.fromMap(d.id, d.data()))
            .toList();
        if (appType == AdminAppType.organizationAdmin) {
          final orgId = actor?.organizationId;
          items = items.where((r) => r.organizationId == orgId).toList();
        }
        return items;
      } catch (_) {
        return const [];
      }
    }
  }

  Future<void> saveRule({
    required AdminUser actor,
    required AiAutomationRule rule,
  }) async {
    // Force recommend-only unless Super Admin explicitly opted into future auto.
    final safe = rule.copyWith(
      executionMode: rule.executionMode == AiRuleExecutionMode.autoExecute
          ? AiRuleExecutionMode.autoExecute
          : AiRuleExecutionMode.recommendOnly,
      organizationId: rule.organizationId ?? actor.organizationId,
    );
    final creating = safe.id.isEmpty;
    final ref = creating ? _rules.doc() : _rules.doc(safe.id);
    await ref.set(safe.toMap(creating: creating), SetOptions(merge: true));
    await _appendLog(
      action: creating ? AiLogAction.ruleCreated : AiLogAction.ruleEnabled,
      actor: actor,
      recommendation: safe.name,
      organizationId: safe.organizationId,
      detail: '${safe.trigger.label} → ${safe.action.label}',
    );
    await _writeAudit(
      action: creating ? 'ai.rule_created' : 'ai.rule_updated',
      actor: actor,
      targetUid: ref.id,
      targetEmail: safe.name,
      organizationId: safe.organizationId,
    );
  }

  Future<void> setRuleStatus({
    required AiAutomationRule rule,
    required AdminUser actor,
    required AiRuleStatus status,
  }) async {
    await _rules.doc(rule.id).update({
      'status': status.wireValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _appendLog(
      action: status == AiRuleStatus.enabled
          ? AiLogAction.ruleEnabled
          : AiLogAction.ruleDisabled,
      actor: actor,
      recommendation: rule.name,
      organizationId: rule.organizationId ?? actor.organizationId,
    );
    await _writeAudit(
      action: status == AiRuleStatus.enabled
          ? 'ai.rule_enabled'
          : 'ai.rule_disabled',
      actor: actor,
      targetUid: rule.id,
      targetEmail: rule.name,
      organizationId: rule.organizationId,
    );
  }

  Future<void> duplicateRule({
    required AiAutomationRule rule,
    required AdminUser actor,
  }) async {
    final copy = rule.copyWith(
      id: '',
      name: '${rule.name} (copy)',
      status: AiRuleStatus.draft,
    );
    await saveRule(actor: actor, rule: copy);
    await _appendLog(
      action: AiLogAction.ruleDuplicated,
      actor: actor,
      recommendation: copy.name,
      organizationId: actor.organizationId,
    );
  }

  Future<void> deleteRule({
    required AiAutomationRule rule,
    required AdminUser actor,
  }) async {
    await _rules.doc(rule.id).delete();
    await _appendLog(
      action: AiLogAction.ruleDeleted,
      actor: actor,
      recommendation: rule.name,
      organizationId: rule.organizationId ?? actor.organizationId,
    );
    await _writeAudit(
      action: 'ai.rule_deleted',
      actor: actor,
      targetUid: rule.id,
      targetEmail: rule.name,
      organizationId: rule.organizationId,
    );
  }

  Future<void> seedDefaultRulesIfEmpty({
    required AdminAppType appType,
    required AdminUser actor,
  }) async {
    final existing = await fetchRules(appType: appType, actor: actor);
    if (existing.isNotEmpty) return;
    final defaults = [
      AiAutomationRule(
        id: '',
        name: 'Flag accounts with many reports',
        description: 'If user receives more than X reports → flag account',
        status: AiRuleStatus.disabled,
        trigger: AiRuleTriggerType.reportThreshold,
        action: AiRuleActionType.flagAccount,
        threshold: 5,
        organizationId: actor.organizationId,
        workflowGraph: {
          'version': 1,
          'nodes': [
            {'id': 'trigger', 'type': 'reportThreshold'},
            {'id': 'action', 'type': 'flagAccount'},
          ],
          'edges': [
            {'from': 'trigger', 'to': 'action'},
          ],
        },
      ),
      AiAutomationRule(
        id: '',
        name: 'Hide spam-reported community posts',
        description:
            'If community post receives spam reports → hide temporarily',
        status: AiRuleStatus.disabled,
        trigger: AiRuleTriggerType.spamReports,
        action: AiRuleActionType.hideTemporarily,
        threshold: 3,
        organizationId: actor.organizationId,
      ),
      AiAutomationRule(
        id: '',
        name: 'Notify on fake tournament reports',
        description:
            'If tournament receives repeated fake reports → notify moderators',
        status: AiRuleStatus.disabled,
        trigger: AiRuleTriggerType.fakeReports,
        action: AiRuleActionType.notifyModerators,
        threshold: 3,
        organizationId: actor.organizationId,
      ),
      AiAutomationRule(
        id: '',
        name: 'Support alert on stream disconnects',
        description:
            'If stream disconnects multiple times → generate support alert',
        status: AiRuleStatus.disabled,
        trigger: AiRuleTriggerType.streamDisconnects,
        action: AiRuleActionType.createSupportAlert,
        threshold: 3,
        organizationId: actor.organizationId,
      ),
    ];
    for (final r in defaults) {
      await saveRule(actor: actor, rule: r);
    }
  }

  // ---------------------------------------------------------------------------
  // Jobs / logs / settings / models
  // ---------------------------------------------------------------------------

  Future<List<AiJob>> fetchJobs({
    required AdminAppType appType,
    required AdminUser? actor,
  }) async {
    Query<Map<String, dynamic>> query = _jobs;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      query = query.where('organizationId', isEqualTo: orgId);
    }
    try {
      final snap = await query
          .orderBy('scheduledAt', descending: true)
          .limit(80)
          .get();
      return snap.docs.map((d) => AiJob.fromMap(d.id, d.data())).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<AiJob> scheduleJob({
    required AdminUser actor,
    required AiJobKind kind,
    String note = '',
  }) async {
    final job = AiJob(
      id: '',
      kind: kind,
      status: AiJobStatus.scheduled,
      note: note.isEmpty
          ? 'Queued for future Cloud Function worker — no live scan'
          : note,
      organizationId: actor.organizationId,
    );
    final ref = await _jobs.add(job.toCreateMap());
    await _appendLog(
      action: AiLogAction.jobScheduled,
      actor: actor,
      recommendation: kind.label,
      organizationId: actor.organizationId,
      detail: note,
    );
    await _writeAudit(
      action: 'ai.job_scheduled',
      actor: actor,
      targetUid: ref.id,
      targetEmail: kind.label,
      organizationId: actor.organizationId,
    );
    final snap = await ref.get();
    return AiJob.fromMap(ref.id, snap.data() ?? {});
  }

  Future<List<AiOpsLogEntry>> fetchLogs({
    required AdminAppType appType,
    required AdminUser? actor,
    int limit = 80,
  }) async {
    Query<Map<String, dynamic>> query = _logs;
    if (appType == AdminAppType.organizationAdmin) {
      final orgId = actor?.organizationId;
      if (orgId == null || orgId.isEmpty) return const [];
      query = query.where('organizationId', isEqualTo: orgId);
    }
    try {
      final snap =
          await query.orderBy('timestamp', descending: true).limit(limit).get();
      return snap.docs
          .map((d) => AiOpsLogEntry.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<AiOpsSettings> fetchSettings() async {
    try {
      final snap = await _settingsDoc.get();
      return AiOpsSettings.fromMap(snap.data());
    } catch (_) {
      return const AiOpsSettings();
    }
  }

  Future<void> saveSettings({
    required AdminUser actor,
    required AiOpsSettings settings,
  }) async {
    await _settingsDoc.set(settings.toMap(), SetOptions(merge: true));
    // Mirror key flags into admin_feature_flags for platform consistency.
    final flags = {
      'ai_ops_enabled': settings.enableAi,
      'ai_automation_enabled': settings.enableAutomation,
      'ai_smart_reports': settings.enableSmartReports,
      'ai_spam_detection': settings.enableSpamDetection,
      'ai_recommendations': settings.enableRecommendations,
      'ai_duplicate_detection': settings.enableDuplicateDetection,
      'ai_fraud_detection': settings.enableFraudDetection,
    };
    for (final e in flags.entries) {
      try {
        await _db
            .collection(AdminCollections.adminFeatureFlags)
            .doc(e.key)
            .set({
          'key': e.key,
          'enabled': e.value,
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'ai_ops',
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    await _appendLog(
      action: AiLogAction.settingsUpdated,
      actor: actor,
      recommendation: 'AI settings',
      organizationId: actor.organizationId,
      detail: 'Provider=${settings.preferredProvider.label}',
    );
    await _writeAudit(
      action: 'ai.settings_updated',
      actor: actor,
      targetUid: 'global',
      targetEmail: 'AI settings',
      organizationId: actor.organizationId,
    );
  }

  List<AiModelRegistryEntry> listModels() => AiProviderCatalog.defaultModels;

  Future<void> requestManualScan({
    required AdminUser actor,
    AiJobKind kind = AiJobKind.manualScan,
  }) async {
    await scheduleJob(
      actor: actor,
      kind: kind,
      note: 'Manual scan requested — worker will batch-process later',
    );
    await _appendLog(
      action: AiLogAction.scanRequested,
      actor: actor,
      recommendation: kind.label,
      organizationId: actor.organizationId,
    );
  }

  Future<void> _appendLog({
    required AiLogAction action,
    required AdminUser actor,
    String recommendation = '',
    AiRecommendationStatus status = AiRecommendationStatus.pending,
    String? organizationId,
    String detail = '',
  }) async {
    try {
      await _logs.add(
        AiOpsLogEntry(
          id: '',
          action: action,
          recommendation: recommendation,
          status: status,
          actorUid: actor.uid,
          actorEmail: actor.email,
          organizationId: organizationId ?? actor.organizationId,
          detail: detail,
        ).toCreateMap(),
      );
    } catch (_) {}
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
          'module': 'ai_ops',
          'entity': 'ai_ops',
          'role': actor.roleId,
          if (organizationId != null && organizationId.isNotEmpty)
            'organizationId': organizationId,
        },
      );
      await _audit.add(entry.toMap());
    } catch (_) {}
  }
}
