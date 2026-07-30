import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/teams_repository.dart';
import '../models/managed_team.dart';
import '../models/team_enums.dart';
import '../models/team_filters.dart';

final teamsRepositoryProvider = Provider<TeamsRepository>((ref) {
  return TeamsRepository();
});

class TeamsListState {
  const TeamsListState({
    this.teams = const [],
    this.filters = TeamListFilters.empty,
    this.sort = const TeamSort(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.summary = const TeamSummaryStats(),
  });

  final List<ManagedTeam> teams;
  final TeamListFilters filters;
  final TeamSort sort;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final TeamSummaryStats summary;

  TeamsListState copyWith({
    List<ManagedTeam>? teams,
    TeamListFilters? filters,
    TeamSort? sort,
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
    TeamSummaryStats? summary,
  }) {
    return TeamsListState(
      teams: teams ?? this.teams,
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

class TeamsListController extends StateNotifier<TeamsListState> {
  TeamsListController(this._ref)
      : super(const TeamsListState(isLoading: true)) {
    Future(() {
      if (mounted) refresh();
    });
  }

  final Ref _ref;
  TeamsRepository get _repo => _ref.read(teamsRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
      teams: const [],
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
        teams: page.teams,
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
        teams: [...state.teams, ...page.teams],
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

  Future<void> applyFilters(TeamListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> setSort(TeamSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field));
    await refresh();
  }

  void selectTeam(String? id) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedId: id);
    }
  }

  Future<void> setFeatured(ManagedTeam t, bool featured, {String? reason}) async {
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

  Future<void> setVerified(ManagedTeam t, bool verified, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setVerified(
      target: t,
      verified: verified,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> setStatus(
    ManagedTeam t,
    ManagedTeamStatus status, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setStatus(
      target: t,
      status: status,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> softDelete(ManagedTeam t, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.softDelete(target: t, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> restore(ManagedTeam t, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.restore(target: t, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> archive(ManagedTeam t, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.archive(target: t, actor: actor, reason: reason);
    await refresh();
  }

  Future<void> saveBasicInfo(
    ManagedTeam t, {
    String? name,
    String? coachName,
    String? contactNumber,
    ManagedTeamCategory? category,
    ManagedTeamBallType? ballType,
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.updateBasicInfo(
      target: t,
      actor: actor,
      name: name,
      coachName: coachName,
      contactNumber: contactNumber,
      category: category,
      ballType: ballType,
      reason: reason,
    );
    await refresh();
  }
}

final teamsListControllerProvider =
    StateNotifierProvider.autoDispose<TeamsListController, TeamsListState>(
        (ref) {
  return TeamsListController(ref);
});

final selectedManagedTeamProvider =
    FutureProvider.autoDispose<ManagedTeam?>((ref) async {
  final id =
      ref.watch(teamsListControllerProvider.select((s) => s.selectedId));
  if (id == null) return null;
  return ref.watch(teamsRepositoryProvider).fetchById(
        id,
        appType: ref.watch(adminAppTypeProvider),
        actor: ref.watch(adminSessionProvider).adminUser,
      );
});

final selectedTeamAuditProvider =
    FutureProvider.autoDispose<List<AdminAuditLogEntry>>((ref) async {
  final team = await ref.watch(selectedManagedTeamProvider.future);
  if (team == null) return const [];
  return ref.watch(teamsRepositoryProvider).fetchAuditForTeam(team.id);
});
