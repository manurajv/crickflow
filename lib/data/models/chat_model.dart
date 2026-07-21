import 'package:equatable/equatable.dart';

enum ChatStatus { active, request, declined }

class ChatParticipant extends Equatable {
  const ChatParticipant({
    required this.userId,
    this.name = '',
    this.photoUrl,
    this.playerId,
  });

  final String userId;
  final String name;
  final String? photoUrl;
  final String? playerId;

  factory ChatParticipant.fromMap(String userId, Map<String, dynamic>? map) {
    return ChatParticipant(
      userId: userId,
      name: map?['name'] as String? ?? '',
      photoUrl: map?['photoUrl'] as String?,
      playerId: map?['playerId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (playerId != null) 'playerId': playerId,
      };

  @override
  List<Object?> get props => [userId, name, photoUrl];
}

class ChatModel extends Equatable {
  const ChatModel({
    required this.id,
    required this.participantIds,
    this.participants = const {},
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastSenderId = '',
    this.status = ChatStatus.active,
    this.requestFrom,
    this.unread = const {},
    this.pinnedBy = const [],
    this.mutedBy = const [],
    this.archivedBy = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final List<String> participantIds;
  final Map<String, ChatParticipant> participants;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastSenderId;
  final ChatStatus status;
  final String? requestFrom;
  final Map<String, int> unread;
  final List<String> pinnedBy;
  final List<String> mutedBy;
  final List<String> archivedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatParticipant? otherParticipant(String myId) {
    for (final id in participantIds) {
      if (id != myId) return participants[id];
    }
    return null;
  }

  int unreadFor(String userId) => unread[userId] ?? 0;

  bool isPinnedBy(String userId) => pinnedBy.contains(userId);
  bool isMutedBy(String userId) => mutedBy.contains(userId);
  bool isArchivedBy(String userId) => archivedBy.contains(userId);

  factory ChatModel.fromMap(String id, Map<String, dynamic> map) {
    final ids = List<String>.from(map['participantIds'] as List? ?? []);
    final rawParts = map['participants'] as Map<String, dynamic>? ?? {};
    final parts = <String, ChatParticipant>{};
    for (final e in rawParts.entries) {
      parts[e.key] = ChatParticipant.fromMap(
        e.key,
        e.value is Map ? Map<String, dynamic>.from(e.value as Map) : null,
      );
    }
    final unreadRaw = map['unread'] as Map<String, dynamic>? ?? {};
    final unread = <String, int>{
      for (final e in unreadRaw.entries) e.key: (e.value as num?)?.toInt() ?? 0,
    };

    return ChatModel(
      id: id,
      participantIds: ids,
      participants: parts,
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageAt: DateTime.tryParse(map['lastMessageAt']?.toString() ?? ''),
      lastSenderId: map['lastSenderId'] as String? ?? '',
      status: ChatStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ChatStatus.active,
      ),
      requestFrom: map['requestFrom'] as String?,
      unread: unread,
      pinnedBy: List<String>.from(map['pinnedBy'] as List? ?? []),
      mutedBy: List<String>.from(map['mutedBy'] as List? ?? []),
      archivedBy: List<String>.from(map['archivedBy'] as List? ?? []),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, status, lastMessageAt, unread];
}

class ChatMessageModel extends Equatable {
  const ChatMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  factory ChatMessageModel.fromMap(
    String id,
    Map<String, dynamic> map, {
    required String chatId,
  }) {
    return ChatMessageModel(
      id: id,
      chatId: chatId,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'text': text.trim(),
        'createdAt': createdAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, chatId, senderId, text];
}
