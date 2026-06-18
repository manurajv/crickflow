import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import '../../data/repositories/match_follower_repository.dart';
import 'providers.dart';

final userNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(notificationRepositoryProvider).watchForUser(uid);
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

