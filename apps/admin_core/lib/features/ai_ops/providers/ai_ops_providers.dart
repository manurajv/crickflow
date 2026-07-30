import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/ai_ops_repository.dart';
import '../data/ai_provider_adapter.dart';
import '../models/ai_ops_enums.dart';
import '../models/ai_ops_filters.dart';
import '../models/managed_ai_ops.dart';

final aiOpsRepositoryProvider = Provider<AiOpsRepository>((ref) {
  return AiOpsRepository();
});

class AiOpsHubState {
  const AiOpsHubState({
    this.section = AiOpsHubSection.dashboard,
    this.recommendations = const [],
    this.rules = const [],
    this.jobs = const [],
    this.logs = const [],
    this.insights = const [],
    this.models = const [],
    this.settings = const AiOpsSettings(),
    this.summary = const AiOpsSummary(),
    this.filters = AiOpsFilters.empty,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedRecId,
    this.selectedRuleId,
  });

  final AiOpsHubSection section;
  final List<AiRecommendation> recommendations;
  final List<AiAutomationRule> rules;
  final List<AiJob> jobs;
  final List<AiOpsLogEntry> logs;
  final List<AiInsightCard> insights;
  final List<AiModelRegistryEntry> models;
  final AiOpsSettings settings;
  final AiOpsSummary summary;
  final AiOpsFilters filters;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedRecId;
  final String? selectedRuleId;

  AiRecommendation? get selectedRec {
    if (selectedRecId == null) return null;
    for (final r in recommendations) {
      if (r.id == selectedRecId) return r;
    }
    return null;
  }

  AiAutomationRule? get selectedRule {
    if (selectedRuleId == null) return null;
    for (final r in rules) {
      if (r.id == selectedRuleId) return r;
    }
    return null;
  }

  AiOpsHubState copyWith({
    AiOpsHubSection? section,
    List<AiRecommendation>? recommendations,
    List<AiAutomationRule>? rules,
    List<AiJob>? jobs,
    List<AiOpsLogEntry>? logs,
    List<AiInsightCard>? insights,
    List<AiModelRegistryEntry>? models,
    AiOpsSettings? settings,
    AiOpsSummary? summary,
    AiOpsFilters? filters,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? selectedRecId,
    bool clearSelectedRec = false,
    String? selectedRuleId,
    bool clearSelectedRule = false,
  }) {
    return AiOpsHubState(
      section: section ?? this.section,
      recommendations: recommendations ?? this.recommendations,
      rules: rules ?? this.rules,
      jobs: jobs ?? this.jobs,
      logs: logs ?? this.logs,
      insights: insights ?? this.insights,
      models: models ?? this.models,
      settings: settings ?? this.settings,
      summary: summary ?? this.summary,
      filters: filters ?? this.filters,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedRecId:
          clearSelectedRec ? null : (selectedRecId ?? this.selectedRecId),
      selectedRuleId:
          clearSelectedRule ? null : (selectedRuleId ?? this.selectedRuleId),
    );
  }
}

class AiOpsHubController extends StateNotifier<AiOpsHubState> {
  AiOpsHubController(this._ref) : super(const AiOpsHubState()) {
    Future(() {
      if (mounted) ensureBootstrapped();
    });
  }

  final Ref _ref;
  bool _bootstrapped = false;

