import 'package:cloud_firestore/cloud_firestore.dart';

import 'support_thread_models.dart';

const supportThreadsCollection = 'support_threads';

/// One support conversation per signed-in user (thread id = user id).
class SupportThreadRepository {
  SupportThreadRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _threadRef(String userId) =>
      _db.collection(supportThreadsCollection).doc(userId);

  CollectionReference<Map<String, dynamic>> _messages(String threadId) =>
      _threadRef(threadId).collection('messages');

  Stream<SupportThread?> watchThread(String userId) {
    return _threadRef(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return SupportThread.fromMap(snap.id, snap.data() ?? {});
    });
  }

  Stream<List<SupportThread>> watchStaffInbox() {
    return _db
        .collection(supportThreadsCollection)
        .orderBy('lastMessageAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SupportThread.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<int> watchStaffUnreadTotal() {
    return _db
        .collection(supportThreadsCollection)
        .where('staffUnreadCount', isGreaterThan: 0)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs.fold<int>(
            0,
            (total, d) => total + ((d.data()['staffUnreadCount'] as num?)?.toInt() ?? 0),
          ),
        );
  }

  Stream<List<SupportMessage>> watchMessages(String threadId) {
    return _messages(threadId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SupportMessage.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> sendUserMessage({
    required String userId,
    required String displayName,
    String? photoUrl,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final threadRef = _threadRef(userId);
    final messageRef = _messages(userId).doc();
    final now = FieldValue.serverTimestamp();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(threadRef);
      final existingUnread =
          (snap.data()?['staffUnreadCount'] as num?)?.toInt() ?? 0;
      final threadPayload = <String, dynamic>{
        'userId': userId,
        'userDisplayName': displayName,
        if (photoUrl != null && photoUrl.isNotEmpty) 'userPhotoUrl': photoUrl,
        'status': 'open',
        'lastMessageAt': now,
        'lastMessageText': trimmed,
        'lastSenderId': userId,
        'lastSenderRole': 'user',
        'userUnreadCount': 0,
        'staffUnreadCount': existingUnread + 1,
        'updatedAt': now,
        if (!snap.exists) 'createdAt': now,
      };
      tx.set(threadRef, threadPayload, SetOptions(merge: true));
      tx.set(messageRef, {
        'senderId': userId,
        'senderName': displayName,
        'senderRole': 'user',
        'text': trimmed,
        'createdAt': now,
      });
    });
  }

  Future<void> sendStaffMessage({
    required String threadId,
    required String staffUserId,
    required String staffName,
    required String text,
    required int currentUserUnread,
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
          (snap.data()?['userUnreadCount'] as num?)?.toInt() ?? currentUserUnread;
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

  Future<void> markUserRead(String userId) async {
    final ref = _threadRef(userId);
    final snap = await ref.get();
    if (!snap.exists) return;
    await ref.set({'userUnreadCount': 0}, SetOptions(merge: true));
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
