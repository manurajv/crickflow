import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'ai_ops_enums.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

class AiRecommendation extends Equatable {
  const AiRecommendation({
    required this.id,
    required this.title,
    this.reason = '',
    this.category = AiRecommendationCategory.other,
    this.status = AiRecommendationStatus.pending,
    this.confidence = 0.5,
    this.entityType = AiEntityType.other,
    this.entityId = '',
    this.entityLabel = '',
    this.organizationId,
    this.country = '',
    this.stateProvince = '',
    this.similarityPercent,
    this.reportPriority,
    this.duplicateDecision = DuplicateDecision.pending,
    this.suggestedAction = '',
    this.provider = AiProviderId.none,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.resolvedByUid,
    this.resolvedByEmail,
  });

  final String id;
  final String title;
  final String reason;
  final AiRecommendationCategory category;
  final AiRecommendationStatus status;
  final double confidence;
  final AiEntityType entityType;
  final String entityId;
  final String entityLabel;
  final String? organizationId;
  final String country;
  final String stateProvince;
  final double? similarityPercent;
  final AiReportPriority? reportPriority;
  final DuplicateDecision duplicateDecision;
  final String suggestedAction;
  final AiProviderId provider;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String? resolvedByUid;
  final String? resolvedByEmail;

  AiConfidenceBand get confidenceBand => AiConfidenceBand.fromScore(confidence);

  factory AiRecommendation.fromMap(String id, Map<String, dynamic> map) {
    return AiRecommendation(
      id: id,
      title: (map['title'] as String?) ?? '',
      reason: (map['reason'] as String?) ?? '',
      category: AiRecommendationCategory.parse(map['category'] as String?),
      status: AiRecommendationStatus.parse(map['status'] as String?),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      entityType: AiEntityType.parse(map['entityType'] as String?),
      entityId: (map['entityId'] as String?) ?? '',
      entityLabel: (map['entityLabel'] as String?) ?? '',
      organizationId: map['organizationId'] as String?,
      country: (map['country'] as String?) ?? '',
      stateProvince: (map['stateProvince'] as String?) ?? '',
      similarityPercent: (map['similarityPercent'] as num?)?.toDouble(),
      reportPriority: map['reportPriority'] == null
          ? null
          : AiReportPriority.parse(map['reportPriority'] as String?),
      duplicateDecision:
          DuplicateDecision.parse(map['duplicateDecision'] as String?),
      suggestedAction: (map['suggestedAction'] as String?) ?? '',
      provider: AiProviderId.parse(map['provider'] as String?),
      createdAt: _ts(map['createdAt']),
      updatedAt: _ts(map['updatedAt']),
      resolvedAt: _ts(map['resolvedAt']),
      resolvedByUid: map['resolvedByUid'] as String?,
      resolvedByEmail: map['resolvedByEmail'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'title': title,
        'reason': reason,
        'category': category.wireValue,
        'status': status.wireValue,
        'confidence': confidence,
        'entityType': entityType.wireValue,
        'entityId': entityId,
        'entityLabel': entityLabel,
        if (organizationId != null) 'organizationId': organizationId,
        'country': country,
        'stateProvince': stateProvince,
        if (similarityPercent != null) 'similarityPercent': similarityPercent,
        if (reportPriority != null)
          'reportPriority': reportPriority!.wireValue,
        'duplicateDecision': duplicateDecision.wireValue,
        'suggestedAction': suggestedAction,
        'provider': provider.wireValue,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, status, confidence, updatedAt];
}

class AiAutomationRule extends Equatable {
  const AiAutomationRule({
    required this.id,
    required this.name,
    this.description = '',
    this.status = AiRuleStatus.draft,
    this.trigger = AiRuleTriggerType.custom,
    this.action = AiRuleActionType.createRecommendation,
    this.executionMode = AiRuleExecutionMode.recommendOnly,
    this.threshold = 3,
    this.organizationId,
    this.createdAt,
    this.updatedAt,
    /// Future visual workflow builder JSON (nodes/edges). Opaque for now.
    this.workflowGraph = const {},
  });

  final String id;
  final String name;
  final String description;
  final AiRuleStatus status;
  final AiRuleTriggerType trigger;
  final AiRuleActionType action;
  final AiRuleExecutionMode executionMode;
  final int threshold;
  final String? organizationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> workflowGraph;

  factory AiAutomationRule.fromMap(String id, Map<String, dynamic> map) {
    final graph = map['workflowGraph'];
    return AiAutomationRule(
      id: id,
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      status: AiRuleStatus.parse(map['status'] as String?),
      trigger: AiRuleTriggerType.parse(map['trigger'] as String?),
      action: AiRuleActionType.parse(map['action'] as String?),
      executionMode:
          AiRuleExecutionMode.parse(map['executionMode'] as String?),
      threshold: (map['threshold'] as num?)?.toInt() ?? 3,
      organizationId: map['organizationId'] as String?,
      createdAt: _ts(map['createdAt']),
      updatedAt: _ts(map['updatedAt']),
      workflowGraph: graph is Map
          ? Map<String, dynamic>.from(graph)
          : const {},
    );
  }

  Map<String, dynamic> toMap({bool creating = false}) => {
        'name': name,
        'description': description,
        'status': status.wireValue,
        'trigger': trigger.wireValue,
        'action': action.wireValue,
        'executionMode': executionMode.wireValue,
        'threshold': threshold,
        if (organizationId != null) 'organizationId': organizationId,
        'workflowGraph': workflowGraph,
        'updatedAt': FieldValue.serverTimestamp(),
        if (creating) 'createdAt': FieldValue.serverTimestamp(),
      };

  AiAutomationRule copyWith({
    String? id,
    String? name,
    String? description,
    AiRuleStatus? status,
    AiRuleTriggerType? trigger,
    AiRuleActionType? action,
    AiRuleExecutionMode? executionMode,
    int? threshold,
    String? organizationId,
    Map<String, dynamic>? workflowGraph,
  }) {
    return AiAutomationRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      trigger: trigger ?? this.trigger,
      action: action ?? this.action,
      executionMode: executionMode ?? this.executionMode,
      threshold: threshold ?? this.threshold,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      workflowGraph: workflowGraph ?? this.workflowGraph,
    );
  }

  @override
  List<Object?> get props => [id, name, status, trigger, action];
}

class AiJob extends Equatable {
  const AiJob({
    required this.id,
    required this.kind,
    this.status = AiJobStatus.scheduled,
    this.note = '',
    this.organizationId,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.error,
  });

