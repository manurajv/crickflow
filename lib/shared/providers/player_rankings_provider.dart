import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/location_model.dart';
import '../../data/repositories/player_rankings_repository.dart';
import '../../domain/services/player_rankings/player_rankings_models.dart';

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
  });

  final List<PlayerRankingEntry> entries;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final int totalCount;
  final int page;

  PlayerRankingsFeedState copyWith({
    List<PlayerRankingEntry>? entries,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    int? totalCount,
    int? page,
  }) {
    return PlayerRankingsFeedState(
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      totalCount: totalCount ?? this.totalCount,
      page: page ?? this.page,
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

  Future<void> refresh() async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      entries: const [],
      page: -1,
      hasMore: true,
    );
    try {
      final result = await _repo.fetchRankings(filter: _filter, page: 0);
      state = PlayerRankingsFeedState(
        entries: result.entries,
        loading: false,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
        page: 0,
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
      final nextPage = state.page + 1;
      final result = await _repo.fetchRankings(
        filter: _filter,
        page: nextPage,
      );
      state = state.copyWith(
        entries: [...state.entries, ...result.entries],
        loadingMore: false,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
        page: nextPage,
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
