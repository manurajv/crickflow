import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/geo_distance.dart';
import '../../data/models/opportunity_post_model.dart';
import '../../data/repositories/opportunity_repository.dart';
import '../../data/services/google_maps_location_service.dart';
import '../../features/discover/domain/opportunity_category.dart';
import 'providers.dart';

final opportunityRepositoryProvider = Provider(
  (ref) => OpportunityRepository(),
);

final platformAdminIdsProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(opportunityRepositoryProvider).watchPlatformAdminIds();
});

final isPlatformAdminProvider = Provider<bool>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return false;
  final admins = ref.watch(platformAdminIdsProvider).valueOrNull ?? {};
  return admins.contains(uid);
});

class OpportunityFeedFilter {
  const OpportunityFeedFilter({
    this.category,
    this.quickFilterId = 'all',
    this.searchQuery = '',
    this.savedOnly = false,
  });

  final OpportunityCategory? category;
  final String quickFilterId;
  final String searchQuery;
  final bool savedOnly;

  OpportunityFeedFilter copyWith({
    OpportunityCategory? category,
    bool clearCategory = false,
    String? quickFilterId,
    String? searchQuery,
    bool? savedOnly,
  }) {
    return OpportunityFeedFilter(
      category: clearCategory ? null : (category ?? this.category),
      quickFilterId: quickFilterId ?? this.quickFilterId,
      searchQuery: searchQuery ?? this.searchQuery,
      savedOnly: savedOnly ?? this.savedOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OpportunityFeedFilter &&
      other.category == category &&
      other.quickFilterId == quickFilterId &&
      other.searchQuery == searchQuery &&
      other.savedOnly == savedOnly;

  @override
  int get hashCode =>
      Object.hash(category, quickFilterId, searchQuery, savedOnly);
}

final opportunityFeedFilterProvider =
    StateProvider<OpportunityFeedFilter>((ref) => const OpportunityFeedFilter());

class OpportunityFeedState {
  const OpportunityFeedState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<OpportunityPostModel> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;

  OpportunityFeedState copyWith({
    List<OpportunityPostModel>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return OpportunityFeedState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OpportunityFeedController extends StateNotifier<OpportunityFeedState> {
  OpportunityFeedController(this._ref) : super(const OpportunityFeedState()) {
    _ref.listen<OpportunityFeedFilter>(opportunityFeedFilterProvider, (
      prev,
      next,
    ) {
      if (prev?.category != next.category) {
        _older = const [];
        _resubscribeHead(next.category);
      }
      if (next.savedOnly && (prev?.savedOnly != true)) {
        _loadSaved();
      }
      if (next.quickFilterId == 'nearby') {
        resolveNearMeOrigin();
      }
      _publish();
    });
    _subscribe();
  }

  final Ref _ref;
  StreamSubscription<List<OpportunityPostModel>>? _headSub;
  StreamSubscription<List<String>>? _savedIdsSub;
  List<OpportunityPostModel> _head = const [];
  List<OpportunityPostModel> _older = const [];
  List<OpportunityPostModel> _saved = const [];
  var _loadMoreLocked = false;
  GeoCoords? _nearMeOrigin;
  var _nearMeResolveGen = 0;

  OpportunityRepository get _repo =>
      _ref.read(opportunityRepositoryProvider);

  void _resubscribeHead(OpportunityCategory? category) {
    _headSub?.cancel();
    _headSub = _repo.watchFeedHead(category: category).listen(
          _onHead,
          onError: (e) {
            state = state.copyWith(loading: false, error: e);
          },
        );
  }

  void _subscribe() {
    _headSub?.cancel();
    _savedIdsSub?.cancel();

    final filter = _ref.read(opportunityFeedFilterProvider);
    _resubscribeHead(filter.category);

    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null && uid.isNotEmpty) {
      _savedIdsSub = _repo.watchSavedPostIds(uid).listen((ids) async {
        if (_ref.read(opportunityFeedFilterProvider).savedOnly) {
          _saved = await _repo.fetchPostsByIds(ids);
        }
        _publish();
      });
    }
  }

  Future<void> _loadSaved() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final ids = await _repo.watchSavedPostIds(uid).first;
    _saved = await _repo.fetchPostsByIds(ids);
    _publish();
  }

  void _onHead(List<OpportunityPostModel> head) {
    _head = head;
    state = state.copyWith(loading: false, clearError: true);
    _publish();
  }

  Future<void> resolveNearMeOrigin() async {
    final gen = ++_nearMeResolveGen;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null && profile.location.hasCoordinates) {
      _nearMeOrigin = GeoCoords(
        latitude: profile.location.latitude!,
        longitude: profile.location.longitude!,
      );
      _publish();
      return;
    }
    final coords =
        await _ref.read(googleMapsLocationServiceProvider).getCurrentCoords();
    if (gen != _nearMeResolveGen) return;
    _nearMeOrigin = coords;
    _publish();
  }

  void _publish() {
    final filter = _ref.read(opportunityFeedFilterProvider);
    var items = filter.savedOnly
        ? List<OpportunityPostModel>.from(_saved)
        : _mergeUnique(_head, _older);

    items = items.where((p) => p.isActive || filter.savedOnly).toList();

    final quick = _resolveQuickFilter(filter);
    if (quick != null && quick.id != 'all') {
      if (quick.nearbyOnly) {
        final origin = _nearMeOrigin;
        if (origin != null) {
          items = items.where((p) {
            if (!p.location.hasCoordinates) {
              final profile =
                  _ref.read(currentUserProfileProvider).valueOrNull;
              if (profile == null) return false;
              final city = profile.location.city.toLowerCase();
              final country = profile.location.country.toLowerCase();
              return (city.isNotEmpty &&
                      p.location.city.toLowerCase() == city) ||
                  (country.isNotEmpty &&
                      p.location.country.toLowerCase() == country);
            }
            final d = distanceKmBetween(
              origin,
              GeoCoords(
                latitude: p.location.latitude!,
                longitude: p.location.longitude!,
              ),
            );
            return d <= kNearbyRadiusKm;
          }).toList();
        }
      } else if (quick.fieldKey != null && quick.matchValue != null) {
        items = items.where((p) {
          final v = p.fields[quick.fieldKey];
          if (v is List) {
            return v.map((e) => e.toString()).contains(quick.matchValue);
          }
          return v?.toString() == quick.matchValue;
        }).toList();
      }
    }

    final q = filter.searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((p) {
        final hay = p.searchText.isNotEmpty
            ? p.searchText
            : OpportunityPostModel.buildSearchText(
                title: p.title,
                description: p.description,
                location: p.location,
                fields: p.fields,
                authorName: p.authorName,
              );
        return hay.contains(q);
      }).toList();
    }

    items.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
      final aAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });

