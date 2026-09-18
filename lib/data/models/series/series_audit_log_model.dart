import 'package:equatable/equatable.dart';

/// Immutable Series administrative audit record.
class SeriesAuditLogModel extends Equatable {
  const SeriesAuditLogModel({
    required this.id,
    required this.seriesId,
    required this.actorUserId,
    required this.action,
    this.actorRole = '',
    this.clubId,
    this.targetType = '',
    this.targetId = '',
    this.previousState = const <String, dynamic>{},
    this.newState = const <String, dynamic>{},
    this.reason = '',
    this.metadata = const <String, dynamic>{},
    this.timestamp,
  });

  final String id;
  final String seriesId;
  final String? clubId;
  final String actorUserId;
  final String actorRole;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> previousState;
  final Map<String, dynamic> newState;
  final String reason;
  final Map<String, dynamic> metadata;
  final DateTime? timestamp;

  factory SeriesAuditLogModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesAuditLogModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      clubId: map['clubId'] as String?,
      actorUserId: map['actorUserId'] as String? ?? '',
      actorRole: map['actorRole'] as String? ?? '',
      action: map['action'] as String? ?? '',
      targetType: map['targetType'] as String? ?? '',
      targetId: map['targetId'] as String? ?? '',
      previousState: Map<String, dynamic>.from(
        map['previousState'] as Map? ?? const <String, dynamic>{},
      ),
      newState: Map<String, dynamic>.from(
        map['newState'] as Map? ?? const <String, dynamic>{},
      ),
      reason: map['reason'] as String? ?? '',
      metadata: Map<String, dynamic>.from(
        map['metadata'] as Map? ?? const <String, dynamic>{},
      ),
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'seriesId': seriesId,
        if (clubId != null) 'clubId': clubId,
        'actorUserId': actorUserId,
        'actorRole': actorRole,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'previousState': previousState,
        'newState': newState,
        'reason': reason,
        'metadata': metadata,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, seriesId, action, actorUserId, timestamp];
}
