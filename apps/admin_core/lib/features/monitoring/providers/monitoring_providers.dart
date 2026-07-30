import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/monitoring_repository.dart';
import '../models/monitoring_enums.dart';
import '../models/monitoring_filters.dart';
import '../models/monitoring_models.dart';

final monitoringRepositoryProvider = Provider<MonitoringRepository>((ref) {
  return MonitoringRepository();
});

class MonitoringHubState {
  const MonitoringHubState({
    this.section = MonitoringHubSection.overview,
    this.filters = MonitoringFilters.empty,
    this.snapshot,
    this.isLoading = false,
    this.error,
  });

  final MonitoringHubSection section;
  final MonitoringFilters filters;
  final MonitoringSnapshot? snapshot;
  final bool isLoading;
  final String? error;

  List<MonitoringErrorItem> filteredErrors(MonitoringRepository repo) {
    final snap = snapshot;
    if (snap == null) return const [];
    return repo.filterErrors(snap.errors, filters);
  }

  MonitoringHubState copyWith({
    MonitoringHubSection? section,
    MonitoringFilters? filters,
    MonitoringSnapshot? snapshot,
    bool clearSnapshot = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MonitoringHubState(
      section: section ?? this.section,
      filters: filters ?? this.filters,
      snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MonitoringHubController extends StateNotifier<MonitoringHubState> {
  MonitoringHubController(this._ref) : super(const MonitoringHubState());

  final Ref _ref;
  bool _bootstrapped = false;

  MonitoringRepository get _repo => _ref.read(monitoringRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  /// Org Admin: forced org scope. Super Admin: platform-wide (no org filter).
  String? get _organizationScope {
    if (_appType == AdminAppType.superAdmin) return null;
    final id = _actor?.organizationId;
    return (id != null && id.isNotEmpty) ? id : '__missing_org__';
  }

  Future<void> ensureBootstrapped() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final snapshot = await _repo.fetchSnapshot(
        organizationId: _organizationScope,
        force: force,
      );
      if (!mounted) return;
      state = state.copyWith(snapshot: snapshot, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSection(MonitoringHubSection section) async {
    state = state.copyWith(section: section);
    if (state.snapshot == null) await refresh();
  }

  Future<void> applyFilters(MonitoringFilters filters) async {
    state = state.copyWith(filters: filters);
    // Filters apply client-side to errors/search; refresh only if empty.
    if (state.snapshot == null) await refresh(force: true);
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }
}

final monitoringHubControllerProvider = StateNotifierProvider.autoDispose<
    MonitoringHubController, MonitoringHubState>((ref) {
  return MonitoringHubController(ref);
});
