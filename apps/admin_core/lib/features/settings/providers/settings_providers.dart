import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/settings_repository.dart';
import '../models/platform_settings.dart';
import '../models/settings_enums.dart';

export '../models/settings_enums.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

class SettingsHubState {
  const SettingsHubState({
    this.section = SettingsHubSection.dashboard,
    this.snapshot = const SettingsHubSnapshot(),
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.canWrite = false,
    this.bootstrapped = false,
  });

  final SettingsHubSection section;
  final SettingsHubSnapshot snapshot;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final bool canWrite;
  final bool bootstrapped;

  SettingsHubState copyWith({
    SettingsHubSection? section,
    SettingsHubSnapshot? snapshot,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
    bool? canWrite,
    bool? bootstrapped,
  }) {
    return SettingsHubState(
      section: section ?? this.section,
      snapshot: snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      canWrite: canWrite ?? this.canWrite,
      bootstrapped: bootstrapped ?? this.bootstrapped,
    );
  }
}

class SettingsHubController extends StateNotifier<SettingsHubState> {
  SettingsHubController(this._ref) : super(const SettingsHubState());

  final Ref _ref;

  SettingsRepository get _repo => _ref.read(settingsRepositoryProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  bool get _isSuperAdmin {
    final appType = _ref.read(adminAppTypeProvider);
    if (appType == AdminAppType.superAdmin) return true;
    final role = _ref.read(adminSessionProvider).adminUser?.roleId;
    return role == 'superAdmin';
  }

  Future<void> ensureBootstrapped({
    SettingsHubSection? initialSection,
  }) async {
    if (state.bootstrapped) {
      if (initialSection != null && state.section != initialSection) {
        state = state.copyWith(section: initialSection);
      }
      return;
    }
    if (initialSection != null) {
      state = state.copyWith(
        section: initialSection,
        canWrite: _isSuperAdmin,
      );
    } else {
      state = state.copyWith(canWrite: _isSuperAdmin);
    }
    await refresh();
    if (mounted) {
      state = state.copyWith(bootstrapped: true, canWrite: _isSuperAdmin);
    }
  }

  void setSection(SettingsHubSection section) {
    state = state.copyWith(section: section);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final snap = await _repo.fetchHubSnapshot();
      if (!mounted) return;
      state = state.copyWith(
        snapshot: snap,
        isLoading: false,
        canWrite: _isSuperAdmin,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _requireWrite() {
    if (!_isSuperAdmin) {
      throw StateError(
        'Only Super Admin can modify platform settings.',
      );
    }
  }

  Future<void> saveGeneral(PlatformGeneralSettings general, {String? reason}) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final draft = state.snapshot.settings.copyWith(general: general);
      await _repo.saveSettings(
        draft: draft,
        actor: actor,
        reason: reason,
        section: 'general',
      );
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> saveBranding(PlatformBrandingSettings branding, {String? reason}) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final draft = state.snapshot.settings.copyWith(branding: branding);
      await _repo.saveSettings(
        draft: draft,
        actor: actor,
        reason: reason,
        section: 'branding',
      );
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> saveContact(PlatformContactSettings contact, {String? reason}) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final draft = state.snapshot.settings.copyWith(contact: contact);
      await _repo.saveSettings(
        draft: draft,
        actor: actor,
        reason: reason,
        section: 'contact',
      );
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> saveSocial(PlatformSocialSettings social, {String? reason}) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final draft = state.snapshot.settings.copyWith(social: social);
      await _repo.saveSettings(
        draft: draft,
        actor: actor,
        reason: reason,
        section: 'social',
      );
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> saveSystemPrefs(PlatformSystemPrefs prefs, {String? reason}) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final draft = state.snapshot.settings.copyWith(systemPrefs: prefs);
      await _repo.saveSettings(
        draft: draft,
        actor: actor,
        reason: reason,
        section: 'system_prefs',
      );
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> setFeatureFlag(
    FeatureFlagKey key,
    bool enabled, {
    String? reason,
  }) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.setFeatureFlag(
        key: key,
        enabled: enabled,
        actor: actor,
        reason: reason,
      );
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> upsertRemoteConfig(
    ManagedRemoteConfigEntry entry, {
    String? reason,
  }) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.upsertRemoteConfig(
        entry: entry,
        actor: actor,
        reason: reason,
      );
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deleteRemoteConfig(String id, {String? reason}) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.deleteRemoteConfig(id: id, actor: actor, reason: reason);
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> setRemoteConfigEnabled(
    String id,
    bool enabled, {
    String? reason,
  }) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    await _repo.setRemoteConfigEnabled(
      id: id,
      enabled: enabled,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> createAppVersion(
    ManagedAppVersion draft, {
    String? reason,
  }) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.createAppVersion(
        draft: draft,
        actor: actor,
        reason: reason,
      );
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> saveMaintenance(
    MaintenanceConfig config, {
    String? reason,
  }) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.saveMaintenance(
        config: config,
        actor: actor,
        reason: reason,
      );
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> saveCmsPage(ManagedCmsPage page, {String? reason}) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.saveCmsPage(page: page, actor: actor, reason: reason);
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> saveLegalPage(ManagedLegalPage page, {String? reason}) async {
    _requireWrite();
    final actor = _actor;
    if (actor == null) return;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _repo.saveLegalPage(page: page, actor: actor, reason: reason);
      await refresh();
    } catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }
}

final settingsHubControllerProvider =
    StateNotifierProvider.autoDispose<SettingsHubController, SettingsHubState>(
        (ref) {
  return SettingsHubController(ref);
});

final settingsAuditProvider =
    FutureProvider.autoDispose<List<AdminAuditLogEntry>>((ref) {
  return ref.watch(settingsRepositoryProvider).fetchSettingsAudit();
});
