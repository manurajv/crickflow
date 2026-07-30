import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/broadcasts_repository.dart';
import '../models/broadcast_enums.dart';
import '../models/broadcast_filters.dart';
import '../models/managed_broadcast.dart';

final broadcastsRepositoryProvider = Provider<BroadcastsRepository>((ref) {
  return BroadcastsRepository();
});

class BroadcastsListState {
  const BroadcastsListState({
    this.broadcasts = const [],
    this.filters = BroadcastListFilters.empty,
    this.sort = const BroadcastSort(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.summary = const BroadcastSummaryStats(),
    this.liveMonitor = false,
  });

  final List<ManagedBroadcast> broadcasts;
  final BroadcastListFilters filters;
  final BroadcastSort sort;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final BroadcastSummaryStats summary;
  final bool liveMonitor;

  BroadcastsListState copyWith({
    List<ManagedBroadcast>? broadcasts,
    BroadcastListFilters? filters,
    BroadcastSort? sort,
    int? pageSize,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? selectedId,
    bool clearSelection = false,
    BroadcastSummaryStats? summary,
    bool? liveMonitor,
  }) {
    return BroadcastsListState(
      broadcasts: broadcasts ?? this.broadcasts,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      summary: summary ?? this.summary,
      liveMonitor: liveMonitor ?? this.liveMonitor,
    );
  }
}

class BroadcastsListController extends StateNotifier<BroadcastsListState> {
  BroadcastsListController(this._ref)
      : super(const BroadcastsListState(isLoading: true)) {
    Future(() {
      if (mounted) refresh();
    });
  }

  final Ref _ref;
  BroadcastsRepository get _repo => _ref.read(broadcastsRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
      broadcasts: const [],
    );
    try {
      final summary = await _repo.fetchSummary(
        appType: _appType,
        actor: _actor,
      );
      final filters = state.liveMonitor
          ? state.filters.copyWith(liveOnly: true)
          : state.filters;
      final page = await _repo.fetchPage(
        appType: _appType,
        actor: _actor,
        filters: filters,
        sort: state.sort,
        limit: state.pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(
        broadcasts: page.broadcasts,
        hasMore: page.hasMore,
        cursor: page.cursor,
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
      final filters = state.liveMonitor
          ? state.filters.copyWith(liveOnly: true)
          : state.filters;
      final page = await _repo.fetchPage(
        appType: _appType,
        actor: _actor,
        filters: filters,
        sort: state.sort,
        startAfter: state.cursor,
        limit: state.pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(
        broadcasts: [...state.broadcasts, ...page.broadcasts],
        hasMore: page.hasMore,
        cursor: page.cursor,
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

  Future<void> applyFilters(BroadcastListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> setSort(BroadcastSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field));
    await refresh();
  }

  void selectBroadcast(String? id) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedId: id);
    }
  }

  void toggleLiveMonitor() {
    state = state.copyWith(liveMonitor: !state.liveMonitor);
    refresh();
  }

  Future<void> setFeatured(
    ManagedBroadcast b,
    bool featured, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setFeatured(
      target: b,
      featured: featured,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> softDelete(ManagedBroadcast b, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.softDelete(target: b, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> restore(ManagedBroadcast b, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.restore(target: b, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> archive(ManagedBroadcast b, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.archive(target: b, actor: actor, reason: reason);
    await refresh();
  }
}

final broadcastsListControllerProvider = StateNotifierProvider.autoDispose<
    BroadcastsListController, BroadcastsListState>((ref) {
  return BroadcastsListController(ref);
});

final selectedManagedBroadcastProvider =
    StreamProvider.autoDispose<ManagedBroadcast?>((ref) {
  final id =
      ref.watch(broadcastsListControllerProvider.select((s) => s.selectedId));
  if (id == null) return Stream.value(null);
  return ref.watch(broadcastsRepositoryProvider).watchById(
        id,
        appType: ref.watch(adminAppTypeProvider),
        actor: ref.watch(adminSessionProvider).adminUser,
      );
});

final selectedBroadcastTimelineProvider =
    FutureProvider.autoDispose<List<BroadcastTimelineItem>>((ref) async {
  final b = await ref.watch(selectedManagedBroadcastProvider.future);
  if (b == null) return const [];
  return ref.watch(broadcastsRepositoryProvider).fetchTimeline(b);
});

final selectedBroadcastAuditProvider =
    FutureProvider.autoDispose<List<AdminAuditLogEntry>>((ref) async {
  final b = await ref.watch(selectedManagedBroadcastProvider.future);
  if (b == null) return const [];
  return ref.watch(broadcastsRepositoryProvider).fetchAuditForBroadcast(b.id);
});
