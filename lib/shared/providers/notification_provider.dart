import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
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

/// Increment when user opens My Cricket → Teams tab or /teams route.
final teamsTabVisitCounterProvider = StateProvider<int>((ref) => 0);
