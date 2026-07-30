import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../core/config/admin_env_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/continuity_repository.dart';
import '../models/continuity_enums.dart';
import '../models/continuity_filters.dart';
import '../models/managed_continuity.dart';

final continuityRepositoryProvider = Provider<ContinuityRepository>((ref) {
  return ContinuityRepository();
});

class ContinuityHubState {
  const ContinuityHubState({
    this.section = ContinuityHubSection.dashboard,
    this.filters = ContinuityFilters.empty,
    this.summary = const ContinuitySummary(),
    this.backups = const [],
    this.restores = const [],
    this.plans = const [],
    this.migrations = const [],
    this.timeline = const [],
    this.health = const [],
    this.settings = const ContinuityPlatformSettings(),
    this.isLoading = false,
    this.error,
    this.bootstrapped = false,
  });

  final ContinuityHubSection section;
  final ContinuityFilters filters;
  final ContinuitySummary summary;
  final List<ManagedContinuityBackup> backups;
  final List<ManagedContinuityRestore> restores;
  final List<ManagedRecoveryPlan> plans;
  final List<ManagedContinuityMigration> migrations;
  final List<ContinuityTimelineEvent> timeline;
  final List<ContinuityHealthCheck> health;
  final ContinuityPlatformSettings settings;
  final bool isLoading;
  final String? error;
  final bool bootstrapped;

  ContinuityHubState copyWith({
    ContinuityHubSection? section,
    ContinuityFilters? filters,
    ContinuitySummary? summary,
    List<ManagedContinuityBackup>? backups,
    List<ManagedContinuityRestore>? restores,
    List<ManagedRecoveryPlan>? plans,
    List<ManagedContinuityMigration>? migrations,
    List<ContinuityTimelineEvent>? timeline,
    List<ContinuityHealthCheck>? health,
    ContinuityPlatformSettings? settings,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? bootstrapped,
  }) {
    return ContinuityHubState(
      section: section ?? this.section,
      filters: filters ?? this.filters,
      summary: summary ?? this.summary,
      backups: backups ?? this.backups,
      restores: restores ?? this.restores,
      plans: plans ?? this.plans,
      migrations: migrations ?? this.migrations,
      timeline: timeline ?? this.timeline,
      health: health ?? this.health,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      bootstrapped: bootstrapped ?? this.bootstrapped,
    );
  }
}

class ContinuityHubController extends StateNotifier<ContinuityHubState> {
  ContinuityHubController(this._ref) : super(const ContinuityHubState());

  final Ref _ref;

  ContinuityRepository get _repo => _ref.read(continuityRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  bool get isSuperAdmin => _appType == AdminAppType.superAdmin;
  dynamic get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> ensureBootstrapped() async {
    if (state.bootstrapped) return;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    if (!isSuperAdmin) {
      state = state.copyWith(
        error: 'Continuity Center is Super Admin only',
        isLoading: false,
        bootstrapped: true,
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _load();
      state = state.copyWith(isLoading: false, bootstrapped: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSection(ContinuityHubSection section) async {
    state = state.copyWith(section: section);
    await refresh();
  }

  Future<void> applyFilters(ContinuityFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  Future<void> _load() async {
    final summary = await _repo.fetchSummary();
    final settings = await _repo.fetchSettings();
    final section = state.section;

    switch (section) {
      case ContinuityHubSection.dashboard:
      case ContinuityHubSection.disasterRecovery:
        state = state.copyWith(
          summary: summary,
          settings: settings,
          health: _repo.healthChecks(),
          backups: await _repo.fetchBackups(limit: 10),
        );
        return;
      case ContinuityHubSection.firestoreBackup:
      case ContinuityHubSection.storageBackup:
      case ContinuityHubSection.configBackup:
      case ContinuityHubSection.backupHistory:
        final backups =
            await _repo.fetchBackups(filters: state.filters, limit: 80);
        state = state.copyWith(
          summary: summary,
          backups: backups,
          settings: settings,
        );
        return;
      case ContinuityHubSection.restoreCenter:
        state = state.copyWith(
          summary: summary,
          restores: await _repo.fetchRestores(),
          backups: await _repo.fetchBackups(limit: 30),
        );
        return;
      case ContinuityHubSection.recoveryPlans:
        state = state.copyWith(
          summary: summary,
          plans: await _repo.fetchPlans(),
        );
        return;
      case ContinuityHubSection.migrationCenter:
      case ContinuityHubSection.importCenter:
      case ContinuityHubSection.exportCenter:
        state = state.copyWith(
          summary: summary,
          migrations: await _repo.fetchMigrations(),
        );
        return;
      case ContinuityHubSection.healthVerification:
        state = state.copyWith(
          summary: summary,
          health: _repo.healthChecks(),
        );
        return;
      case ContinuityHubSection.timeline:
        state = state.copyWith(
          summary: summary,
          timeline: await _repo.fetchTimeline(),
        );
        return;
    }
  }

  Future<String?> queueBackup(ContinuityBackupType type) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) {
      state = state.copyWith(error: 'Super Admin required');
      return null;
    }
    final id = await _repo.queueBackup(
      actor: actor,
      type: type,
      environment: AdminEnvConfig.environment.wireValue,
    );
    await refresh(force: true);
    return id;
  }

  Future<void> validateBackup(ManagedContinuityBackup backup, bool ok) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.markBackupValidated(
      actor: actor,
      backup: backup,
      integrityOk: ok,
    );
    await refresh(force: true);
  }

  Future<void> archiveBackup(ManagedContinuityBackup backup) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.archiveBackup(actor: actor, backup: backup);
    await refresh(force: true);
  }

  Future<String?> requestRestorePreview({
    required String backupId,
    required ContinuityRestoreScope scope,
    required String reason,
  }) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return null;
    final id = await _repo.requestRestorePreview(
      actor: actor,
      backupId: backupId,
      scope: scope,
      reason: reason,
      environment: AdminEnvConfig.environment.wireValue,
    );
    await refresh(force: true);
    return id;
  }

  Future<void> queueMigrationDryRun({
    required ContinuityMigrationKind kind,
    required String title,
  }) async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.queueMigrationDryRun(actor: actor, kind: kind, title: title);
    await refresh(force: true);
  }

  Future<void> recordHealth() async {
    final actor = _actor;
    if (actor == null || !isSuperAdmin) return;
    await _repo.recordHealthCheck(actor: actor);
    await refresh(force: true);
  }
}

final continuityHubControllerProvider =
    StateNotifierProvider<ContinuityHubController, ContinuityHubState>((ref) {
  return ContinuityHubController(ref);
});
