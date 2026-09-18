import 'package:equatable/equatable.dart';

import 'series_enums.dart';

/// Series competition wrapper (single match or tournament).
class SeriesCompetitionModel extends Equatable {
  const SeriesCompetitionModel({
    required this.id,
    required this.seriesId,
    required this.type,
    this.title = '',
    this.clubAId,
    this.clubBId,
    this.matchId,
    this.tournamentId,
    this.status = SeriesOfficialStatus.draft,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.approvedBy,
  });

  final String id;
  final String seriesId;
  final SeriesCompetitionType type;
  final String title;
  final String? clubAId;
  final String? clubBId;
  final String? matchId;
  final String? tournamentId;
  final SeriesOfficialStatus status;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  bool get isOfficial => status == SeriesOfficialStatus.approved;

  factory SeriesCompetitionModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesCompetitionModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      type: SeriesCompetitionType.parse(map['type'] as String?),
      title: map['title'] as String? ?? '',
      clubAId: map['clubAId'] as String?,
      clubBId: map['clubBId'] as String?,
      matchId: map['matchId'] as String?,
      tournamentId: map['tournamentId'] as String?,
      status: SeriesOfficialStatus.parse(map['status'] as String?),
      createdBy: map['createdBy'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
      approvedAt: DateTime.tryParse(map['approvedAt']?.toString() ?? ''),
      approvedBy: map['approvedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'seriesId': seriesId,
        'type': type.name,
        'title': title,
        if (clubAId != null) 'clubAId': clubAId,
        if (clubBId != null) 'clubBId': clubBId,
        if (matchId != null) 'matchId': matchId,
        if (tournamentId != null) 'tournamentId': tournamentId,
        'status': status.name,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
        if (approvedBy != null) 'approvedBy': approvedBy,
      };

  @override
  List<Object?> get props => [id, seriesId, type, status, matchId, tournamentId];
}
