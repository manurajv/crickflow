import 'package:equatable/equatable.dart';

/// Persisted over / segment metadata for replay and over history.
class OverMetadataModel extends Equatable {
  const OverMetadataModel({
    required this.inningsNumber,
    required this.overNumber,
    required this.ballsPerOverExpected,
    required this.createdAt,
    this.segment,
    this.bowlerId,
    this.actualBallsBowled,
    this.segmentLegalBalls,
    this.manuallyEnded = false,
    this.continuedBeyondLimit = false,
    this.reason,
    this.ballEventId,
  });

  final int inningsNumber;
  /// 1-based over number.
  final int overNumber;
  /// Segment within the over (1 = A, 2 = B, …). Null for whole-over summary.
  final int? segment;
  final String? bowlerId;
  final int ballsPerOverExpected;
  /// Legal deliveries in the completed over (whole-over summary).
  final int? actualBallsBowled;
  /// Legal deliveries in a closed segment (mid-over bowler change).
  final int? segmentLegalBalls;
  final bool manuallyEnded;
  final bool continuedBeyondLimit;
  final String? reason;
  final String? ballEventId;
  final DateTime createdAt;

  factory OverMetadataModel.fromMap(Map<String, dynamic> map) {
    return OverMetadataModel(
      inningsNumber: map['inningsNumber'] as int? ?? 1,
      overNumber: map['overNumber'] as int? ?? 1,
      segment: map['segment'] as int?,
      bowlerId: map['bowlerId'] as String?,
      ballsPerOverExpected: map['ballsPerOverExpected'] as int? ?? 6,
      actualBallsBowled: map['actualBallsBowled'] as int?,
      segmentLegalBalls: map['segmentLegalBalls'] as int?,
      manuallyEnded: map['manuallyEnded'] as bool? ?? false,
      continuedBeyondLimit: map['continuedBeyondLimit'] as bool? ?? false,
      reason: map['reason'] as String?,
      ballEventId: map['ballEventId'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'inningsNumber': inningsNumber,
        'overNumber': overNumber,
        if (segment != null) 'segment': segment,
        if (bowlerId != null) 'bowlerId': bowlerId,
        'ballsPerOverExpected': ballsPerOverExpected,
        if (actualBallsBowled != null) 'actualBallsBowled': actualBallsBowled,
        if (segmentLegalBalls != null) 'segmentLegalBalls': segmentLegalBalls,
        'manuallyEnded': manuallyEnded,
        'continuedBeyondLimit': continuedBeyondLimit,
        if (reason != null && reason!.isNotEmpty) 'reason': reason,
        if (ballEventId != null) 'ballEventId': ballEventId,
        'createdAt': createdAt.toIso8601String(),
      };

  OverMetadataModel copyWith({String? ballEventId, String? reason}) {
    return OverMetadataModel(
      inningsNumber: inningsNumber,
      overNumber: overNumber,
      segment: segment,
      bowlerId: bowlerId,
      ballsPerOverExpected: ballsPerOverExpected,
      actualBallsBowled: actualBallsBowled,
      segmentLegalBalls: segmentLegalBalls,
      manuallyEnded: manuallyEnded,
      continuedBeyondLimit: continuedBeyondLimit,
      reason: reason ?? this.reason,
      ballEventId: ballEventId ?? this.ballEventId,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [inningsNumber, overNumber, segment, bowlerId, ballEventId];
}
