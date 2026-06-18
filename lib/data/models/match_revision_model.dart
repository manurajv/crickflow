import 'package:equatable/equatable.dart';

/// Append-only target / innings revision record under `matchRevisions/`.
class MatchRevisionModel extends Equatable {
  const MatchRevisionModel({
    required this.id,
    required this.type,
    this.revisionMethod,
    this.originalOvers,
    this.revisedOvers,
    this.oversLost,
    this.oldTarget,
    this.newTarget,
    this.reason = '',
    this.penaltyRuns,
    this.createdBy = '',
    this.createdAt,
  });

  final String id;
  final String type;
  final String? revisionMethod;
  final int? originalOvers;
  final int? revisedOvers;
  final int? oversLost;
  final int? oldTarget;
  final int? newTarget;
  final String reason;
  final int? penaltyRuns;
  final String createdBy;
  final DateTime? createdAt;

  factory MatchRevisionModel.fromMap(String id, Map<String, dynamic> map) {
    return MatchRevisionModel(
      id: id,
      type: map['type'] as String? ?? '',
      revisionMethod: map['revisionMethod'] as String?,
      originalOvers: map['originalOvers'] as int?,
      revisedOvers: map['revisedOvers'] as int?,
      oversLost: map['oversLost'] as int?,
      oldTarget: map['oldTarget'] as int?,
      newTarget: map['newTarget'] as int?,
      reason: map['reason'] as String? ?? '',
      penaltyRuns: map['penaltyRuns'] as int?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        if (revisionMethod != null) 'revisionMethod': revisionMethod,
        if (originalOvers != null) 'originalOvers': originalOvers,
        if (revisedOvers != null) 'revisedOvers': revisedOvers,
        if (oversLost != null) 'oversLost': oversLost,
        if (oldTarget != null) 'oldTarget': oldTarget,
        if (newTarget != null) 'newTarget': newTarget,
        if (reason.isNotEmpty) 'reason': reason,
        if (penaltyRuns != null) 'penaltyRuns': penaltyRuns,
        if (createdBy.isNotEmpty) 'createdBy': createdBy,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  @override
  List<Object?> get props => [id, type, newTarget];
}
