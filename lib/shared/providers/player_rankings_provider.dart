import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/location_model.dart';
import '../../data/models/player_model.dart';
import '../../data/repositories/player_rankings_repository.dart';
import '../../domain/services/player_rankings/player_rankings_models.dart';
import 'my_player_provider.dart';

final playerRankingsRepositoryProvider = Provider(
  (ref) => PlayerRankingsRepository(),
);

final playerRankingsFilterProvider =
    StateProvider<PlayerRankingsFilter>((ref) => const PlayerRankingsFilter());

class PlayerRankingsFeedState {
  const PlayerRankingsFeedState({
    this.entries = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
    this.totalCount = 0,
    this.page = -1,
    this.myEntry,
  });

  final List<PlayerRankingEntry> entries;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final int totalCount;
  final int page;
  final PlayerRankingEntry? myEntry;

  PlayerRankingsFeedState copyWith({
    List<PlayerRankingEntry>? entries,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    int? totalCount,
    int? page,
    PlayerRankingEntry? myEntry,
    bool clearMyEntry = false,
  }) {
    return PlayerRankingsFeedState(
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      totalCount: totalCount ?? this.totalCount,
      page: page ?? this.page,
      myEntry: clearMyEntry ? null : (myEntry ?? this.myEntry),
    );
  }
}

class PlayerRankingsFeedController
    extends StateNotifier<PlayerRankingsFeedState> {
  PlayerRankingsFeedController(this._ref)
      : super(const PlayerRankingsFeedState()) {
    refresh();
  }

  final Ref _ref;
  var _loadMoreLocked = false;

  PlayerRankingsRepository get _repo =>
      _ref.read(playerRankingsRepositoryProvider);

  PlayerRankingsFilter get _filter =>
      _ref.read(playerRankingsFilterProvider);

  Future<PlayerModel?> _viewerPlayer() async {
    try {
      return await _ref.read(myPlayerProvider.future);
    } catch (_) {
      return _ref.read(myPlayerProvider).valueOrNull;
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      entries: const [],
      page: -1,
      hasMore: true,
      clearMyEntry: true,
    );
    try {
      final viewer = await _viewerPlayer();
      final result = await _repo.fetchRankings(
        filter: _filter,
        page: 0,
        viewerPlayerDocId: viewer?.id,
        viewerPublicPlayerId: viewer?.playerId,
      );
      state = PlayerRankingsFeedState(
        entries: result.entries,
        loading: false,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
        page: 0,
        myEntry: result.myEntry,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (_loadMoreLocked || state.loadingMore || !state.hasMore || state.loading) {
      return;
    }
    _loadMoreLocked = true;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final viewer = await _viewerPlayer();
      final nextPage = state.page + 1;
      final result = await _repo.fetchRankings(
        filter: _filter,
        page: nextPage,
        viewerPlayerDocId: viewer?.id,
        viewerPublicPlayerId: viewer?.playerId,
      );
      state = state.copyWith(
        entries: [...state.entries, ...result.entries],
        loadingMore: false,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
        page: nextPage,
        myEntry: result.myEntry ?? state.myEntry,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e);
    } finally {
      _loadMoreLocked = false;
    }
  }
}

final playerRankingsFeedControllerProvider = StateNotifierProvider<
    PlayerRankingsFeedController, PlayerRankingsFeedState>((ref) {
  final controller = PlayerRankingsFeedController(ref);
  ref.listen<PlayerRankingsFilter>(playerRankingsFilterProvider, (prev, next) {
    if (prev == next) return;
    controller.refresh();
  });
  ref.listen(myPlayerProvider, (prev, next) {
    final prevId = prev?.valueOrNull?.id;
    final nextId = next.valueOrNull?.id;
    if (prevId == nextId) return;
    // Auth/player resolved after first paint — refresh so sticky rank appears.
    if (nextId != null && nextId.isNotEmpty) {
      controller.refresh();
    }
  });
  return controller;
});

void updatePlayerRankingsFilter(
  WidgetRef ref,
  PlayerRankingsFilter Function(PlayerRankingsFilter) transform,
) {
  final current = ref.read(playerRankingsFilterProvider);
  ref.read(playerRankingsFilterProvider.notifier).state = transform(current);
}

void setPlayerRankingsLocation(WidgetRef ref, LocationModel location) {
  updatePlayerRankingsFilter(
    ref,
    (f) => f.copyWith(location: location),
  );
}
