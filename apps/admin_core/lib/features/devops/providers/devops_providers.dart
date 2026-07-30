import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/devops_repository.dart';
import '../models/devops_enums.dart';
import '../models/devops_filters.dart';
import '../models/managed_devops.dart';

final devopsRepositoryProvider = Provider<DevOpsRepository>((ref) {
  return DevOpsRepository();
});

class DevOpsHubState {
  const DevOpsHubState({
    this.section = DevOpsHubSection.dashboard,
    this.summary = const DevOpsSummary(),
    this.settings = const DevOpsPlatformSettings(),
    this.releases = const [],
    this.deployments = const [],
    this.builds = const [],
    this.rollouts = const [],
    this.rollbacks = const [],
    this.domains = const [],
    this.envVars = const [],
    this.timeline = const [],
    this.filters = DevOpsFilters.empty,
    this.isLoading = false,
    this.error,
    this.selectedReleaseId,
  });

  final DevOpsHubSection section;
  final DevOpsSummary summary;
  final DevOpsPlatformSettings settings;
  final List<ManagedRelease> releases;
  final List<ManagedDeploymentLog> deployments;
  final List<ManagedBuild> builds;
  final List<ManagedRollout> rollouts;
  final List<ManagedRollbackPlan> rollbacks;
  final List<ManagedDomain> domains;
  final List<ManagedEnvVar> envVars;
  final List<ManagedTimelineEvent> timeline;
  final DevOpsFilters filters;
  final bool isLoading;
  final String? error;
  final String? selectedReleaseId;

  ManagedRelease? get selectedRelease {
    if (selectedReleaseId == null) return null;
    for (final r in releases) {
      if (r.id == selectedReleaseId) return r;
    }
    return null;
  }

  DevOpsHubState copyWith({
    DevOpsHubSection? section,
    DevOpsSummary? summary,
    DevOpsPlatformSettings? settings,
    List<ManagedRelease>? releases,
    List<ManagedDeploymentLog>? deployments,
    List<ManagedBuild>? builds,
    List<ManagedRollout>? rollouts,
    List<ManagedRollbackPlan>? rollbacks,
    List<ManagedDomain>? domains,
    List<ManagedEnvVar>? envVars,
    List<ManagedTimelineEvent>? timeline,
    DevOpsFilters? filters,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? selectedReleaseId,
    bool clearSelectedRelease = false,
  }) {
    return DevOpsHubState(
      section: section ?? this.section,
      summary: summary ?? this.summary,
      settings: settings ?? this.settings,
      releases: releases ?? this.releases,
      deployments: deployments ?? this.deployments,
      builds: builds ?? this.builds,
      rollouts: rollouts ?? this.rollouts,
      rollbacks: rollbacks ?? this.rollbacks,
      domains: domains ?? this.domains,
      envVars: envVars ?? this.envVars,
      timeline: timeline ?? this.timeline,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedReleaseId: clearSelectedRelease
          ? null
          : (selectedReleaseId ?? this.selectedReleaseId),
    );
  }
}

class DevOpsHubController extends StateNotifier<DevOpsHubState> {
  DevOpsHubController(this._ref) : super(const DevOpsHubState()) {
    Future(() {
      if (mounted) ensureBootstrapped();
    });
  }

  final Ref _ref;
  bool _bootstrapped = false;