    state = state.copyWith(
      items: items,
      hasMore: !filter.savedOnly && _older.length + _head.length >= pageHint,
    );
  }

  static const pageHint = OpportunityRepository.pageSize;

  OpportunityQuickFilter? _resolveQuickFilter(OpportunityFeedFilter filter) {
    final chips = filter.category?.quickFilters ??
        OpportunityQuickFilter.globalDefaults;
    for (final c in chips) {
      if (c.id == filter.quickFilterId) return c;
    }
    return OpportunityQuickFilter.all;
  }

  List<OpportunityPostModel> _mergeUnique(
    List<OpportunityPostModel> head,
    List<OpportunityPostModel> older,
  ) {
    final seen = <String>{};
    final out = <OpportunityPostModel>[];
    for (final p in [...head, ...older]) {
      if (seen.add(p.id)) out.add(p);
    }
    return out;
  }

  Future<void> loadMore() async {
    if (_loadMoreLocked || state.loadingMore || !state.hasMore) return;
    final filter = _ref.read(opportunityFeedFilterProvider);
    if (filter.savedOnly) return;

    _loadMoreLocked = true;
    state = state.copyWith(loadingMore: true);
    try {
      final merged = _mergeUnique(_head, _older);
      final last = merged.isNotEmpty ? merged.last : null;
      final cursor = last?.createdAt?.toUtc().toIso8601String();
      final page = await _repo.fetchPage(
        category: filter.category,
        startAfterCreatedAt: cursor,
      );
      if (page.isEmpty) {
        state = state.copyWith(loadingMore: false, hasMore: false);
      } else {
        _older = [..._older, ...page];
        state = state.copyWith(loadingMore: false);
        _publish();
      }
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e);
    } finally {
      _loadMoreLocked = false;
    }
  }

  Future<void> refresh() async {
    _older = const [];
    state = state.copyWith(loading: true, clearError: true);
    _subscribe();
  }

  @override
  void dispose() {
    _headSub?.cancel();
    _savedIdsSub?.cancel();
    super.dispose();
  }
}

final opportunityFeedControllerProvider =
    StateNotifierProvider<OpportunityFeedController, OpportunityFeedState>(
  (ref) => OpportunityFeedController(ref),
);

final opportunityPostSavedProvider =
    StreamProvider.family<bool, String>((ref, postId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(false);
  return ref
      .watch(opportunityRepositoryProvider)
      .watchSaved(postId: postId, userId: uid);
});

final opportunitySavedPostIdsProvider = StreamProvider<List<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null || uid.isEmpty) return Stream.value(const []);
  return ref.watch(opportunityRepositoryProvider).watchSavedPostIds(uid);
});

final opportunitySavedPostsProvider =
    FutureProvider<List<OpportunityPostModel>>((ref) async {
  final ids = await ref.watch(opportunitySavedPostIdsProvider.future);
  if (ids.isEmpty) return const [];
  return ref.read(opportunityRepositoryProvider).fetchPostsByIds(ids);
});

final authorOpportunityPostsProvider =
    FutureProvider.family<List<OpportunityPostModel>, String>((ref, authorId) {
  return ref
      .read(opportunityRepositoryProvider)
      .fetchByAuthor(authorId, limit: 10);
});
