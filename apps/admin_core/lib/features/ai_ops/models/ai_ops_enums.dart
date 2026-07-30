/// AI Operations Center hub sections and domain enums.
///
/// Provider-agnostic: OpenAI / Gemini / Vertex / Claude / local models plug in
/// later via [AiProviderAdapter] without redesigning this module.
enum AiOpsHubSection {
  dashboard,
  insights,
  automationRules,
  moderationAssistant,
  smartReports,
  fraudDetection,
  duplicateDetection,
  spamDetection,
  recommendationCenter,
  aiJobs,
  aiModels,
  aiLogs,
  aiSettings;

  String get label => switch (this) {
        AiOpsHubSection.dashboard => 'Dashboard',
        AiOpsHubSection.insights => 'AI Insights',
        AiOpsHubSection.automationRules => 'Automation Rules',
        AiOpsHubSection.moderationAssistant => 'Moderation Assistant',
        AiOpsHubSection.smartReports => 'Smart Reports',
        AiOpsHubSection.fraudDetection => 'Fraud Detection',
        AiOpsHubSection.duplicateDetection => 'Duplicate Detection',
        AiOpsHubSection.spamDetection => 'Spam Detection',
        AiOpsHubSection.recommendationCenter => 'Recommendation Center',
        AiOpsHubSection.aiJobs => 'AI Jobs',
        AiOpsHubSection.aiModels => 'AI Models',
        AiOpsHubSection.aiLogs => 'AI Logs',
        AiOpsHubSection.aiSettings => 'AI Settings',
      };
}

enum AiRecommendationCategory {
  moderation,
  spam,
  duplicate,
  fraud,
  insight,
  reportPriority,
  growth,
  operations,
  other;

  String get label => switch (this) {
        AiRecommendationCategory.moderation => 'Moderation',
        AiRecommendationCategory.spam => 'Spam',
        AiRecommendationCategory.duplicate => 'Duplicate',
        AiRecommendationCategory.fraud => 'Fraud',
        AiRecommendationCategory.insight => 'Insight',
        AiRecommendationCategory.reportPriority => 'Smart Report',
        AiRecommendationCategory.growth => 'Growth',
        AiRecommendationCategory.operations => 'Operations',
        AiRecommendationCategory.other => 'Other',
      };

  String get wireValue => name;

  static AiRecommendationCategory parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiRecommendationCategory.other;
  }
}

enum AiRecommendationStatus {
  pending,
  accepted,
  rejected,
  executed,
  archived;

  String get label => switch (this) {
        AiRecommendationStatus.pending => 'Pending',
        AiRecommendationStatus.accepted => 'Accepted',
        AiRecommendationStatus.rejected => 'Rejected',
        AiRecommendationStatus.executed => 'Executed',
        AiRecommendationStatus.archived => 'Archived',
      };

  String get wireValue => name;

  static AiRecommendationStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiRecommendationStatus.pending;
  }
}

enum AiConfidenceBand {
  low,
  medium,
  high,
  critical;

  String get label => switch (this) {
        AiConfidenceBand.low => 'Low',
        AiConfidenceBand.medium => 'Medium',
        AiConfidenceBand.high => 'High',
        AiConfidenceBand.critical => 'Critical',
      };

  String get wireValue => name;

  static AiConfidenceBand fromScore(double score) {
    if (score >= 0.9) return AiConfidenceBand.critical;
    if (score >= 0.75) return AiConfidenceBand.high;
    if (score >= 0.5) return AiConfidenceBand.medium;
    return AiConfidenceBand.low;
  }

  static AiConfidenceBand parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiConfidenceBand.medium;
  }
}

enum AiEntityType {
  user,
  team,
  tournament,
  organization,
  ground,
  match,
  broadcast,
  communityPost,
  discoverPost,
  report,
  other;