  DevOpsRepository get _repo => _ref.read(devopsRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;
  bool get isSuperAdmin => _appType == AdminAppType.superAdmin;

  Future<void> ensureBootstrapped() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    if (!isSuperAdmin) {
      state = state.copyWith(
        isLoading: false,
        error: 'DevOps Center is available to Super Admins only',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _load();
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSection(DevOpsHubSection section) async {
    state = state.copyWith(section: section);
    await refresh();
  }

  Future<void> applyFilters(DevOpsFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  void selectRelease(String? id) {
    state = state.copyWith(
      selectedReleaseId: id,
      clearSelectedRelease: id == null,
    );
  }

  Future<void> _load() async {
    final actor = _actor;
    final settings = await _repo.fetchSettings();
    final summary = await _repo.fetchSummary();
    final section = state.section;

    switch (section) {
      case DevOpsHubSection.dashboard:
        final releases = await _repo.fetchReleases(limit: 8);
        final deployments = await _repo.fetchDeployments(limit: 8);
        final timeline = await _repo.fetchTimeline(limit: 12);
        state = state.copyWith(
          settings: settings,
          summary: summary,
          releases: releases,
          deployments: deployments,
          timeline: timeline,
        );
        return;
      case DevOpsHubSection.environments:
      case DevOpsHubSection.qualityGates:
        state = state.copyWith(settings: settings, summary: summary);
        return;
      case DevOpsHubSection.releases:
      case DevOpsHubSection.versionHistory:
      case DevOpsHubSection.releaseNotes:
        final releases =
            await _repo.fetchReleases(filters: state.filters, limit: 60);
        state = state.copyWith(
          settings: settings,
          summary: summary,
          releases: releases,
        );
        return;
      case DevOpsHubSection.buildMonitor:
        final builds = await _repo.fetchBuilds();
        state = state.copyWith(
          settings: settings,
          summary: summary,
          builds: builds,
        );
        return;
      case DevOpsHubSection.featureRollout:
        final rollouts = await _repo.fetchRollouts();
        state = state.copyWith(
          settings: settings,
          summary: summary,
          rollouts: rollouts,
        );
        return;
      case DevOpsHubSection.rollbackCenter:
        final rollbacks = await _repo.fetchRollbacks();
        final releases = await _repo.fetchReleases(limit: 30);
        state = state.copyWith(
          settings: settings,
          summary: summary,
          rollbacks: rollbacks,
          releases: releases,
        );
        return;
      case DevOpsHubSection.deploymentLogs:
        final deployments =
            await _repo.fetchDeployments(filters: state.filters);
        state = state.copyWith(
          settings: settings,
          summary: summary,
          deployments: deployments,
        );
        return;
      case DevOpsHubSection.envVariables:
        final envVars = await _repo.fetchEnvVars(
          environment: state.filters.environment,
        );
        state = state.copyWith(
          settings: settings,
          summary: summary,
          envVars: envVars,
        );
        return;
      case DevOpsHubSection.domains:
        if (actor != null) {
          await _repo.ensureDefaultDomains(actor);
        }
        final domains = await _repo.fetchDomains();
        state = state.copyWith(
          settings: settings,
          summary: summary,
          domains: domains,
        );
        return;
      case DevOpsHubSection.timeline:
        final timeline = await _repo.fetchTimeline(limit: 60);
        state = state.copyWith(
          settings: settings,
          summary: summary,
          timeline: timeline,
        );
        return;
    }
  }

  Future<void> createRelease(ManagedRelease draft) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.createRelease(actor: actor, draft: draft);
    await refresh(force: true);
  }

  Future<void> setReleaseStatus(
    ManagedRelease release,
    DevOpsReleaseStatus status,
  ) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.updateReleaseStatus(
      actor: actor,
      release: release,
      status: status,
    );
    await refresh(force: true);
  }

  Future<void> duplicateRelease(ManagedRelease release) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.duplicateRelease(actor: actor, source: release);
    await refresh(force: true);
  }

  Future<void> saveRollout(ManagedRollout rollout) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.saveRollout(actor: actor, rollout: rollout);
    await refresh(force: true);
  }

  Future<void> prepareRollback({
    required String targetVersion,
    required String fromVersion,
    required String reason,
    required DevOpsEnvironment environment,
  }) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.prepareRollback(
      actor: actor,
      targetVersion: targetVersion,
      fromVersion: fromVersion,
      reason: reason,
      environment: environment,
    );
    await refresh(force: true);
  }

  Future<void> saveSettings(DevOpsPlatformSettings settings) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.saveSettings(actor: actor, settings: settings);
    await refresh(force: true);
  }

  Future<void> upsertEnvVarMeta({
    required String key,
    required DevOpsEnvironment environment,
    required bool configured,
  }) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.upsertEnvVarMeta(
      actor: actor,
      key: key,
      environment: environment,
      configured: configured,
    );
    await refresh(force: true);
  }
}

final devopsHubControllerProvider =
    StateNotifierProvider.autoDispose<DevOpsHubController, DevOpsHubState>(
        (ref) {
  return DevOpsHubController(ref);
});
