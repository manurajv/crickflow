import 'package:equatable/equatable.dart';

import 'series_enums.dart';

/// Reusable Series approval workflow document.
class SeriesApprovalModel extends Equatable {
  const SeriesApprovalModel({
    required this.id,
    required this.seriesId,
    required this.targetType,
    required this.targetId,
    required this.requestedBy,
    this.clubId,
    this.status = SeriesApprovalStatus.pending,
    this.reviewedBy,
    this.requestedAt,
    this.reviewedAt,
    this.reason = '',
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String seriesId;
  final String? clubId;
  final SeriesApprovalTargetType targetType;
  final String targetId;
  final SeriesApprovalStatus status;
  final String requestedBy;
  final String? reviewedBy;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final String reason;
  final Map<String, dynamic> metadata;

  bool get isPending => status == SeriesApprovalStatus.pending;

  factory SeriesApprovalModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesApprovalModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      clubId: map['clubId'] as String?,
      targetType: SeriesApprovalTargetType.parse(map['targetType'] as String?),
      targetId: map['targetId'] as String? ?? '',
      status: SeriesApprovalStatus.parse(map['status'] as String?),
      requestedBy: map['requestedBy'] as String? ?? '',
      reviewedBy: map['reviewedBy'] as String?,
      requestedAt: DateTime.tryParse(map['requestedAt']?.toString() ?? ''),
      reviewedAt: DateTime.tryParse(map['reviewedAt']?.toString() ?? ''),
      reason: map['reason'] as String? ?? '',
      metadata: Map<String, dynamic>.from(
        map['metadata'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'seriesId': seriesId,
        if (clubId != null) 'clubId': clubId,
        'targetType': targetType.name,
        'targetId': targetId,
        'status': status.name,
        'requestedBy': requestedBy,
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (requestedAt != null) 'requestedAt': requestedAt!.toIso8601String(),
        if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
        'reason': reason,
        'metadata': metadata,
      };

  @override
  List<Object?> get props => [id, seriesId, targetType, targetId, status];
}
