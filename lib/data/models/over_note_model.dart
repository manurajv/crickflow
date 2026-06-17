import 'package:equatable/equatable.dart';

/// Scorer note when an over ends with a different legal-ball count than configured.
class OverNoteModel extends Equatable {
  const OverNoteModel({
    required this.inningsNumber,
    required this.overNumber,
    required this.expectedBalls,
    required this.actualBalls,
    required this.reason,
    required this.createdAt,
    this.scorerId,
    this.ballEventId,
  });

  final int inningsNumber;
  final int overNumber;
  final int expectedBalls;
  final int actualBalls;
  final String reason;
  final DateTime createdAt;
  final String? scorerId;
  final String? ballEventId;

  factory OverNoteModel.fromMap(Map<String, dynamic> map) {
    return OverNoteModel(
      inningsNumber: map['inningsNumber'] as int? ?? 1,
      overNumber: map['overNumber'] as int? ?? 0,
      expectedBalls: map['expectedBalls'] as int? ?? 6,
      actualBalls: map['actualBalls'] as int? ?? 6,
      reason: map['reason'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      scorerId: map['scorerId'] as String?,
      ballEventId: map['ballEventId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'inningsNumber': inningsNumber,
        'overNumber': overNumber,
        'expectedBalls': expectedBalls,
        'actualBalls': actualBalls,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
        if (scorerId != null) 'scorerId': scorerId,
        if (ballEventId != null) 'ballEventId': ballEventId,
      };

  OverNoteModel copyWith({String? ballEventId, String? scorerId}) {
    return OverNoteModel(
      inningsNumber: inningsNumber,
      overNumber: overNumber,
      expectedBalls: expectedBalls,
      actualBalls: actualBalls,
      reason: reason,
      createdAt: createdAt,
      scorerId: scorerId ?? this.scorerId,
      ballEventId: ballEventId ?? this.ballEventId,
    );
  }

  @override
  List<Object?> get props =>
      [inningsNumber, overNumber, expectedBalls, actualBalls, ballEventId];
}
