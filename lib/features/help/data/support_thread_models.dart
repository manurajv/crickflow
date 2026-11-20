import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class SupportThread {
  const SupportThread({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    this.userPhotoUrl,
    this.status = 'open',
    this.lastMessageAt,
    this.lastMessageText = '',
    this.lastSenderRole = '',
    this.userUnreadCount = 0,
    this.staffUnreadCount = 0,
    this.createdAt,
    this.resolvedAt,
    this.resolvedByName,
  });

  final String id;
  final String userId;
  final String userDisplayName;
  final String? userPhotoUrl;
  final String status;
  final DateTime? lastMessageAt;
  final String lastMessageText;
  final String lastSenderRole;
  final int userUnreadCount;
  final int staffUnreadCount;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedByName;

  bool get isOpen => status != 'resolved';

  factory SupportThread.fromMap(String id, Map<String, dynamic> map) {
    return SupportThread(
      id: id,
      userId: (map['userId'] as String?) ?? '',
      userDisplayName: (map['userDisplayName'] as String?)?.trim().isNotEmpty == true
          ? (map['userDisplayName'] as String).trim()
          : 'CrickFlow user',
      userPhotoUrl: map['userPhotoUrl'] as String?,
      status: (map['status'] as String?) ?? 'open',
      lastMessageAt: _ts(map['lastMessageAt']),
      lastMessageText: (map['lastMessageText'] as String?) ?? '',
      lastSenderRole: (map['lastSenderRole'] as String?) ?? '',
      userUnreadCount: (map['userUnreadCount'] as num?)?.toInt() ?? 0,
      staffUnreadCount: (map['staffUnreadCount'] as num?)?.toInt() ?? 0,
      createdAt: _ts(map['createdAt']),
      resolvedAt: _ts(map['resolvedAt']),
      resolvedByName: map['resolvedByName'] as String?,
    );
  }
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime? createdAt;

  bool get isStaff => senderRole == 'staff';

  factory SupportMessage.fromMap(String id, Map<String, dynamic> map) {
    return SupportMessage(
      id: id,
      senderId: (map['senderId'] as String?) ?? '',
      senderName: (map['senderName'] as String?)?.trim().isNotEmpty == true
          ? (map['senderName'] as String).trim()
          : (map['senderRole'] == 'staff' ? 'CrickFlow staff' : 'You'),
      senderRole: (map['senderRole'] as String?) ?? 'user',
      text: (map['text'] as String?) ?? '',
      createdAt: _ts(map['createdAt']),
    );
  }
}
