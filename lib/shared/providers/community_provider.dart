import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/enums.dart';
import '../../data/models/community_comment_model.dart';
import '../../data/models/community_post_model.dart';
import '../../data/repositories/community_repository.dart';
import '../../features/community/data/community_location_filter_store.dart';
import 'chat_provider.dart';
import 'player_social_provider.dart';
import 'providers.dart';

final communityRepositoryProvider = Provider(
  (ref) => CommunityRepository(
    notificationRepository: ref.watch(notificationRepositoryProvider),
  ),
);

final communityLocationFilterStoreProvider =
    FutureProvider<CommunityLocationFilterStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return CommunityLocationFilterStore(prefs);
});

final communityHiddenPostsStoreProvider =
    FutureProvider<CommunityHiddenPostsStore>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return CommunityHiddenPostsStore(prefs);
});

class CommunityFeedFilter {
  const CommunityFeedFilter({
    this.category,
    this.nearMeOnly = false,
    this.locations = const [],
  });

  final CommunityPostCategory? category;
  final bool nearMeOnly;
  final List<CommunityLocationSelection> locations;

  bool get hasLocationFilter => nearMeOnly || locations.isNotEmpty;

  CommunityFeedFilter copyWith({
    CommunityPostCategory? category,
    bool? clearCategory,
    bool? nearMeOnly,
    List<CommunityLocationSelection>? locations,
  }) {
    return CommunityFeedFilter(
      category: clearCategory == true ? null : (category ?? this.category),
      nearMeOnly: nearMeOnly ?? this.nearMeOnly,
      locations: locations ?? this.locations,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CommunityFeedFilter &&
      other.category == category &&
      other.nearMeOnly == nearMeOnly &&
      _listEq(other.locations, locations);

  @override
  int get hashCode => Object.hash(category, nearMeOnly, Object.hashAll(locations));

  static bool _listEq(
    List<CommunityLocationSelection> a,
    List<CommunityLocationSelection> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final communityFeedFilterProvider =
    StateProvider<CommunityFeedFilter>((ref) => const CommunityFeedFilter());

final communityHiddenPostIdsProvider =
    StateProvider<Set<String>>((ref) => {});

class CommunityFeedState {
  const CommunityFeedState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<CommunityPostModel> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;

  CommunityFeedState copyWith({
    List<CommunityPostModel>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return CommunityFeedState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Live head + append-only older pages; location filters applied client-side.
class CommunityFeedController extends StateNotifier<CommunityFeedState> {
  CommunityFeedController(this._ref)
      : super(const CommunityFeedState()) {
    _subscribe();
    _loadFollowing();
  }

  final Ref _ref;
  StreamSubscription<List<CommunityPostModel>>? _headSub;
  List<CommunityPostModel> _head = const [];
  List<CommunityPostModel> _older = const [];
  var _loadMoreLocked = false;
  Set<String> _followingIds = {};

  CommunityRepository get _repo => _ref.read(communityRepositoryProvider);

  Future<void> _loadFollowing() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      _followingIds = await _ref
          .read(playerFollowRepositoryProvider)
          .followingUserIds(uid);
      reapplyFilters();
    } catch (_) {}
  }

  void _subscribe() {
    _headSub?.cancel();
    final filter = _ref.read(communityFeedFilterProvider);
    _headSub = _repo
        .watchFeedHead(category: filter.category)
        .listen(
      (head) {
        _head = head;
        final headIds = head.map((e) => e.id).toSet();
        _older = _older.where((p) => !headIds.contains(p.id)).toList();
        state = state.copyWith(
          items: _visible(_merged()),
          loading: false,
          hasMore: _older.isNotEmpty
              ? state.hasMore
              : head.length >= CommunityRepository.pageSize,
          clearError: true,
        );
        if (head.length < CommunityRepository.pageSize && _older.isEmpty) {
          state = state.copyWith(hasMore: false);
        }
      },
      onError: (e) {
        state = state.copyWith(loading: false, error: e);
      },
    );
  }

  void resubscribe() {
    _older = const [];
    state = const CommunityFeedState();
    _subscribe();
  }

  List<CommunityPostModel> _merged() {
    final byId = <String, CommunityPostModel>{};
    for (final p in [..._head, ..._older]) {
      byId.putIfAbsent(p.id, () => p);
    }
    final list = byId.values.toList()
      ..sort((a, b) {
        // Pinned / admin / sponsored first, then recency.
        final scoreA = _rankScore(a);
        final scoreB = _rankScore(b);
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
    return list;
  }

  int _rankScore(CommunityPostModel p) {
    var s = 0;
    if (p.isPinned || p.isAdminPost) s += 1000;
    if (p.isSponsored) s += 500;
    if (_followingIds.contains(p.authorId)) s += 200;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    final myCity = profile?.location.city.trim().toLowerCase() ?? '';
    final postCity = p.location.city.trim().toLowerCase();
    if (myCity.isNotEmpty && postCity == myCity) s += 120;
    final myCountry = profile?.location.country.trim().toLowerCase() ?? '';
    final postCountry = p.location.country.trim().toLowerCase();
    if (myCountry.isNotEmpty &&
        postCountry == myCountry &&
        postCity != myCity) {
      s += 40;
    }
    // Mild popularity bump without drowning recent posts.
    s += (p.likeCount + p.commentCount).clamp(0, 80);
    return s;
  }

  List<CommunityPostModel> _visible(List<CommunityPostModel> posts) {
    final filter = _ref.read(communityFeedFilterProvider);
    final hidden = _ref.read(communityHiddenPostIdsProvider);
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    final blocked =
        _ref.read(blockedUserIdsProvider).valueOrNull ?? const <String>{};

    return posts.where((p) {
      if (hidden.contains(p.id)) return false;
      if (blocked.contains(p.authorId)) return false;

      if (!filter.hasLocationFilter) return true;

      final selections = <CommunityLocationSelection>[
        ...filter.locations,
        if (filter.nearMeOnly &&
            profile != null &&
            profile.location.city.isNotEmpty)
          CommunityLocationSelection(
            country: profile.location.country,
            stateProvince: profile.location.stateProvince,
            district: profile.location.district,
            city: profile.location.city,
          ),
      ];
      if (selections.isEmpty) return true;
      return selections.any((s) => s.matches(p.location));
    }).toList();
  }

  Future<void> loadMore() async {
    if (_loadMoreLocked || state.loadingMore || !state.hasMore) return;
    if (state.items.isEmpty && _head.isEmpty) return;

    _loadMoreLocked = true;
    state = state.copyWith(loadingMore: true);

    try {
      final filter = _ref.read(communityFeedFilterProvider);
      final source = _merged();
      if (source.isEmpty) {
        state = state.copyWith(loadingMore: false, hasMore: false);
        return;
      }
      final last = source.last;
      final cursor = last.createdAt?.toIso8601String();
      final page = await _repo.fetchPage(
        category: filter.category,
        startAfterCreatedAt: cursor,
      );
      final existingIds = source.map((e) => e.id).toSet();
      final fresh = page.where((p) => !existingIds.contains(p.id)).toList();
      if (fresh.isEmpty) {
        state = state.copyWith(loadingMore: false, hasMore: false);
        return;
      }
      _older = [..._older, ...fresh];
      state = state.copyWith(
        items: _visible(_merged()),
        loadingMore: false,
        hasMore: page.length >= CommunityRepository.pageSize,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e);
    } finally {
      _loadMoreLocked = false;
    }
  }

  Future<void> refresh() async {
    resubscribe();
  }

  void reapplyFilters() {
    state = state.copyWith(items: _visible(_merged()));
  }

  @override
  void dispose() {
    _headSub?.cancel();
    super.dispose();
  }
}

final communityFeedControllerProvider =
    StateNotifierProvider<CommunityFeedController, CommunityFeedState>((ref) {
  final controller = CommunityFeedController(ref);
  ref.listen<CommunityFeedFilter>(communityFeedFilterProvider, (prev, next) {
    if (prev?.category != next.category) {
      controller.resubscribe();
    } else {
      controller.reapplyFilters();
    }
  });
  ref.listen<Set<String>>(communityHiddenPostIdsProvider, (_, _) {
    controller.reapplyFilters();
  });
  ref.listen(blockedUserIdsProvider, (_, _) {
    controller.reapplyFilters();
  });
  return controller;
});

final communityPostLikedProvider =
    StreamProvider.family<bool, ({String postId, String userId})>((ref, ids) {
  return ref.watch(communityRepositoryProvider).watchLiked(
        postId: ids.postId,
        userId: ids.userId,
      );
});

final communityPostSavedProvider =
    StreamProvider.family<bool, ({String postId, String userId})>((ref, ids) {
  return ref.watch(communityRepositoryProvider).watchSaved(
        postId: ids.postId,
        userId: ids.userId,
      );
});

final communityCommentsProvider =
    StreamProvider.family<List<CommunityCommentModel>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).watchComments(postId);
});

final communityCommentLikedProvider = StreamProvider.family<
    bool,
    ({String postId, String commentId, String userId})>((ref, ids) {
  return ref.watch(communityRepositoryProvider).watchCommentLiked(
        postId: ids.postId,
        commentId: ids.commentId,
        userId: ids.userId,
      );
});
