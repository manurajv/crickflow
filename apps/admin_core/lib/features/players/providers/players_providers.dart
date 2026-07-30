import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../data/players_repository.dart';
import '../models/managed_player.dart';
import '../models/player_enums.dart';
import '../models/player_filters.dart';

final playersRepositoryProvider = Provider<PlayersRepository>((ref) {
  return PlayersRepository();
});

class PlayersListState {
  const PlayersListState({
    this.players = const [],
    this.filters = PlayerListFilters.empty,
    this.sort = const PlayerSort(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedId,
    this.summary = const PlayerSummaryStats(),
  });

  final List<ManagedPlayer> players;
  final PlayerListFilters filters;
  final PlayerSort sort;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedId;
  final PlayerSummaryStats summary;

  PlayersListState copyWith({
    List<ManagedPlayer>? players,
    PlayerListFilters? filters,
    PlayerSort? sort,
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
    PlayerSummaryStats? summary,
  }) {
    return PlayersListState(
      players: players ?? this.players,
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

class PlayersListController extends StateNotifier<PlayersListState> {
  PlayersListController(this._ref)
      : super(const PlayersListState(isLoading: true)) {
    Future(() {
      if (mounted) refresh();
    });
  }

  final Ref _ref;
  PlayersRepository get _repo => _ref.read(playersRepositoryProvider);
  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
      players: const [],
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
        players: page.players,
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
        players: [...state.players, ...page.players],
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

  Future<void> applyFilters(PlayerListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> setSort(PlayerSortField field) async {
    final same = state.sort.field == field;
    state = state.copyWith(
      sort: PlayerSort(
        field: field,
        descending: same ? !state.sort.descending : true,
      ),
    );
    await refresh();
  }

  void selectPlayer(String? id) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedId: id);
    }
  }

  Future<void> setFeatured(ManagedPlayer player, bool featured) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setFeatured(target: player, featured: featured, actor: actor);
    await refresh();
    if (state.selectedId == player.id) {
      state = state.copyWith(selectedId: player.id);
    }
  }

  Future<void> setVerified(ManagedPlayer player, bool verified) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setVerified(target: player, verified: verified, actor: actor);
    await refresh();
  }

  Future<void> setStatus(ManagedPlayer player, ManagedPlayerStatus status) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setStatus(target: player, status: status, actor: actor);
    await refresh();
  }

  Future<void> softDelete(ManagedPlayer player) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.softDelete(target: player, actor: actor);
    await refresh();
  }

  Future<void> restore(ManagedPlayer player) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.restore(target: player, actor: actor);
    await refresh();
  }

  Future<void> updateBasicInfo({
    required ManagedPlayer player,
    String? name,
    String? fullName,
    String? role,
    String? battingStyle,
    String? bowlingStyle,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.updateBasicInfo(
      target: player,
      actor: actor,
      name: name,
      fullName: fullName,
      role: role,
      battingStyle: battingStyle,
      bowlingStyle: bowlingStyle,
    );
    await refresh();
  }
}

final playersListControllerProvider =
    StateNotifierProvider<PlayersListController, PlayersListState>((ref) {
  return PlayersListController(ref);
});

final selectedManagedPlayerProvider =
    FutureProvider.autoDispose<ManagedPlayer?>((ref) async {
  final id = ref.watch(
    playersListControllerProvider.select((s) => s.selectedId),
  );
  if (id == null) return null;
  final repo = ref.watch(playersRepositoryProvider);
  final appType = ref.watch(adminAppTypeProvider);
  final actor = ref.watch(adminSessionProvider).adminUser;
  return repo.fetchById(id, appType: appType, actor: actor);
});

final playerAuditProvider =
    FutureProvider.autoDispose.family<List<AdminAuditLogEntry>, String>(
  (ref, playerId) {
    return ref.watch(playersRepositoryProvider).fetchAuditForPlayer(playerId);
  },
);