  AiOpsRepository get _repo => _ref.read(aiOpsRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  bool get isSuperAdmin => _appType == AdminAppType.superAdmin;

  Future<void> ensureBootstrapped() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    state = state.copyWith(isLoading: true, clearError: true, clearCursor: true);
    try {
      await _load();
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSection(AiOpsHubSection section) async {
    state = state.copyWith(
      section: section,
      clearSelectedRec: true,
      clearSelectedRule: true,
      clearCursor: true,
      recommendations: const [],
    );
    await refresh();
  }

  Future<void> applyFilters(AiOpsFilters filters) async {
    state = state.copyWith(filters: filters, clearCursor: true);
    await refresh();
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  void selectRecommendation(AiRecommendation? rec) {
    state = state.copyWith(
      selectedRecId: rec?.id,
      clearSelectedRec: rec == null,
    );
  }

  void selectRule(AiAutomationRule? rule) {
    state = state.copyWith(
      selectedRuleId: rule?.id,
      clearSelectedRule: rule == null,
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    if (!_isRecSection(state.section) &&
        state.section != AiOpsHubSection.dashboard) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.fetchRecommendations(
        appType: _appType,
        actor: _actor,
        filters: state.filters,
        startAfter: state.cursor,
        forceCategories: _categoriesForSection(state.section),
      );
      if (!mounted) return;
      state = state.copyWith(
        recommendations: [...state.recommendations, ...page.items],
        hasMore: page.hasMore,
        cursor: page.lastDoc,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  bool _isRecSection(AiOpsHubSection s) =>
      s == AiOpsHubSection.dashboard ||
      s == AiOpsHubSection.recommendationCenter ||
      s == AiOpsHubSection.moderationAssistant ||
      s == AiOpsHubSection.smartReports ||
      s == AiOpsHubSection.fraudDetection ||
      s == AiOpsHubSection.duplicateDetection ||
      s == AiOpsHubSection.spamDetection;

  Set<AiRecommendationCategory>? _categoriesForSection(AiOpsHubSection s) {
    return switch (s) {
      AiOpsHubSection.moderationAssistant => {
          AiRecommendationCategory.moderation,
        },
      AiOpsHubSection.smartReports => {AiRecommendationCategory.reportPriority},
      AiOpsHubSection.fraudDetection => {AiRecommendationCategory.fraud},
      AiOpsHubSection.duplicateDetection => {
          AiRecommendationCategory.duplicate,
        },
      AiOpsHubSection.spamDetection => {AiRecommendationCategory.spam},
      _ => null,
    };
  }

  Future<void> _load() async {
    final actor = _actor;
    final summary = await _repo.fetchSummary(
      appType: _appType,
      actor: actor,
    );
    final settings = await _repo.fetchSettings();
    _repo.setProvider(AiProviderCatalog.resolve(settings.preferredProvider));

    final section = state.section;
    switch (section) {
      case AiOpsHubSection.insights:
        final insights = await _repo.fetchInsights(
          appType: _appType,
          actor: actor,
        );
        state = state.copyWith(
          insights: insights,
          summary: summary,
          settings: settings,
          models: _repo.listModels(),
        );
        return;
      case AiOpsHubSection.automationRules:
        if (actor != null) {
          await _repo.seedDefaultRulesIfEmpty(
            appType: _appType,
            actor: actor,
          );
        }
        final rules = await _repo.fetchRules(appType: _appType, actor: actor);
        state = state.copyWith(
          rules: rules,
          summary: summary,
          settings: settings,
          models: _repo.listModels(),
        );
        return;
      case AiOpsHubSection.aiJobs:
        final jobs = await _repo.fetchJobs(appType: _appType, actor: actor);
        state = state.copyWith(
          jobs: jobs,
          summary: summary,
          settings: settings,
          models: _repo.listModels(),
        );
        return;
      case AiOpsHubSection.aiModels:
        state = state.copyWith(
          models: _repo.listModels(),
          summary: summary,
          settings: settings,
        );
        return;
      case AiOpsHubSection.aiLogs:
        final logs = await _repo.fetchLogs(appType: _appType, actor: actor);
        state = state.copyWith(
          logs: logs,
          summary: summary,
          settings: settings,
          models: _repo.listModels(),
        );
        return;
      case AiOpsHubSection.aiSettings:
        state = state.copyWith(
          settings: settings,
          summary: summary,
          models: _repo.listModels(),
        );
        return;
      default:
        break;
    }

    final page = await _repo.fetchRecommendations(
      appType: _appType,
      actor: actor,
      filters: state.filters,
      forceCategories: _categoriesForSection(section),
    );
    final rules = section == AiOpsHubSection.dashboard
        ? await _repo.fetchRules(appType: _appType, actor: actor)
        : state.rules;

    state = state.copyWith(
      recommendations: page.items,
      hasMore: page.hasMore,
      cursor: page.lastDoc,
      summary: summary,
      settings: settings,
      rules: rules,
      models: _repo.listModels(),
      clearCursor: page.lastDoc == null,
    );
  }

  Future<void> resolveSelected(
    AiRecommendationStatus status, {
    DuplicateDecision? duplicateDecision,
    String? reason,
  }) async {
    final rec = state.selectedRec;
    final actor = _actor;
    if (rec == null || actor == null) return;
    // Org admins may only manage their org recommendations.
    if (!isSuperAdmin &&
        actor.organizationId != null &&
        rec.organizationId != null &&
        rec.organizationId != actor.organizationId) {
      state = state.copyWith(error: 'Out of organization scope');
      return;
    }
    await _repo.resolveRecommendation(
      rec: rec,
      actor: actor,
      status: status,
      duplicateDecision: duplicateDecision,
      reason: reason,
    );
    await refresh();
  }

  Future<void> saveRule(AiAutomationRule rule) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.saveRule(actor: actor, rule: rule);
    await refresh();
  }

  Future<void> setRuleStatus(AiAutomationRule rule, AiRuleStatus status) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setRuleStatus(rule: rule, actor: actor, status: status);
    await refresh();
  }

  Future<void> duplicateRule(AiAutomationRule rule) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.duplicateRule(rule: rule, actor: actor);
    await refresh();
  }

  Future<void> deleteRule(AiAutomationRule rule) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.deleteRule(rule: rule, actor: actor);
    await refresh();
  }

  Future<void> saveSettings(AiOpsSettings settings) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) {
      state = state.copyWith(error: 'Only Super Admin can change AI settings');
      return;
    }
    await _repo.saveSettings(actor: actor, settings: settings);
    await refresh();
  }

