import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_support_thread_models.dart';

const userSupportThreadsCollection = 'support_threads';

class UserSupportThreadRepository {
  UserSupportThreadRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _threadRef(String threadId) =>
      _db.collection(userSupportThreadsCollection).doc(threadId);

  CollectionReference<Map<String, dynamic>> _messages(String threadId) =>
      _threadRef(threadId).collection('messages');

  Stream<List<UserSupportThread>> watchInbox() {
    return _db
        .collection(userSupportThreadsCollection)
        .orderBy('lastMessageAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => UserSupportThread.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<UserSupportMessage>> watchMessages(String threadId) {
    return _messages(threadId).orderBy('createdAt').snapshots().map(
          (snap) => snap.docs
              .map((d) => UserSupportMessage.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> sendStaffMessage({
    required String threadId,
    required String staffUserId,
    required String staffName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final threadRef = _threadRef(threadId);
    final messageRef = _messages(threadId).doc();
    final now = FieldValue.serverTimestamp();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(threadRef);
      if (!snap.exists) {
        throw StateError('This conversation is no longer available.');
      }
      final userUnread =
          (snap.data()?['userUnreadCount'] as num?)?.toInt() ?? 0;
      tx.set(
        threadRef,
        {
          'status': 'open',
          'lastMessageAt': now,
          'lastMessageText': trimmed,
          'lastSenderId': staffUserId,
          'lastSenderRole': 'staff',
          'staffUnreadCount': 0,
          'userUnreadCount': userUnread + 1,
          'updatedAt': now,
          'resolvedAt': FieldValue.delete(),
          'resolvedByName': FieldValue.delete(),
          'resolvedByUid': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      tx.set(messageRef, {
        'senderId': staffUserId,
        'senderName': staffName,
        'senderRole': 'staff',
        'text': trimmed,
        'createdAt': now,
      });
    });
  }

  Future<void> markStaffRead(String threadId) async {
    final ref = _threadRef(threadId);
    final snap = await ref.get();
    if (!snap.exists) return;
    await ref.set({'staffUnreadCount': 0}, SetOptions(merge: true));
  }

  Future<void> setStatus({
    required String threadId,
    required String status,
    String? resolvedByUid,
    String? resolvedByName,
  }) async {
    final now = FieldValue.serverTimestamp();
    final payload = <String, dynamic>{
      'status': status,
      'updatedAt': now,
    };
    if (status == 'resolved') {
      payload['resolvedAt'] = now;
      if (resolvedByUid != null) payload['resolvedByUid'] = resolvedByUid;
      if (resolvedByName != null) payload['resolvedByName'] = resolvedByName;
    } else {
      payload['resolvedAt'] = FieldValue.delete();
      payload['resolvedByName'] = FieldValue.delete();
      payload['resolvedByUid'] = FieldValue.delete();
    }
    await _threadRef(threadId).set(payload, SetOptions(merge: true));
  }
}
