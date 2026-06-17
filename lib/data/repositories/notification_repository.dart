import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../models/notification_model.dart';
import '../models/team_model.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.notificationsCollection);

  CollectionReference<Map<String, dynamic>> get _players =>
      _firestore.collection(AppConstants.playersCollection);

  Stream<List<NotificationModel>> watchForUser(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<int> watchUnreadCount(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markRead(String notificationId) async {
    await _col.doc(notificationId).update({'read': true, 'isRead': true});
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String? matchId,
    String? teamId,
    String? playerId,
    String? type,
    String? addedByUserId,
    String? reportId,
  }) async {
    if (userId.isEmpty) return;

    await _col.doc(_uuid.v4()).set({
      'userId': userId,
      'title': title,
      'body': body,
      'message': body,
      if (matchId != null) 'matchId': matchId,
      if (teamId != null) 'teamId': teamId,
      if (playerId != null) 'playerId': playerId,
      if (type != null) 'type': type,
      if (addedByUserId != null) 'addedByUserId': addedByUserId,
      if (reportId != null) 'reportId': reportId,
      'read': false,
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Notifies owner, captain, and vice captain using Firebase Auth uids.
  Future<void> notifyTeamLeadership({
    required TeamModel team,
    required String title,
    required String body,
    required String type,
    String? playerId,
    String? excludeUserId,
  }) async {
    final recipients = await _leadershipAuthUserIds(team);
    for (final uid in recipients) {
      if (excludeUserId != null && uid == excludeUserId) continue;
      await createNotification(
        userId: uid,
        title: title,
        body: body,
        teamId: team.id,
        playerId: playerId,
        type: type,
      );
    }
  }

  Future<Set<String>> _leadershipAuthUserIds(TeamModel team) async {
    final ids = <String>{};

    final owner = team.createdBy;
    if (owner != null && owner.isNotEmpty) {
      ids.add(owner);
    }

    await _addResolvedPlayerUid(ids, team.captainId);
    await _addResolvedPlayerUid(ids, team.viceCaptainId);

    return ids;
  }

  Future<void> _addResolvedPlayerUid(Set<String> ids, String? playerDocId) async {
    if (playerDocId == null || playerDocId.isEmpty) return;

    final playerSnap = await _players.doc(playerDocId).get();
    if (!playerSnap.exists) {
      ids.add(playerDocId);
      return;
    }

    final userId = playerSnap.data()?['userId'] as String?;
    ids.add(userId != null && userId.isNotEmpty ? userId : playerDocId);
  }

  Future<void> markAllRead(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true, 'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotificationsForTeam(String teamId) async {
    while (true) {
      final snap =
          await _col.where('teamId', isEqualTo: teamId).limit(100).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> deleteAllForUser(String userId) async {
    while (true) {
      final snap =
          await _col.where('userId', isEqualTo: userId).limit(100).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
