import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/constants/app_constants.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  Future<void> registerDevice(String userId) async {
    final token = await _messaging.getToken();
    if (token == null) return;

    await _firestore.collection(AppConstants.usersCollection).doc(userId).set(
      {
        'fcmToken': token,
        'fcmUpdatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> subscribeToMatch(String matchId) async {
    await _messaging.subscribeToTopic('match_$matchId');
  }

  Future<void> unsubscribeFromMatch(String matchId) async {
    await _messaging.unsubscribeFromTopic('match_$matchId');
  }
}
