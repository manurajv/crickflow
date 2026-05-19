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
    this.logoUrl,
    this.captainId,
    this.viceCaptainId,
    this.coachName,
    this.playerIds = const [],
    this.location = const LocationModel(),
    this.stats = const TeamStatsModel(),
    this.badgeIds = const [],
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? captainId;
  final String? viceCaptainId;
  final String? coachName;
  final List<String> playerIds;
  final LocationModel location;
  final TeamStatsModel stats;
  final List<String> badgeIds;
  final String? createdBy;
  final DateTime? createdAt;

  factory TeamModel.fromMap(String id, Map<String, dynamic> map) {
    return TeamModel(
      id: id,
      name: map['name'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      captainId: map['captainId'] as String?,
      viceCaptainId: map['viceCaptainId'] as String?,
      coachName: map['coachName'] as String?,
      playerIds: List<String>.from(map['playerIds'] as List? ?? []),
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      stats: TeamStatsModel.fromMap(map['stats'] as Map<String, dynamic>?),
      badgeIds: List<String>.from(map['badgeIds'] as List? ?? []),
      createdBy: map['createdBy'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (captainId != null) 'captainId': captainId,
        if (viceCaptainId != null) 'viceCaptainId': viceCaptainId,
        if (coachName != null) 'coachName': coachName,
        'playerIds': playerIds,
        'location': location.toMap(),
        'stats': stats.toMap(),
        'badgeIds': badgeIds,
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name];
}
