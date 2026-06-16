import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.matchId,
    this.teamId,
    this.playerId,
    this.type,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String? matchId;
  final String? teamId;
  final String? playerId;
  final String? type;
  final bool read;
  final DateTime? createdAt;

  bool get isRead => read;

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? map['message'] as String? ?? '',
      matchId: map['matchId'] as String?,
      teamId: map['teamId'] as String?,
      playerId: map['playerId'] as String?,
      type: map['type'] as String?,
      read: map['read'] as bool? ?? map['isRead'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [id, title, read];
}
