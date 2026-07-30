import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/matches_repository.dart';
import '../models/match_enums.dart';
import '../models/match_filters.dart';
import '../models/managed_match.dart';

final matchesRepositoryProvider = Provider<MatchesRepository>((ref) => MatchesRepository());

class MatchesListState {
  const MatchesListState({this.matches = const [], this.filters = MatchListFilters.empty, this.sort = const MatchSort(), this.pageSize = 25, this.hasMore = false, this.cursor, this.isLoading = false, this.isLoadingMore = false, this.error, this.selectedId, this.summary = const MatchSummaryStats(), this.commentaryQuery = ''});
  final List<ManagedMatch> matches;
  final MatchListFilters filters;
  final MatchSort sort;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final MatchSummaryStats summary;
  final String commentaryQuery;
  MatchesListState copyWith({List<ManagedMatch>? matches, MatchListFilters? filters, MatchSort? sort, int? pageSize, bool? hasMore, DocumentSnapshot<Map<String, dynamic>>? cursor, bool clearCursor = false, bool? isLoading, bool? isLoadingMore, String? error, bool clearError = false, String? selectedId, bool clearSelection = false, MatchSummaryStats? summary, String? commentaryQuery}) => MatchesListState(matches: matches ?? this.matches, filters: filters ?? this.filters, sort: sort ?? this.sort, pageSize: pageSize ?? this.pageSize, hasMore: hasMore ?? this.hasMore, cursor: clearCursor ? null : (cursor ?? this.cursor), isLoading: isLoading ?? this.isLoading, isLoadingMore: isLoadingMore ?? this.isLoadingMore, error: clearError ? null : (error ?? this.error), selectedId: clearSelection ? null : (selectedId ?? this.selectedId), summary: summary ?? this.summary, commentaryQuery: commentaryQuery ?? this.commentaryQuery);
}

class MatchesListController extends StateNotifier<MatchesListState> {
  MatchesListController(this._ref) : super(const MatchesListState(isLoading: true)) { Future(() { if (mounted) refresh(); }); }
  final Ref _ref;
  MatchesRepository get _repo => _ref.read(matchesRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, clearCursor: true, matches: const []);
    try {
      final summary = await _repo.fetchSummary(appType: _appType, actor: _actor);
      final page = await _repo.fetchPage(appType: _appType, actor: _actor, filters: state.filters, sort: state.sort, limit: state.pageSize);
      if (!mounted) return;
      state = state.copyWith(matches: page.matches, hasMore: page.hasMore, cursor: page.cursor, isLoading: false, summary: summary);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repo.fetchPage(appType: _appType, actor: _actor, filters: state.filters, sort: state.sort, startAfter: state.cursor, limit: state.pageSize);
      if (!mounted) return;
      state = state.copyWith(matches: [...state.matches, ...page.matches], hasMore: page.hasMore, cursor: page.cursor, isLoadingMore: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void setQuery(String query) => state = state.copyWith(filters: state.filters.copyWith(query: query));
  Future<void> applyFilters(MatchListFilters filters) async { state = state.copyWith(filters: filters); await refresh(); }
  Future<void> setSort(MatchSortField field) async { state = state.copyWith(sort: state.sort.toggle(field)); await refresh(); }
  void selectMatch(String? id) => state = id == null ? state.copyWith(clearSelection: true) : state.copyWith(selectedId: id);
  void setCommentaryQuery(String query) => state = state.copyWith(commentaryQuery: query);

  Future<void> setFeatured(ManagedMatch m, bool featured, {String? reason}) async { final actor = _actor; if (actor == null) return; await _repo.setFeatured(target: m, featured: featured, actor: actor, reason: reason); await refresh(); }
  Future<void> setPaused(ManagedMatch m, bool paused, {String? reason}) async { final actor = _actor; if (actor == null) return; await _repo.setPaused(target: m, paused: paused, actor: actor, reason: reason); await refresh(); }
  Future<void> setStatus(ManagedMatch m, ManagedMatchStatus status, {String? reason}) async { final actor = _actor; if (actor == null) return; await _repo.setStatus(target: m, status: status, actor: actor, reason: reason); await refresh(); }
  Future<void> softDelete(ManagedMatch m, {String? reason}) async { final actor = _actor; if (actor == null) return; await _repo.softDelete(target: m, actor: actor, reason: reason); await refresh(); }
  Future<void> restore(ManagedMatch m, {String? reason}) async { final actor = _actor; if (actor == null) return; await _repo.restore(target: m, actor: actor, reason: reason); await refresh(); }
  Future<void> archive(ManagedMatch m, {String? reason}) async { final actor = _actor; if (actor == null) return; await _repo.archive(target: m, actor: actor, reason: reason); await refresh(); }
  Future<void> saveMetadata(ManagedMatch m, {String? title, String? venue, String? reason}) async { final actor = _actor; if (actor == null) return; await _repo.updateMetadata(target: m, actor: actor, title: title, venue: venue, reason: reason); await refresh(); }
}

final matchesListControllerProvider = StateNotifierProvider.autoDispose<MatchesListController, MatchesListState>((ref) => MatchesListController(ref));

final selectedManagedMatchProvider = StreamProvider.autoDispose<ManagedMatch?>((ref) {
  final id = ref.watch(matchesListControllerProvider.select((s) => s.selectedId));
  if (id == null) return Stream.value(null);
  return ref.watch(matchesRepositoryProvider).watchById(id, appType: ref.watch(adminAppTypeProvider), actor: ref.watch(adminSessionProvider).adminUser);
});

final selectedMatchCommentaryProvider = FutureProvider.autoDispose<List<MatchCommentaryItem>>((ref) async {
  final match = await ref.watch(selectedManagedMatchProvider.future);
  if (match == null) return const [];
  final query = ref.watch(matchesListControllerProvider.select((s) => s.commentaryQuery));
  return ref.watch(matchesRepositoryProvider).fetchCommentary(match.id, query: query);
});

final selectedMatchTimelineProvider = FutureProvider.autoDispose<List<MatchTimelineItem>>((ref) async {
  final match = await ref.watch(selectedManagedMatchProvider.future);
  if (match == null) return const [];
  return ref.watch(matchesRepositoryProvider).fetchTimeline(match);
});

final selectedMatchAuditProvider = FutureProvider.autoDispose<List<AdminAuditLogEntry>>((ref) async {
  final match = await ref.watch(selectedManagedMatchProvider.future);
  if (match == null) return const [];
  return ref.watch(matchesRepositoryProvider).fetchAuditForMatch(match.id);
});
