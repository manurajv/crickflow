import 'package:equatable/equatable.dart';

import '../../domain/streaming_enums.dart';

class ReplayMarkerModel extends Equatable {
  const ReplayMarkerModel({
    required this.id,
    required this.matchId,
    required this.kind,
    required this.label,
    required this.streamOffsetMs,
    required this.createdBy,
    this.ballEventId,
    this.createdAt,
    this.streamSessionId = '',
    this.playbackUrl,
    this.streamSessionStartedAt,
    this.streamSessionEndedAt,
  });

  final String id;
  final String matchId;
  final ReplayMarkerKind kind;
  final String label;
  final int streamOffsetMs;
  final String createdBy;
  final String? ballEventId;
  final DateTime? createdAt;
  /// Stable id for the live session (`playbackEntries.sessionId` or fallback key).
  final String streamSessionId;
  final String? playbackUrl;
  final DateTime? streamSessionStartedAt;
  final DateTime? streamSessionEndedAt;

  factory ReplayMarkerModel.fromMap(String id, Map<String, dynamic> map) {
    return ReplayMarkerModel(
      id: id,
      matchId: map['matchId'] as String? ?? '',
      kind: ReplayMarkerKind.values.firstWhere(
        (e) => e.name == map['kind'],
        orElse: () => ReplayMarkerKind.custom,
      ),
      label: map['label'] as String? ?? '',
      streamOffsetMs: map['streamOffsetMs'] as int? ?? 0,
      createdBy: map['createdBy'] as String? ?? '',
      ballEventId: map['ballEventId'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      streamSessionId: map['streamSessionId'] as String? ?? '',
      playbackUrl: map['playbackUrl'] as String?,
      streamSessionStartedAt:
          DateTime.tryParse(map['streamSessionStartedAt']?.toString() ?? ''),
      streamSessionEndedAt:
          DateTime.tryParse(map['streamSessionEndedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'matchId': matchId,
        'kind': kind.name,
        'label': label,
        'streamOffsetMs': streamOffsetMs,
        'createdBy': createdBy,
        if (ballEventId != null) 'ballEventId': ballEventId,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        if (streamSessionId.isNotEmpty) 'streamSessionId': streamSessionId,
        if (playbackUrl != null && playbackUrl!.isNotEmpty)
          'playbackUrl': playbackUrl,
        if (streamSessionStartedAt != null)
          'streamSessionStartedAt': streamSessionStartedAt!.toIso8601String(),
        if (streamSessionEndedAt != null)
          'streamSessionEndedAt': streamSessionEndedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, matchId, streamSessionId, streamOffsetMs, createdAt];
}
