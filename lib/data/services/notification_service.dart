import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/constants/app_constants.dart';
import 'push_notification_handler.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  Future<void> initializePush() async {
    await PushNotificationHandler.instance.initialize();
    await PushNotificationHandler.instance.ensurePermissions();
    PushNotificationHandler.instance.listenForOpenedMessages();
  }

  Future<void> registerDevice(String userId) async {
    if (userId.isEmpty) return;

    await PushNotificationHandler.instance.ensurePermissions();

    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await _firestore.collection(AppConstants.usersCollection).doc(userId).set(
        {
          'fcmToken': token,
          'fcmUpdatedAt': DateTime.now().toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-fatal when offline or permission denied.
    }
  }

  void listenForTokenRefresh(String userId) {
    _messaging.onTokenRefresh.listen((token) async {
      if (userId.isEmpty || token.isEmpty) return;
      try {
        await _firestore.collection(AppConstants.usersCollection).doc(userId).set(
          {
            'fcmToken': token,
            'fcmUpdatedAt': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}
    });
  }

  Future<void> subscribeToMatch(String matchId) async {
    await _messaging.subscribeToTopic('match_$matchId');
  }

  Future<void> unsubscribeFromMatch(String matchId) async {
    await _messaging.unsubscribeFromTopic('match_$matchId');
  }
}
