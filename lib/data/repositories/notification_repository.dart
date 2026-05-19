import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.notificationsCollection);

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

  Future<void> markRead(String notificationId) async {
    await _col.doc(notificationId).update({'read': true});
  }

  Future<void> markAllRead(String userId) async {
    final snap = await _col.where('userId', isEqualTo: userId).where('read', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Removes inbox notifications for account deletion (batched).
  Future<void> deleteAllForUser(String userId) async {
    while (true) {
      final snap = await _col.where('userId', isEqualTo: userId).limit(100).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
