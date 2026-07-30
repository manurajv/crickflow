import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/analytics_repository.dart';
import '../models/analytics_enums.dart';
import '../models/analytics_filters.dart';
import '../models/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository();
});

class AnalyticsHubState {
  const AnalyticsHubState({
    this.section = AnalyticsHubSection.overview,
    this.filters = AnalyticsFilters.empty,
    this.snapshot,
    this.isLoading = false,
    this.error,
    this.reportKind = AnalyticsReportKind.monthly,
  });

  final AnalyticsHubSection section;
  final AnalyticsFilters filters;
  final AnalyticsSnapshot? snapshot;
  final bool isLoading;
  final String? error;
  final AnalyticsReportKind reportKind;

  AnalyticsHubState copyWith({
    AnalyticsHubSection? section,
    AnalyticsFilters? filters,
    AnalyticsSnapshot? snapshot,
    bool clearSnapshot = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
    AnalyticsReportKind? reportKind,
  }) {
    return AnalyticsHubState(
      section: section ?? this.section,
      filters: filters ?? this.filters,
      snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      reportKind: reportKind ?? this.reportKind,
    );
  }
}

class AnalyticsHubController extends StateNotifier<AnalyticsHubState> {
  AnalyticsHubController(this._ref) : super(const AnalyticsHubState());

  final Ref _ref;
  bool _bootstrapped = false;

  AnalyticsRepository get _repo => _ref.read(analyticsRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> ensureBootstrapped() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final snapshot = await _repo.fetchSnapshot(
        appType: _appType,
        actor: _actor,
        filters: state.filters,
        forceRefresh: force,
      );
      if (!mounted) return;
      state = state.copyWith(snapshot: snapshot, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSection(AnalyticsHubSection section) async {
    state = state.copyWith(section: section);
    if (state.snapshot == null) await refresh();
  }

  Future<void> applyFilters(AnalyticsFilters filters) async {
    _repo.clearCache();
    state = state.copyWith(filters: filters);
    await refresh(force: true);
  }

  Future<void> setPeriod(AnalyticsPeriod period) async {
    await applyFilters(state.filters.copyWith(period: period));
  }

  void setReportKind(AnalyticsReportKind kind) {
    state = state.copyWith(reportKind: kind);
  }

  String exportCsv() {
    final snap = state.snapshot;
    if (snap == null) return '';
    return _repo.buildCsvExport(snap);
  }

  AnalyticsReportPreview? buildReportPreview() {
    final snap = state.snapshot;
    if (snap == null) return null;
    return AnalyticsReportPreview(
      kind: state.reportKind,
      title: state.reportKind.label,
      summaryLines: _repo.buildReportLines(snap),
      generatedAt: DateTime.now(),
    );
  }
}

final analyticsHubControllerProvider =
    StateNotifierProvider.autoDispose<AnalyticsHubController, AnalyticsHubState>(
        (ref) {
  return AnalyticsHubController(ref);
});
