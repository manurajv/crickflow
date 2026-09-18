import 'package:equatable/equatable.dart';

import 'series_enums.dart';

class SeriesAdminModel extends Equatable {
  const SeriesAdminModel({
    required this.id,
    required this.seriesId,
    required this.userId,
    this.displayName = '',
    this.permissions = const <String>[],
    this.status = 'active',
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String seriesId;
  final String userId;
  final String displayName;
  final List<String> permissions;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;

  factory SeriesAdminModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesAdminModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      permissions: List<String>.from(map['permissions'] as List? ?? const []),
      status: map['status'] as String? ?? 'active',
      createdBy: map['createdBy'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'seriesId': seriesId,
        'userId': userId,
        'displayName': displayName,
        'permissions': permissions,
        'status': status,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, seriesId, userId, status];
}

class SeriesClubModel extends Equatable {
  const SeriesClubModel({
    required this.id,
    required this.seriesId,
    required this.name,
    this.description = '',
    this.logoUrl,
    this.linkedTeamId,
    this.status = SeriesClubStatus.pending,
    this.createdBy,
    this.squadCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String seriesId;
  final String name;
  final String description;
  final String? logoUrl;
  final String? linkedTeamId;
  final SeriesClubStatus status;
  final String? createdBy;
  final int squadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isApproved => status == SeriesClubStatus.approved;

  factory SeriesClubModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesClubModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      name: map['name'] as String? ?? 'Club',
      description: map['description'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      linkedTeamId: map['linkedTeamId'] as String?,
      status: SeriesClubStatus.parse(map['status'] as String?),
      createdBy: map['createdBy'] as String?,
      squadCount: (map['squadCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'seriesId': seriesId,
        'name': name,
        'description': description,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (linkedTeamId != null) 'linkedTeamId': linkedTeamId,
        'status': status.name,
        if (createdBy != null) 'createdBy': createdBy,
        'squadCount': squadCount,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, seriesId, name, status];
}

class SeriesClubAdminModel extends Equatable {
  const SeriesClubAdminModel({
    required this.id,
    required this.seriesId,
    required this.clubId,
    required this.userId,
    this.displayName = '',
    this.status = 'active',
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String seriesId;
  final String clubId;
  final String userId;
  final String displayName;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;

  factory SeriesClubAdminModel.fromMap(String id, Map<String, dynamic> map) {
    return SeriesClubAdminModel(
      id: id,
      seriesId: map['seriesId'] as String? ?? '',
      clubId: map['clubId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      createdBy: map['createdBy'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'seriesId': seriesId,
        'clubId': clubId,
        'userId': userId,
        'displayName': displayName,
        'status': status,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, seriesId, clubId, userId];
}
