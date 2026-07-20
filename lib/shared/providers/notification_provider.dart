import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import '../../data/repositories/match_follower_repository.dart';
import '../../data/repositories/notification_repository.dart';
import 'providers.dart';

class NotificationsFeedState {
  const NotificationsFeedState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<NotificationModel> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;

  NotificationsFeedState copyWith({
    List<NotificationModel>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return NotificationsFeedState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Live first page + append-only older pages (preserves scroll on load-more).
class NotificationsFeedController extends StateNotifier<NotificationsFeedState> {
  NotificationsFeedController(this._ref, this._userId)
      : super(const NotificationsFeedState()) {
    if (_userId == null || _userId!.isEmpty) {
      state = const NotificationsFeedState(loading: false, hasMore: false);
      return;
    }
    _subscribeHead();
  }

  final Ref _ref;
  final String? _userId;
  StreamSubscription<List<NotificationModel>>? _headSub;
  List<NotificationModel> _head = const [];
  List<NotificationModel> _older = const [];
  var _loadMoreLocked = false;

  NotificationRepository get _repo =>
      _ref.read(notificationRepositoryProvider);

  void _subscribeHead() {
    _headSub?.cancel();
    _headSub = _repo
        .watchForUser(_userId!, limit: NotificationRepository.pageSize)
        .listen(
      (head) {
        _head = head;
        // Drop older entries that moved into the live head (or were deleted).
        final headIds = head.map((e) => e.id).toSet();
        _older = _older.where((n) => !headIds.contains(n.id)).toList();
        state = state.copyWith(
          items: _merged(),
          loading: false,
          hasMore: _older.isNotEmpty
              ? state.hasMore
              : head.length >= NotificationRepository.pageSize,
          clearError: true,
        );
        if (head.length < NotificationRepository.pageSize && _older.isEmpty) {
          state = state.copyWith(hasMore: false);
        }
      },
      onError: (e) {
        state = state.copyWith(loading: false, error: e);
      },
    );
  }

  Future<void> loadMore() async {
    if (_userId == null || _userId!.isEmpty) return;
    if (_loadMoreLocked || state.loadingMore || !state.hasMore) return;
    if (state.items.isEmpty) return;

    _loadMoreLocked = true;
    state = state.copyWith(loadingMore: true);

    try {
      final last = state.items.last;
      final cursor = last.createdAt?.toIso8601String();
      final page = await _repo.fetchPage(
        userId: _userId!,
        limit: NotificationRepository.pageSize,
        startAfterCreatedAt: cursor,
      );

      final existingIds = state.items.map((e) => e.id).toSet();
      final fresh = page.where((n) => !existingIds.contains(n.id)).toList();

      if (fresh.isEmpty) {
        state = state.copyWith(loadingMore: false, hasMore: false);
        return;
      }

      _older = [..._older, ...fresh];
      state = state.copyWith(
        items: _merged(),
        loadingMore: false,
        hasMore: page.length >= NotificationRepository.pageSize,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e);
    } finally {
      _loadMoreLocked = false;
    }
  }

  List<NotificationModel> _merged() {
    if (_older.isEmpty) return List<NotificationModel>.from(_head);
    final seen = <String>{};
    final out = <NotificationModel>[];
    for (final n in _head) {
      if (seen.add(n.id)) out.add(n);
    }
    for (final n in _older) {
      if (seen.add(n.id)) out.add(n);
    }
    return out;
  }

  @override
  void dispose() {
    _headSub?.cancel();
    super.dispose();
  }
}

final notificationsFeedProvider = StateNotifierProvider.autoDispose<
    NotificationsFeedController, NotificationsFeedState>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return NotificationsFeedController(ref, uid);
});

/// First-page live stream (callers that only need recent items).
final userNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);
  return ref
      .watch(notificationRepositoryProvider)
      .watchForUser(uid, limit: NotificationRepository.pageSize);
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(uid);
});

final notificationPreferencesProvider =
    StreamProvider<NotificationPreferences>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) {
    return Stream.value(const NotificationPreferences());
  }
  return ref
      .watch(notificationPreferencesRepositoryProvider)
      .watchPreferences(uid);
});

final matchFollowingProvider = StreamProvider.family<bool, String>((ref, matchId) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(false);
  return ref
      .watch(matchFollowerRepositoryProvider)
      .watchIsFollowing(matchId: matchId, userId: uid);
});

final teamNotificationEnabledProvider =
    StreamProvider.family<bool, String>((ref, teamId) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(true);
  return ref.watch(notificationPreferencesRepositoryProvider).watchTeamNotificationsEnabled(
        userId: uid,
        teamId: teamId,
      );
});

/// Increment when user opens My Cricket → Teams tab or /teams route.
final teamsTabVisitCounterProvider = StateProvider<int>((ref) => 0);
