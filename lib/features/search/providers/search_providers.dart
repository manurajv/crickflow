import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/community_provider.dart';
import '../../../shared/providers/player_social_provider.dart';
import '../../../shared/providers/providers.dart';
import '../data/recent_search_store.dart';
import '../data/unified_search_service.dart';
import '../domain/search_models.dart';

final recentSearchStoreProvider = FutureProvider<RecentSearchStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return RecentSearchStore(prefs);
});

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier(ref);
});

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier(this._ref) : super(const []) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final store = await _ref.read(recentSearchStoreProvider.future);
    state = store.read();
  }

  Future<void> add(String query) async {
    final store = await _ref.read(recentSearchStoreProvider.future);
    await store.add(query);
    state = store.read();
  }

  Future<void> remove(String query) async {
    final store = await _ref.read(recentSearchStoreProvider.future);
    await store.remove(query);
    state = store.read();
  }

  Future<void> clear() async {
    final store = await _ref.read(recentSearchStoreProvider.future);
    await store.clear();
    state = const [];
  }
}

final unifiedSearchServiceProvider = Provider((ref) {
  return UnifiedSearchService(
    playerDiscovery: ref.watch(playerDiscoveryRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
    communityRepository: ref.watch(communityRepositoryProvider),
  );
});

class SearchQueryState {
  const SearchQueryState({
    this.text = '',
    this.debounced = '',
    this.category = SearchCategory.all,
  });

  final String text;
  final String debounced;
  final SearchCategory category;

  SearchQueryState copyWith({
    String? text,
    String? debounced,
    SearchCategory? category,
  }) {
    return SearchQueryState(
      text: text ?? this.text,
      debounced: debounced ?? this.debounced,
      category: category ?? this.category,
    );
  }
}

final searchQueryProvider =
    StateNotifierProvider.autoDispose<SearchQueryNotifier, SearchQueryState>(
  (ref) => SearchQueryNotifier(),
);

class SearchQueryNotifier extends StateNotifier<SearchQueryState> {
  SearchQueryNotifier() : super(const SearchQueryState());

  Timer? _debounce;

  void setText(String value) {
    state = state.copyWith(text: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      state = state.copyWith(debounced: value.trim());
    });
  }

  void setCategory(SearchCategory category) {
    state = state.copyWith(category: category);
  }

  void applySuggestion(String query, SearchCategory category) {
    _debounce?.cancel();
    state = SearchQueryState(
      text: query,
      debounced: query.trim(),
      category: category,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchResultsProvider =
    FutureProvider.autoDispose<UnifiedSearchResult>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final q = query.debounced;
  if (q.isEmpty) {
    return UnifiedSearchResult(query: q, category: query.category);
  }

  final matches = ref.watch(matchesProvider).valueOrNull ?? [];
  final teams = ref.watch(allTeamsProvider).valueOrNull ?? [];
  final tournaments = ref.watch(tournamentsProvider).valueOrNull ?? [];
  final uid = ref.watch(authStateProvider).value?.uid;
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;

  return ref.watch(unifiedSearchServiceProvider).search(
        query: q,
        category: query.category,
        matches: matches,
        teams: teams,
        tournaments: tournaments,
        currentUserId: uid,
        currentUser: profile,
      );
});
