import 'package:equatable/equatable.dart';
import 'location_model.dart';

class TeamStatsModel extends Equatable {
  const TeamStatsModel({
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.matchesTied = 0,
    this.points = 0,
    this.netRunRate = 0,
    this.totalRunsScored = 0,
    this.totalWicketsTaken = 0,
    this.totalWicketsLost = 0,
  });

  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int matchesTied;
  final int points;
  final double netRunRate;
  final int totalRunsScored;
  final int totalWicketsTaken;
  final int totalWicketsLost;

  factory TeamStatsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TeamStatsModel();
    return TeamStatsModel(
      matchesPlayed: map['matchesPlayed'] as int? ?? 0,
      matchesWon: map['matchesWon'] as int? ?? 0,
      matchesLost: map['matchesLost'] as int? ?? 0,
      matchesTied: map['matchesTied'] as int? ?? 0,
      points: map['points'] as int? ?? 0,
      netRunRate: (map['netRunRate'] as num?)?.toDouble() ?? 0,
      totalRunsScored: map['totalRunsScored'] as int? ?? 0,
      totalWicketsTaken: map['totalWicketsTaken'] as int? ?? 0,
      totalWicketsLost: map['totalWicketsLost'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'matchesPlayed': matchesPlayed,
    'matchesWon': matchesWon,
    'matchesLost': matchesLost,
    'matchesTied': matchesTied,
    'points': points,
    'netRunRate': netRunRate,
    'totalRunsScored': totalRunsScored,
    'totalWicketsTaken': totalWicketsTaken,
    'totalWicketsLost': totalWicketsLost,
  };

  @override
  List<Object?> get props => [matchesPlayed, matchesWon, points];
}

class TeamModel extends Equatable {
  const TeamModel({
    required this.id,
    required this.name,
    this.teamCode,
    this.qrUrl,
    this.logoUrl,
    this.teamProfileImageUrl,
    this.teamCoverImageUrl,
    this.captainId,
    this.viceCaptainId,
    this.coachName,
    this.contactNumber,
    this.playerIds = const [],
    this.memberCount = 0,
    this.location = const LocationModel(),
    this.stats = const TeamStatsModel(),
    this.badgeIds = const [],
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? teamCode;
  final String? qrUrl;

  /// Legacy field — mirrored from [teamProfileImageUrl] when saving.
  final String? logoUrl;
  final String? teamProfileImageUrl;
  final String? teamCoverImageUrl;
  final String? captainId;
  final String? viceCaptainId;
  final String? coachName;
  final String? contactNumber;
  final List<String> playerIds;
  final int memberCount;
  final LocationModel location;
  final TeamStatsModel stats;
  final List<String> badgeIds;
  final String? createdBy;
  final DateTime? createdAt;

  String? get profileImageUrl =>
      _nonEmpty(teamProfileImageUrl) ?? _nonEmpty(logoUrl);

  String? get coverImageUrl => _nonEmpty(teamCoverImageUrl);

  static String? _nonEmpty(String? value) =>
      value != null && value.isNotEmpty ? value : null;

  factory TeamModel.fromMap(String id, Map<String, dynamic> map) {
    final profile =
        map['teamProfileImageUrl'] as String? ?? map['logoUrl'] as String?;
    return TeamModel(
      id: id,
      name: map['name'] as String? ?? '',
      teamCode: map['teamCode'] as String?,
      qrUrl: map['qrUrl'] as String?,
      logoUrl: profile,
      teamProfileImageUrl: profile,
      teamCoverImageUrl: map['teamCoverImageUrl'] as String?,
      captainId: map['captainId'] as String?,
      viceCaptainId: map['viceCaptainId'] as String?,
      coachName: map['coachName'] as String?,
      contactNumber: map['contactNumber'] as String?,
      playerIds: List<String>.from(map['playerIds'] as List? ?? []),
      memberCount:
          map['memberCount'] as int? ??
          (map['playerIds'] as List?)?.length ??
          0,
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      stats: TeamStatsModel.fromMap(map['stats'] as Map<String, dynamic>?),
      badgeIds: List<String>.from(map['badgeIds'] as List? ?? []),
      createdBy: map['createdBy'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (teamCode != null) 'teamCode': teamCode,
    if (qrUrl != null) 'qrUrl': qrUrl,
    if (profileImageUrl != null) ...{
      'teamProfileImageUrl': profileImageUrl,
      'logoUrl': profileImageUrl,
    },
    if (coverImageUrl != null) 'teamCoverImageUrl': coverImageUrl,
    if (captainId != null) 'captainId': captainId,
    if (viceCaptainId != null) 'viceCaptainId': viceCaptainId,
    if (coachName != null) 'coachName': coachName,
    if (contactNumber != null) 'contactNumber': contactNumber,
    'playerIds': playerIds,
    'memberCount': memberCount > 0 ? memberCount : playerIds.length,
    'location': location.toMap(),
    'stats': stats.toMap(),
    'badgeIds': badgeIds,
    if (createdBy != null) 'createdBy': createdBy,
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };

  TeamModel copyWith({
    String? name,
    String? teamCode,
    String? qrUrl,
    String? logoUrl,
    String? teamProfileImageUrl,
    String? teamCoverImageUrl,
    String? captainId,
    String? viceCaptainId,
    bool clearCaptain = false,
    bool clearViceCaptain = false,
    String? coachName,
    String? contactNumber,
    List<String>? playerIds,
    int? memberCount,
    LocationModel? location,
    TeamStatsModel? stats,
    List<String>? badgeIds,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return TeamModel(
      id: id,
      name: name ?? this.name,
      teamCode: teamCode ?? this.teamCode,
      qrUrl: qrUrl ?? this.qrUrl,
      logoUrl: teamProfileImageUrl ?? logoUrl ?? this.logoUrl,
      teamProfileImageUrl:
          teamProfileImageUrl ?? this.teamProfileImageUrl ?? this.logoUrl,
      teamCoverImageUrl: teamCoverImageUrl ?? this.teamCoverImageUrl,
      captainId: clearCaptain ? null : (captainId ?? this.captainId),
      viceCaptainId: clearViceCaptain
          ? null
          : (viceCaptainId ?? this.viceCaptainId),
      coachName: coachName ?? this.coachName,
      contactNumber: contactNumber ?? this.contactNumber,
      playerIds: playerIds ?? this.playerIds,
      memberCount: memberCount ?? this.memberCount,
      location: location ?? this.location,
      stats: stats ?? this.stats,
      badgeIds: badgeIds ?? this.badgeIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
