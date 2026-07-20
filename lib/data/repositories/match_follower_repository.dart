import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';

/// Persists match follow subscriptions for enriched push notifications.
class MatchFollowerRepository {
  MatchFollowerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _followers =>
      _firestore.collection('matchFollowers');

  static String docId(String matchId, String userId) => '${matchId}_$userId';

  Stream<bool> watchIsFollowing({
    required String matchId,
    required String userId,
  }) {
    if (userId.isEmpty) return Stream.value(false);
    return _followers.doc(docId(matchId, userId)).snapshots().map((s) => s.exists);
  }

  Future<bool> isFollowing({
    required String matchId,
    required String userId,
  }) async {
    if (userId.isEmpty) return false;
    final snap = await _followers.doc(docId(matchId, userId)).get();
    return snap.exists;
  }

  Future<void> followMatch({
    required String matchId,
    required String userId,
  }) async {
    if (userId.isEmpty) return;
    await _followers.doc(docId(matchId, userId)).set({
      'matchId': matchId,
      'userId': userId,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> unfollowMatch({
    required String matchId,
    required String userId,
  }) async {
    if (userId.isEmpty) return;
    await _followers.doc(docId(matchId, userId)).delete();
  }

  /// Removes all match follows for [userId] (account deletion).
  Future<void> deleteAllForUser(String userId) async {
    if (userId.isEmpty) return;
    while (true) {
      final snap =
          await _followers.where('userId', isEqualTo: userId).limit(100).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}

/// User-level notification preferences (team + follower toggles).
class NotificationPreferencesRepository {
  NotificationPreferencesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      _firestore.collection(AppConstants.usersCollection).doc(userId);

  CollectionReference<Map<String, dynamic>> _teamPrefs(String userId) =>
      _userRef(userId).collection('teamNotificationPrefs');

  /// Deletes per-team notification prefs under the user (account deletion).
  Future<void> deleteTeamPrefsForUser(String userId) async {
    if (userId.isEmpty) return;
    while (true) {
      final snap = await _teamPrefs(userId).limit(100).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Stream<NotificationPreferences> watchPreferences(String userId) {
    if (userId.isEmpty) {
      return Stream.value(const NotificationPreferences());
    }
    return _userRef(userId).snapshots().map((snap) {
      final prefs =
          snap.data()?['notificationPrefs'] as Map<String, dynamic>? ?? {};
      return NotificationPreferences(
        receiveTeamMatchNotifications:
            prefs['receiveTeamMatchNotifications'] as bool? ?? true,
        receiveFollowerNotifications:
            prefs['receiveFollowerNotifications'] as bool? ?? true,
      );
    });
  }

  Future<NotificationPreferences> fetchPreferences(String userId) async {
    if (userId.isEmpty) return const NotificationPreferences();
    final snap = await _userRef(userId).get();
    final prefs =
        snap.data()?['notificationPrefs'] as Map<String, dynamic>? ?? {};
    return NotificationPreferences(
      receiveTeamMatchNotifications:
          prefs['receiveTeamMatchNotifications'] as bool? ?? true,
      receiveFollowerNotifications:
          prefs['receiveFollowerNotifications'] as bool? ?? true,
    );
  }

  Future<void> setReceiveTeamMatchNotifications(
    String userId,
    bool enabled,
  ) async {
    final current = await fetchPreferences(userId);
    await _userRef(userId).set(
      {
        'notificationPrefs': {
          'receiveTeamMatchNotifications': enabled,
          'receiveFollowerNotifications': current.receiveFollowerNotifications,
        },
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setReceiveFollowerNotifications(
    String userId,
    bool enabled,
  ) async {
    final current = await fetchPreferences(userId);
    await _userRef(userId).set(
      {
        'notificationPrefs': {
          'receiveTeamMatchNotifications': current.receiveTeamMatchNotifications,
          'receiveFollowerNotifications': enabled,
        },
      },
      SetOptions(merge: true),
    );
  }

  Stream<bool> watchTeamNotificationsEnabled({
    required String userId,
    required String teamId,
  }) {
    if (userId.isEmpty || teamId.isEmpty) return Stream.value(true);
    return _teamPrefs(userId).doc(teamId).snapshots().map((snap) {
      if (!snap.exists) return true;
      return snap.data()?['enabled'] as bool? ?? true;
    });
  }

  Future<void> setTeamNotificationsEnabled({
    required String userId,
    required String teamId,
    required bool enabled,
  }) async {
    await _teamPrefs(userId).doc(teamId).set({'enabled': enabled});
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    this.receiveTeamMatchNotifications = true,
    this.receiveFollowerNotifications = true,
  });

  final bool receiveTeamMatchNotifications;
  final bool receiveFollowerNotifications;
}