  String get label => switch (this) {
        AiEntityType.user => 'User',
        AiEntityType.team => 'Team',
        AiEntityType.tournament => 'Tournament',
        AiEntityType.organization => 'Organization',
        AiEntityType.ground => 'Ground',
        AiEntityType.match => 'Match',
        AiEntityType.broadcast => 'Broadcast',
        AiEntityType.communityPost => 'Community Post',
        AiEntityType.discoverPost => 'Discover Post',
        AiEntityType.report => 'Report',
        AiEntityType.other => 'Other',
      };

  String get wireValue => name;

  static AiEntityType parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiEntityType.other;
  }
}

enum AiRuleStatus {
  enabled,
  disabled,
  draft;

  String get label => switch (this) {
        AiRuleStatus.enabled => 'Enabled',
        AiRuleStatus.disabled => 'Disabled',
        AiRuleStatus.draft => 'Draft',
      };

  String get wireValue => name;

  static AiRuleStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiRuleStatus.draft;
  }
}

enum AiRuleTriggerType {
  reportThreshold,
  spamReports,
  fakeReports,
  streamDisconnects,
  inactivity,
  duplicateSimilarity,
  custom;

  String get label => switch (this) {
        AiRuleTriggerType.reportThreshold => 'Report threshold',
        AiRuleTriggerType.spamReports => 'Spam reports',
        AiRuleTriggerType.fakeReports => 'Repeated fake reports',
        AiRuleTriggerType.streamDisconnects => 'Stream disconnects',
        AiRuleTriggerType.inactivity => 'Inactivity',
        AiRuleTriggerType.duplicateSimilarity => 'Duplicate similarity',
        AiRuleTriggerType.custom => 'Custom',
      };

  String get wireValue => name;

  static AiRuleTriggerType parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiRuleTriggerType.custom;
  }
}

enum AiRuleActionType {
  flagAccount,
  hideTemporarily,
  notifyModerators,
  createSupportAlert,
  createRecommendation,
  escalatePriority,
  none;

  String get label => switch (this) {
        AiRuleActionType.flagAccount => 'Flag account',
        AiRuleActionType.hideTemporarily => 'Hide temporarily',
        AiRuleActionType.notifyModerators => 'Notify moderators',
        AiRuleActionType.createSupportAlert => 'Generate support alert',
        AiRuleActionType.createRecommendation => 'Create recommendation',
        AiRuleActionType.escalatePriority => 'Escalate priority',
        AiRuleActionType.none => 'None',
      };

  String get wireValue => name;

  static AiRuleActionType parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiRuleActionType.createRecommendation;
  }
}

/// Automatic execution is opt-in and still requires an explicit rule flag.
/// Default is recommend-only — never mutate user data without approval.
enum AiRuleExecutionMode {
  recommendOnly,
  autoExecute;

  String get label => switch (this) {
        AiRuleExecutionMode.recommendOnly => 'Recommend only',
        AiRuleExecutionMode.autoExecute => 'Auto-execute (future)',
      };

  String get wireValue => name;

  static AiRuleExecutionMode parse(String? raw) {
    if (raw == 'autoExecute') return AiRuleExecutionMode.autoExecute;
    return AiRuleExecutionMode.recommendOnly;
  }
}

enum AiJobStatus {
  scheduled,
  running,
  completed,
  failed,
  cancelled;

  String get label => switch (this) {
        AiJobStatus.scheduled => 'Scheduled',
        AiJobStatus.running => 'Running',
        AiJobStatus.completed => 'Completed',
        AiJobStatus.failed => 'Failed',
        AiJobStatus.cancelled => 'Cancelled',
      };

  String get wireValue => name;

  static AiJobStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiJobStatus.scheduled;
  }
}

enum AiJobKind {
  manualScan,
  scheduledScan,
  spamScan,
  duplicateScan,
  fraudScan,
  insightRefresh,
  moderationBatch,
  other;

  String get label => switch (this) {
        AiJobKind.manualScan => 'Manual scan',
        AiJobKind.scheduledScan => 'Scheduled scan',
        AiJobKind.spamScan => 'Spam scan',
        AiJobKind.duplicateScan => 'Duplicate scan',
        AiJobKind.fraudScan => 'Fraud scan',
        AiJobKind.insightRefresh => 'Insight refresh',
        AiJobKind.moderationBatch => 'Moderation batch',
        AiJobKind.other => 'Other',
      };

