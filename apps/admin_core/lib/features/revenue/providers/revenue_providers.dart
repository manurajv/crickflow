import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/revenue_repository.dart';
import '../models/managed_revenue.dart';
import '../models/revenue_enums.dart';
import '../models/revenue_filters.dart';

final revenueRepositoryProvider = Provider<RevenueRepository>((ref) {
  return RevenueRepository();
});

class RevenueHubState {
  const RevenueHubState({
    this.section = RevenueHubSection.dashboard,
    this.filters = RevenueFilters.empty,
    this.summary = const RevenueSummary(),
    this.entries = const [],
    this.integrations = const [],
    this.isLoading = false,
    this.error,
    this.bootstrapped = false,
  });

  final RevenueHubSection section;
  final RevenueFilters filters;
  final RevenueSummary summary;
  final List<ManagedRevenueEntry> entries;
  final List<RevenueIntegrationCard> integrations;
  final bool isLoading;
  final String? error;
  final bool bootstrapped;

  RevenueHubState copyWith({
    RevenueHubSection? section,
    RevenueFilters? filters,
    RevenueSummary? summary,
    List<ManagedRevenueEntry>? entries,
    List<RevenueIntegrationCard>? integrations,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? bootstrapped,
  }) {
    return RevenueHubState(
      section: section ?? this.section,
      filters: filters ?? this.filters,
      summary: summary ?? this.summary,
      entries: entries ?? this.entries,
      integrations: integrations ?? this.integrations,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      bootstrapped: bootstrapped ?? this.bootstrapped,
    );
  }
}

class RevenueHubController extends StateNotifier<RevenueHubState> {
  RevenueHubController(this._ref) : super(const RevenueHubState());

  final Ref _ref;
  RevenueRepository get _repo => _ref.read(revenueRepositoryProvider);
  bool get isSuperAdmin =>
      _ref.read(adminAppTypeProvider) == AdminAppType.superAdmin;

  Future<void> ensureBootstrapped() async {
    if (state.bootstrapped) return;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    if (!isSuperAdmin) {
      state = state.copyWith(
        error: 'Revenue Center is Super Admin only',
        isLoading: false,
        bootstrapped: true,
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final summary = await _repo.fetchSummary();
      final entries = await _repo.fetchEntries(filters: state.filters);
      if (!mounted) return;
      state = state.copyWith(
        summary: summary,
        entries: entries,
        integrations: _repo.integrations(),
        isLoading: false,
        bootstrapped: true,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSection(RevenueHubSection section) async {
    state = state.copyWith(section: section);
    await refresh();
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  Future<void> applyFilters(RevenueFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }
}

final revenueHubControllerProvider =
    StateNotifierProvider<RevenueHubController, RevenueHubState>((ref) {
  return RevenueHubController(ref);
});