  final String id;
  final AiJobKind kind;
  final AiJobStatus status;
  final String note;
  final String? organizationId;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? error;

  factory AiJob.fromMap(String id, Map<String, dynamic> map) {
    return AiJob(
      id: id,
      kind: AiJobKind.parse(map['kind'] as String?),
      status: AiJobStatus.parse(map['status'] as String?),
      note: (map['note'] as String?) ?? '',
      organizationId: map['organizationId'] as String?,
      scheduledAt: _ts(map['scheduledAt']),
      startedAt: _ts(map['startedAt']),
      completedAt: _ts(map['completedAt']),
      error: map['error'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'kind': kind.wireValue,
        'status': status.wireValue,
        'note': note,
        if (organizationId != null) 'organizationId': organizationId,
        'scheduledAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [id, kind, status];
}

class AiModelRegistryEntry extends Equatable {
  const AiModelRegistryEntry({
    required this.id,
    required this.provider,
    required this.name,
    this.version = '—',
    this.status = AiModelStatus.notConfigured,
    this.capabilities = const [],
    this.lastUpdated,
    this.note = 'Provider adapter reserved — keys never stored in client',
  });

  final String id;
  final AiProviderId provider;
  final String name;
  final String version;
  final AiModelStatus status;
  final List<String> capabilities;
  final DateTime? lastUpdated;
  final String note;

  @override
  List<Object?> get props => [id, provider, status];
}

class AiOpsLogEntry extends Equatable {
  const AiOpsLogEntry({
    required this.id,
    required this.action,
    this.recommendation = '',
    this.status = AiRecommendationStatus.pending,
    this.actorUid = '',
    this.actorEmail = '',
    this.organizationId,
    this.timestamp,
    this.detail = '',
  });

  final String id;
  final AiLogAction action;
  final String recommendation;
  final AiRecommendationStatus status;
  final String actorUid;
  final String actorEmail;
  final String? organizationId;
  final DateTime? timestamp;
  final String detail;

  factory AiOpsLogEntry.fromMap(String id, Map<String, dynamic> map) {
    return AiOpsLogEntry(
      id: id,
      action: AiLogAction.parse(map['action'] as String?),
      recommendation: (map['recommendation'] as String?) ?? '',
      status: AiRecommendationStatus.parse(map['status'] as String?),
      actorUid: (map['actorUid'] as String?) ?? '',
      actorEmail: (map['actorEmail'] as String?) ?? '',
      organizationId: map['organizationId'] as String?,
      timestamp: _ts(map['timestamp']),
      detail: (map['detail'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'action': action.wireValue,
        'recommendation': recommendation,
        'status': status.wireValue,
        'actorUid': actorUid,
        'actorEmail': actorEmail,
        if (organizationId != null) 'organizationId': organizationId,
        'timestamp': FieldValue.serverTimestamp(),
        'detail': detail,
      };

  @override
  List<Object?> get props => [id, action, timestamp];
}

class AiOpsSettings extends Equatable {
  const AiOpsSettings({
    this.enableAi = false,
    this.enableAutomation = false,
    this.enableSmartReports = true,
    this.enableSpamDetection = true,
    this.enableRecommendations = true,
    this.enableDuplicateDetection = true,
    this.enableFraudDetection = false,
    this.preferredProvider = AiProviderId.none,
    this.updatedAt,
  });

  final bool enableAi;
  final bool enableAutomation;
  final bool enableSmartReports;
  final bool enableSpamDetection;
  final bool enableRecommendations;
  final bool enableDuplicateDetection;
  final bool enableFraudDetection;
  final AiProviderId preferredProvider;
  final DateTime? updatedAt;

  factory AiOpsSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AiOpsSettings();
    return AiOpsSettings(
      enableAi: map['enableAi'] as bool? ?? false,
      enableAutomation: map['enableAutomation'] as bool? ?? false,
      enableSmartReports: map['enableSmartReports'] as bool? ?? true,
      enableSpamDetection: map['enableSpamDetection'] as bool? ?? true,
      enableRecommendations: map['enableRecommendations'] as bool? ?? true,
      enableDuplicateDetection:
          map['enableDuplicateDetection'] as bool? ?? true,
      enableFraudDetection: map['enableFraudDetection'] as bool? ?? false,
      preferredProvider:
          AiProviderId.parse(map['preferredProvider'] as String?),
      updatedAt: _ts(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'enableAi': enableAi,
        'enableAutomation': enableAutomation,
        'enableSmartReports': enableSmartReports,
        'enableSpamDetection': enableSpamDetection,
        'enableRecommendations': enableRecommendations,
        'enableDuplicateDetection': enableDuplicateDetection,
        'enableFraudDetection': enableFraudDetection,
        'preferredProvider': preferredProvider.wireValue,
        // Never persist API keys / credentials here.
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AiOpsSettings copyWith({
    bool? enableAi,
    bool? enableAutomation,
    bool? enableSmartReports,
    bool? enableSpamDetection,
    bool? enableRecommendations,
    bool? enableDuplicateDetection,
    bool? enableFraudDetection,
    AiProviderId? preferredProvider,
  }) {
    return AiOpsSettings(
      enableAi: enableAi ?? this.enableAi,
      enableAutomation: enableAutomation ?? this.enableAutomation,
      enableSmartReports: enableSmartReports ?? this.enableSmartReports,
      enableSpamDetection: enableSpamDetection ?? this.enableSpamDetection,
      enableRecommendations:
          enableRecommendations ?? this.enableRecommendations,
      enableDuplicateDetection:
          enableDuplicateDetection ?? this.enableDuplicateDetection,
      enableFraudDetection: enableFraudDetection ?? this.enableFraudDetection,
      preferredProvider: preferredProvider ?? this.preferredProvider,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        enableAi,
        enableAutomation,
        enableSmartReports,
        enableSpamDetection,
        enableRecommendations,
        enableDuplicateDetection,
        enableFraudDetection,
        preferredProvider,
      ];
}

class AiInsightCard extends Equatable {
  const AiInsightCard({
    required this.id,
    required this.title,
    required this.value,
    this.subtitle = '',
    this.trend = '',
  });

  final String id;
  final String title;
  final String value;
  final String subtitle;
  final String trend;

  @override
  List<Object?> get props => [id, title, value];
}

class AiOpsSummary extends Equatable {
  const AiOpsSummary({
    this.suggestions = 0,
    this.pendingReviews = 0,
    this.spamDetected = 0,
    this.duplicateAccounts = 0,
    this.duplicateTeams = 0,
    this.duplicateGrounds = 0,
    this.fraudAlerts = 0,
    this.automationRules = 0,
    this.resolvedRecommendations = 0,
  });

  final int suggestions;
  final int pendingReviews;
  final int spamDetected;
  final int duplicateAccounts;
  final int duplicateTeams;
  final int duplicateGrounds;
  final int fraudAlerts;
  final int automationRules;
  final int resolvedRecommendations;

  @override
  List<Object?> get props => [suggestions, pendingReviews, automationRules];
}

class AiOpsPageResult {
  const AiOpsPageResult({
    required this.items,
    required this.hasMore,
    this.lastDoc,
  });

  final List<AiRecommendation> items;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
}
