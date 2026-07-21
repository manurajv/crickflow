import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection(AppConstants.chatsCollection);

  CollectionReference<Map<String, dynamic>> get _blocks =>
      _firestore.collection(AppConstants.chatBlocksCollection);

  /// Deterministic 1:1 chat id (sorted uids).
  static String chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<List<ChatModel>> watchChatsForUser(String userId) {
    return _chats
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ChatModel.fromMap(d.id, d.data()))
          .where((c) {
            if (c.isArchivedBy(userId)) return false;
            if (c.status == ChatStatus.active) return true;
            // Outgoing pending requests stay visible to the sender.
            if (c.status == ChatStatus.request && c.requestFrom == userId) {
              return true;
            }
            return false;
          })
          .toList();
      list.sort((a, b) {
        final pinA = a.isPinnedBy(userId);
        final pinB = b.isPinnedBy(userId);
        if (pinA != pinB) return pinA ? -1 : 1;
        final unreadA = a.unreadFor(userId) > 0;
        final unreadB = b.unreadFor(userId) > 0;
        if (unreadA != unreadB) return unreadA ? -1 : 1;
        final ta = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return list;
    });
  }

  Stream<List<ChatModel>> watchMessageRequests(String userId) {
    return _chats
        .where('participantIds', arrayContains: userId)
        .where('status', isEqualTo: ChatStatus.request.name)
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChatModel.fromMap(d.id, d.data()))
              .where((c) => c.requestFrom != userId)
              .toList(),
        );
  }

  Stream<int> watchUnreadChatCount(String userId) {
    return watchChatsForUser(userId).map(
      (chats) => chats.fold<int>(0, (total, c) => total + c.unreadFor(userId)),
    );
  }

  Stream<int> watchMessageRequestCount(String userId) {
    return watchMessageRequests(userId).map((list) => list.length);
  }

  Stream<ChatModel?> watchChat(String chatId) {
    return _chats.doc(chatId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ChatModel.fromMap(doc.id, doc.data()!);
    });
  }

  Stream<List<ChatMessageModel>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => ChatMessageModel.fromMap(
                  d.id,
                  d.data(),
                  chatId: chatId,
                ),
              )
              .toList(),
        );
  }

  Future<bool> isBlocked({
    required String blockerId,
    required String blockedId,
  }) async {
    final id = '${blockerId}_$blockedId';
    final doc = await _blocks.doc(id).get();
    return doc.exists;
  }

  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    await _blocks.doc('${blockerId}_$blockedId').set({
      'blockerId': blockerId,
      'blockedId': blockedId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    final chatId = chatIdFor(blockerId, blockedId);
    final chatRef = _chats.doc(chatId);
    final snap = await chatRef.get();
    if (snap.exists) {
      await chatRef.update({
        'status': ChatStatus.declined.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Stream<Set<String>> watchBlockedUserIds(String blockerId) {
    if (blockerId.isEmpty) return Stream.value({});
    return _blocks
        .where('blockerId', isEqualTo: blockerId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => d.data()['blockedId'] as String? ?? '')
              .where((id) => id.isNotEmpty)
              .toSet(),
        );
  }

  /// Opens or creates a chat. Returns chatId.
  /// First message from a stranger creates a [ChatStatus.request].
  Future<String> openOrCreateChat({
    required UserModel me,
    required UserModel other,
  }) async {
    if (me.id.isEmpty || other.id.isEmpty || me.id == other.id) {
      throw ArgumentError('Invalid participants');
    }

    final blocked = await isBlocked(blockerId: other.id, blockedId: me.id) ||
        await isBlocked(blockerId: me.id, blockedId: other.id);
    if (blocked) {
      throw StateError('Messaging is blocked');
    }

    final chatId = chatIdFor(me.id, other.id);
    final ref = _chats.doc(chatId);
    final existing = await ref.get();
    if (existing.exists) {
      final data = existing.data()!;
      final status = data['status'] as String?;
      if (status == ChatStatus.declined.name) {
        throw StateError('This conversation was declined');
      }
      // Un-archive for current user when reopening.
      final archived = List<String>.from(data['archivedBy'] as List? ?? []);
      if (archived.contains(me.id)) {
        archived.remove(me.id);
        await ref.update({
          'archivedBy': archived,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
      return chatId;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final ids = [me.id, other.id]..sort();
    await ref.set({
      'participantIds': ids,
      'participants': {
        me.id: ChatParticipant(
          userId: me.id,
          name: me.effectiveName,
          photoUrl: me.photoUrl,
          playerId: me.playerId,
        ).toMap(),
        other.id: ChatParticipant(
          userId: other.id,
          name: other.effectiveName,
          photoUrl: other.photoUrl,
          playerId: other.playerId,
        ).toMap(),
      },
      'lastMessage': '',
      'lastMessageAt': now,
      'lastSenderId': '',
      'status': ChatStatus.request.name,
      'requestFrom': me.id,
      'unread': {me.id: 0, other.id: 0},
      'pinnedBy': <String>[],
      'mutedBy': <String>[],
      'archivedBy': <String>[],
      'createdAt': now,
      'updatedAt': now,
    });
    return chatId;
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final chatRef = _chats.doc(chatId);
    final msgRef = chatRef.collection('messages').doc();
    final now = DateTime.now().toUtc().toIso8601String();

    await _firestore.runTransaction((tx) async {
      final chatSnap = await tx.get(chatRef);
      if (!chatSnap.exists) throw StateError('Chat not found');
      final data = chatSnap.data()!;
      final status = data['status'] as String? ?? ChatStatus.active.name;
      if (status == ChatStatus.declined.name) {
        throw StateError('Conversation declined');
      }

      final participants =
          List<String>.from(data['participantIds'] as List? ?? []);
      final unread = Map<String, dynamic>.from(
        data['unread'] as Map? ?? {},
      );
      for (final id in participants) {
        if (id == senderId) {
          unread[id] = 0;
        } else {
          unread[id] = ((unread[id] as num?)?.toInt() ?? 0) + 1;
        }
      }

      tx.set(msgRef, {
        'senderId': senderId,
        'text': trimmed,
        'createdAt': now,
      });
      tx.update(chatRef, {
        'lastMessage': trimmed,
        'lastMessageAt': now,
        'lastSenderId': senderId,
        'unread': unread,
        'updatedAt': now,
        // Keep request status until accepted; first message already set it.
      });
    });
  }

  Future<void> markRead({
    required String chatId,
    required String userId,
  }) async {
    await _chats.doc(chatId).update({
      'unread.$userId': 0,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> acceptRequest({
    required String chatId,
    required String userId,
  }) async {
    final ref = _chats.doc(chatId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if (data['requestFrom'] == userId) return;
    await ref.update({
      'status': ChatStatus.active.name,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> declineRequest({
    required String chatId,
    required String userId,
  }) async {
    await _chats.doc(chatId).update({
      'status': ChatStatus.declined.name,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> togglePin({
    required String chatId,
    required String userId,
  }) async {
    final ref = _chats.doc(chatId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final pinned = List<String>.from(snap.data()!['pinnedBy'] as List? ?? []);
      if (pinned.contains(userId)) {
        pinned.remove(userId);
      } else {
        pinned.add(userId);
      }
      tx.update(ref, {
        'pinnedBy': pinned,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<void> toggleMute({
    required String chatId,
    required String userId,
  }) async {
    final ref = _chats.doc(chatId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final muted = List<String>.from(snap.data()!['mutedBy'] as List? ?? []);
      if (muted.contains(userId)) {
        muted.remove(userId);
      } else {
        muted.add(userId);
      }
      tx.update(ref, {
        'mutedBy': muted,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<void> archiveChat({
    required String chatId,
    required String userId,
  }) async {
    final ref = _chats.doc(chatId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final archived =
          List<String>.from(snap.data()!['archivedBy'] as List? ?? []);
      if (!archived.contains(userId)) archived.add(userId);
      final pinned = List<String>.from(snap.data()!['pinnedBy'] as List? ?? []);
      pinned.remove(userId);
      tx.update(ref, {
        'archivedBy': archived,
        'pinnedBy': pinned,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  Future<void> deleteChatForUser({
    required String chatId,
    required String userId,
  }) async {
    // Soft-delete: archive + clear unread. Messages remain for the other user.
    await archiveChat(chatId: chatId, userId: userId);
    await markRead(chatId: chatId, userId: userId);
  }
}