  String get wireValue => name;

  static AiJobKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiJobKind.other;
  }
}

enum AiProviderId {
  none,
  openai,
  gemini,
  vertexAi,
  firebaseAi,
  azureOpenAi,
  anthropic,
  local;

  String get label => switch (this) {
        AiProviderId.none => 'None (rules engine)',
        AiProviderId.openai => 'OpenAI',
        AiProviderId.gemini => 'Google Gemini',
        AiProviderId.vertexAi => 'Vertex AI',
        AiProviderId.firebaseAi => 'Firebase AI Logic',
        AiProviderId.azureOpenAi => 'Azure OpenAI',
        AiProviderId.anthropic => 'Anthropic Claude',
        AiProviderId.local => 'Local AI Models',
      };

  String get wireValue => name;

  static AiProviderId parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiProviderId.none;
  }
}

enum AiModelStatus {
  notConfigured,
  ready,
  deprecated,
  error;

  String get label => switch (this) {
        AiModelStatus.notConfigured => 'Not configured',
        AiModelStatus.ready => 'Ready',
        AiModelStatus.deprecated => 'Deprecated',
        AiModelStatus.error => 'Error',
      };

  String get wireValue => name;

  static AiModelStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiModelStatus.notConfigured;
  }
}

enum AiLogAction {
  recommendationCreated,
  recommendationAccepted,
  recommendationRejected,
  recommendationExecuted,
  recommendationArchived,
  ruleCreated,
  ruleEnabled,
  ruleDisabled,
  ruleDuplicated,
  ruleDeleted,
  jobScheduled,
  jobStarted,
  jobCompleted,
  jobFailed,
  settingsUpdated,
  scanRequested,
  other;

  String get label => switch (this) {
        AiLogAction.recommendationCreated => 'Recommendation created',
        AiLogAction.recommendationAccepted => 'Recommendation accepted',
        AiLogAction.recommendationRejected => 'Recommendation rejected',
        AiLogAction.recommendationExecuted => 'Recommendation executed',
        AiLogAction.recommendationArchived => 'Recommendation archived',
        AiLogAction.ruleCreated => 'Rule created',
        AiLogAction.ruleEnabled => 'Rule enabled',
        AiLogAction.ruleDisabled => 'Rule disabled',
        AiLogAction.ruleDuplicated => 'Rule duplicated',
        AiLogAction.ruleDeleted => 'Rule deleted',
        AiLogAction.jobScheduled => 'Job scheduled',
        AiLogAction.jobStarted => 'Job started',
        AiLogAction.jobCompleted => 'Job completed',
        AiLogAction.jobFailed => 'Job failed',
        AiLogAction.settingsUpdated => 'Settings updated',
        AiLogAction.scanRequested => 'Scan requested',
        AiLogAction.other => 'Other',
      };

  String get wireValue => name;

  static AiLogAction parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiLogAction.other;
  }
}

enum AiReportPriority {
  critical,
  high,
  medium,
  low;

  String get label => switch (this) {
        AiReportPriority.critical => 'Critical',
        AiReportPriority.high => 'High',
        AiReportPriority.medium => 'Medium',
        AiReportPriority.low => 'Low',
      };

  String get wireValue => name;

  static AiReportPriority parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return AiReportPriority.medium;
  }
}

enum DuplicateDecision {
  pending,
  ignored,
  markedValid,
  mergeFuture;

  String get label => switch (this) {
        DuplicateDecision.pending => 'Pending',
        DuplicateDecision.ignored => 'Ignored',
        DuplicateDecision.markedValid => 'Marked valid',
        DuplicateDecision.mergeFuture => 'Merge (future)',
      };

  String get wireValue => name;

  static DuplicateDecision parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DuplicateDecision.pending;
  }
}