  Future<void> runManualScan({AiJobKind kind = AiJobKind.manualScan}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.requestManualScan(actor: actor, kind: kind);
    await refresh();
  }

  Future<void> scheduleScan() async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.scheduleJob(
      actor: actor,
      kind: AiJobKind.scheduledScan,
      note: 'Scheduled for future Cloud Function batch worker',
    );
    await refresh();
  }

  Future<void> seedDemoRecommendations() async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    final samples = [
      (
        AiRecommendationCategory.moderation,
        'Review reported team',
        'Multiple community reports — admin decision required',
        AiEntityType.team,
        0.72,
      ),
      (
        AiRecommendationCategory.spam,
        'Possible spam community post',
        'Heuristic spam signals — confidence sample',
        AiEntityType.communityPost,
        0.81,
      ),
      (
        AiRecommendationCategory.duplicate,
        'Similar team name detected',
        'Name similarity sample — merge is future',
        AiEntityType.team,
        0.88,
      ),
      (
        AiRecommendationCategory.fraud,
        'Unusual streaming behaviour',
        'Placeholder fraud signal — future AI only',
        AiEntityType.broadcast,
        0.64,
      ),
      (
        AiRecommendationCategory.reportPriority,
        'Prioritize critical report',
        'Smart report priority suggestion',
        AiEntityType.report,
        0.9,
      ),
      (
        AiRecommendationCategory.operations,
        'Archive inactive organization',
        'Inactivity heuristic — approval required',
        AiEntityType.organization,
        0.55,
      ),
    ];
    for (final s in samples) {
      await _repo.seedSampleRecommendation(
        actor: actor,
        category: s.$1,
        title: s.$2,
        reason: s.$3,
        entityType: s.$4,
        confidence: s.$5,
        similarity: s.$1 == AiRecommendationCategory.duplicate ? 87 : null,
        priority: s.$1 == AiRecommendationCategory.reportPriority
            ? AiReportPriority.critical
            : null,
        suggestedAction: s.$2,
      );
    }
    await refresh();
  }
}

final aiOpsHubControllerProvider =
    StateNotifierProvider.autoDispose<AiOpsHubController, AiOpsHubState>((ref) {
  return AiOpsHubController(ref);
});
