import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/grounds_repository.dart';
import '../models/ground_enums.dart';
import '../models/ground_filters.dart';
import '../models/managed_ground.dart';

final groundsRepositoryProvider = Provider<GroundsRepository>((ref) {
  return GroundsRepository();
});

class GroundsListState {
  const GroundsListState({
    this.grounds = const [],
    this.filters = GroundListFilters.empty,
    this.sort = const GroundSort(),
    this.pageSize = 25,
    this.hasMore = false,
    this.pageCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.summary = const GroundSummaryStats(),
    this.mapView = false,
  });

  final List<ManagedGround> grounds;
  final GroundListFilters filters;
  final GroundSort sort;
  final int pageSize;
  final bool hasMore;
  final String? pageCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final GroundSummaryStats summary;
  final bool mapView;

  GroundsListState copyWith({
    List<ManagedGround>? grounds,
    GroundListFilters? filters,
    GroundSort? sort,
    int? pageSize,
    bool? hasMore,
    String? pageCursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? selectedId,
    bool clearSelection = false,
    GroundSummaryStats? summary,
    bool? mapView,
  }) {
    return GroundsListState(
      grounds: grounds ?? this.grounds,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      pageCursor: clearCursor ? null : (pageCursor ?? this.pageCursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      summary: summary ?? this.summary,
      mapView: mapView ?? this.mapView,
    );
  }
}

class GroundsListController extends StateNotifier<GroundsListState> {
  GroundsListController(this._ref)
      : super(const GroundsListState(isLoading: true)) {
    Future(() {
      if (mounted) refresh();
    });
  }

  final Ref _ref;
  GroundsRepository get _repo => _ref.read(groundsRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
      grounds: const [],
    );
    try {
      final summary = await _repo.fetchSummary(
        appType: _appType,
        actor: _actor,
      );
      final page = await _repo.fetchPage(
        appType: _appType,
        actor: _actor,
        filters: state.filters,
        sort: state.sort,
        limit: state.pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(
        grounds: page.grounds,
        hasMore: page.hasMore,
        pageCursor: page.pageCursor,
        isLoading: false,
        summary: summary,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repo.fetchPage(
        appType: _appType,
        actor: _actor,
        filters: state.filters,
        sort: state.sort,
        startAfterId: state.pageCursor,
        limit: state.pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(
        grounds: [...state.grounds, ...page.grounds],
        hasMore: page.hasMore,
        pageCursor: page.pageCursor,
        isLoadingMore: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  Future<void> applyFilters(GroundListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> setSort(GroundSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field));
    await refresh();
  }

  void selectGround(String? id) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedId: id);
    }
  }

  void toggleMapView() {
    state = state.copyWith(mapView: !state.mapView);
  }

  Future<String?> createGround(ManagedGround draft, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return null;
    final id = await _repo.createGround(
      draft: draft,
      actor: actor,
      reason: reason,
    );
    await refresh();
    return id;
  }

  Future<void> setFeatured(
    ManagedGround g,
    bool featured, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setFeatured(
      target: g,
      featured: featured,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> setVerified(
    ManagedGround g,
    bool verified, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setVerified(
      target: g,
      verified: verified,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> setStatus(
    ManagedGround g,
    ManagedGroundStatus status, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setStatus(
      target: g,
      status: status,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> softDelete(ManagedGround g, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.softDelete(target: g, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> restore(ManagedGround g, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.restore(target: g, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> archive(ManagedGround g, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.archive(target: g, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> saveBasicInfo(
    ManagedGround g, {
    String? name,
    String? description,
    String? address,
    String? city,
    String? stateProvince,
    String? country,
    String? pinCode,
    String? contactPerson,
    String? contactNumber,
    String? email,
    ManagedGroundType? groundType,
    ManagedGroundPitchType? pitchType,
    ManagedGroundAvailability? availability,
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.updateBasicInfo(
      target: g,
      actor: actor,
      name: name,
      description: description,
      address: address,
      city: city,
      stateProvince: stateProvince,
      country: country,
      pinCode: pinCode,
      contactPerson: contactPerson,
      contactNumber: contactNumber,
      email: email,
      groundType: groundType,
      pitchType: pitchType,
      availability: availability,
      reason: reason,
    );
    await refresh();
  }
}

final groundsListControllerProvider =
    StateNotifierProvider.autoDispose<GroundsListController, GroundsListState>(
        (ref) {
  return GroundsListController(ref);
});

final selectedManagedGroundProvider =
    FutureProvider.autoDispose<ManagedGround?>((ref) async {
  final id =
      ref.watch(groundsListControllerProvider.select((s) => s.selectedId));
  final fromList = ref.watch(
    groundsListControllerProvider.select((s) {
      if (id == null) return null;
      for (final g in s.grounds) {
        if (g.id == id) return g;
      }
      return null;
    }),
  );
  if (id == null) return null;
  final fetched = await ref.watch(groundsRepositoryProvider).fetchById(
        id,
        appType: ref.watch(adminAppTypeProvider),
        actor: ref.watch(adminSessionProvider).adminUser,
      );
  return fetched ?? fromList;
});

final selectedGroundAuditProvider =
    FutureProvider.autoDispose<List<AdminAuditLogEntry>>((ref) async {
  final ground = await ref.watch(selectedManagedGroundProvider.future);
  if (ground == null) return const [];
  return ref.watch(groundsRepositoryProvider).fetchAuditForGround(ground.id);
});
