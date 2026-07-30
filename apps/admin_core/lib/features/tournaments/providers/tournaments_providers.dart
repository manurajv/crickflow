import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/tournaments_repository.dart';
import '../models/managed_tournament.dart';
import '../models/tournament_enums.dart';
import '../models/tournament_filters.dart';

final tournamentsRepositoryProvider = Provider<TournamentsRepository>((ref) {
  return TournamentsRepository();
});

class TournamentsListState {
  const TournamentsListState({
    this.tournaments = const [],
    this.filters = TournamentListFilters.empty,
    this.sort = const TournamentSort(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.summary = const TournamentSummaryStats(),
  });

  final List<ManagedTournament> tournaments;
  final TournamentListFilters filters;
  final TournamentSort sort;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final TournamentSummaryStats summary;

  TournamentsListState copyWith({
    List<ManagedTournament>? tournaments,
    TournamentListFilters? filters,
    TournamentSort? sort,
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
    TournamentSummaryStats? summary,
  }) {
    return TournamentsListState(
      tournaments: tournaments ?? this.tournaments,
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
    );
  }
}

class TournamentsListController extends StateNotifier<TournamentsListState> {
  TournamentsListController(this._ref)
      : super(const TournamentsListState(isLoading: true)) {
    Future(() {
      if (mounted) refresh();
    });
  }

  final Ref _ref;
  TournamentsRepository get _repo => _ref.read(tournamentsRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
      tournaments: const [],
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
        tournaments: page.tournaments,
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
      final page = await _repo.fetchPage(
        appType: _appType,
        actor: _actor,
        filters: state.filters,
        sort: state.sort,
        startAfter: state.cursor,
        limit: state.pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(
        tournaments: [...state.tournaments, ...page.tournaments],
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

  Future<void> applyFilters(TournamentListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> setSort(TournamentSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field));
    await refresh();
  }

  void selectTournament(String? id) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedId: id);
    }
  }

  Future<void> setFeatured(ManagedTournament t, bool featured,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setFeatured(
      target: t,
      featured: featured,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> setApproval(
    ManagedTournament t,
    AdminTournamentApproval approval, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setApproval(
      target: t,
      approval: approval,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> cancel(ManagedTournament t, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.cancelTournament(target: t, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> softDelete(ManagedTournament t, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.softDelete(target: t, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> restore(ManagedTournament t, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.restore(target: t, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> archive(ManagedTournament t, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.archive(target: t, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> saveBasicInfo(
    ManagedTournament t, {
    String? name,
    String? description,
    String? winningPrize,
    double? entryFee,
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.updateBasicInfo(
      target: t,
      actor: actor,
      name: name,
      description: description,
      winningPrize: winningPrize,
      entryFee: entryFee,
      reason: reason,
    );
    await refresh();
  }
}

final tournamentsListControllerProvider = StateNotifierProvider.autoDispose<
    TournamentsListController, TournamentsListState>((ref) {
  return TournamentsListController(ref);
});

final selectedManagedTournamentProvider =
    FutureProvider.autoDispose<ManagedTournament?>((ref) async {
  final id =
      ref.watch(tournamentsListControllerProvider.select((s) => s.selectedId));
  if (id == null) return null;
  return ref.watch(tournamentsRepositoryProvider).fetchById(
        id,
        appType: ref.watch(adminAppTypeProvider),
        actor: ref.watch(adminSessionProvider).adminUser,
      );
});
