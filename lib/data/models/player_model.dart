import 'package:equatable/equatable.dart';
import 'location_model.dart';

class PlayerStatsModel extends Equatable {
  const PlayerStatsModel({
    this.runs = 0,
    this.ballsFaced = 0,
    this.fours = 0,
    this.sixes = 0,
    this.wickets = 0,
    this.oversBowledBalls = 0,
    this.runsConceded = 0,
    this.catches = 0,
    this.runOuts = 0,
    this.stumpings = 0,
    this.matchesPlayed = 0,
    this.inningsPlayed = 0,
    this.dismissals = 0,
  });

  final int runs;
  final int ballsFaced;
  final int fours;
  final int sixes;
  final int wickets;
  final int oversBowledBalls;
  final int runsConceded;
  final int catches;
  final int runOuts;
  final int stumpings;
  final int matchesPlayed;
  final int inningsPlayed;
  final int dismissals;

  factory PlayerStatsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlayerStatsModel();
    return PlayerStatsModel(
      runs: map['runs'] as int? ?? 0,
      ballsFaced: map['ballsFaced'] as int? ?? 0,
      fours: map['fours'] as int? ?? 0,
      sixes: map['sixes'] as int? ?? 0,
      wickets: map['wickets'] as int? ?? 0,
      oversBowledBalls: map['oversBowledBalls'] as int? ?? 0,
      runsConceded: map['runsConceded'] as int? ?? 0,
      catches: map['catches'] as int? ?? 0,
      runOuts: map['runOuts'] as int? ?? 0,
      stumpings: map['stumpings'] as int? ?? 0,
      matchesPlayed: map['matchesPlayed'] as int? ?? 0,
      inningsPlayed: map['inningsPlayed'] as int? ?? 0,
      dismissals: map['dismissals'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'runs': runs,
        'ballsFaced': ballsFaced,
        'fours': fours,
        'sixes': sixes,
        'wickets': wickets,
        'oversBowledBalls': oversBowledBalls,
        'runsConceded': runsConceded,
        'catches': catches,
        'runOuts': runOuts,
        'stumpings': stumpings,
        'matchesPlayed': matchesPlayed,
        'inningsPlayed': inningsPlayed,
        'dismissals': dismissals,
      };

  @override
  List<Object?> get props => [runs, wickets, matchesPlayed];
}

class PlayerModel extends Equatable {
  const PlayerModel({
    required this.id,
    required this.name,
    this.teamId,
    this.userId,
    this.jerseyNumber,
    this.battingStyle = '',
    this.bowlingStyle = '',
    this.photoUrl,
    this.role = '',
    this.location = const LocationModel(),
    this.stats = const PlayerStatsModel(),
    this.badgeIds = const [],
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? teamId;
  /// Firebase Auth uid when this profile belongs to a registered player account.
  final String? userId;
  final int? jerseyNumber;
  final String battingStyle;
  final String bowlingStyle;
  final String? photoUrl;
  final String role;
  final LocationModel location;
  final PlayerStatsModel stats;
  final List<String> badgeIds;
  final String? createdBy;
  final DateTime? createdAt;

  factory PlayerModel.fromMap(String id, Map<String, dynamic> map) {
    return PlayerModel(
      id: id,
      name: map['name'] as String? ?? '',
      teamId: map['teamId'] as String?,
      userId: map['userId'] as String?,
      jerseyNumber: map['jerseyNumber'] as int?,
      battingStyle: map['battingStyle'] as String? ?? '',
      bowlingStyle: map['bowlingStyle'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String? ?? '',
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      stats: PlayerStatsModel.fromMap(map['stats'] as Map<String, dynamic>?),
      badgeIds: List<String>.from(map['badgeIds'] as List? ?? []),
      createdBy: map['createdBy'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (teamId != null) 'teamId': teamId,
        if (userId != null) 'userId': userId,
        if (jerseyNumber != null) 'jerseyNumber': jerseyNumber,
        'battingStyle': battingStyle,
        'bowlingStyle': bowlingStyle,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'role': role,
        'location': location.toMap(),
        'stats': stats.toMap(),
        'badgeIds': badgeIds,
        if (createdBy != null) 'createdBy': createdBy,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  PlayerModel copyWith({
    String? name,
    String? teamId,
    String? userId,
    int? jerseyNumber,
    String? battingStyle,
    String? bowlingStyle,
    String? photoUrl,
    String? role,
    LocationModel? location,
    PlayerStatsModel? stats,
    List<String>? badgeIds,
  }) {
    return PlayerModel(
      id: id,
      name: name ?? this.name,
      teamId: teamId ?? this.teamId,
      userId: userId ?? this.userId,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      battingStyle: battingStyle ?? this.battingStyle,
      bowlingStyle: bowlingStyle ?? this.bowlingStyle,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      location: location ?? this.location,
      stats: stats ?? this.stats,
      badgeIds: badgeIds ?? this.badgeIds,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, teamId];
}
