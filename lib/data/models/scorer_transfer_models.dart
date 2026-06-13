import 'package:equatable/equatable.dart';

/// One entry in [MatchModel.scorerTransferHistory].
class ScorerTransferRecord extends Equatable {
  const ScorerTransferRecord({
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.timestamp,
  });

  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final DateTime timestamp;

  factory ScorerTransferRecord.fromMap(Map<String, dynamic> map) {
    return ScorerTransferRecord(
      fromUserId: map['fromUserId'] as String? ?? '',
      fromUserName: map['fromUserName'] as String? ?? '',
      toUserId: map['toUserId'] as String? ?? '',
      toUserName: map['toUserName'] as String? ?? '',
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'toUserId': toUserId,
        'toUserName': toUserName,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [fromUserId, fromUserName, toUserId, toUserName, timestamp];
}
