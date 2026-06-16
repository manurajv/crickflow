import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
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
    this.highScore = 0,
    this.thirties = 0,
    this.fifties = 0,
    this.hundreds = 0,
    this.ducks = 0,
    this.threeWickets = 0,
    this.fiveWickets = 0,
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
  final int highScore;
  final int thirties;
  final int fifties;
  final int hundreds;
  final int ducks;
  final int threeWickets;
  final int fiveWickets;

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
      highScore: map['highScore'] as int? ?? 0,
      thirties: map['thirties'] as int? ?? 0,
      fifties: map['fifties'] as int? ?? 0,
      hundreds: map['hundreds'] as int? ?? 0,
      ducks: map['ducks'] as int? ?? 0,
      threeWickets: map['threeWickets'] as int? ?? 0,
      fiveWickets: map['fiveWickets'] as int? ?? 0,
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
    'highScore': highScore,
    'thirties': thirties,
    'fifties': fifties,
    'hundreds': hundreds,
    'ducks': ducks,
    'threeWickets': threeWickets,
    'fiveWickets': fiveWickets,
  };

  @override
  List<Object?> get props => [runs, wickets, matchesPlayed];
}

class PlayerModel extends Equatable {
  const PlayerModel({
    required this.id,
    required this.name,
    this.fullName = '',
    this.teamId,
    this.teamIds = const [],
    this.userId,
    this.playerId,
    this.jerseyNumber,
    this.battingStyle = '',
    this.bowlingStyle = '',
    this.photoUrl,
    this.role = '',
    this.location = const LocationModel(),
    this.stats = const PlayerStatsModel(),
    this.statsByBallType = const {},
    this.badgeIds = const [],
    this.createdBy,
    this.createdAt,
    this.teamJoinedAt,
  });

  final String id;

  /// Public scorecard / display name.
  final String name;

  /// Legal full name — shown on squad roster (not display name).
  final String fullName;
  /// Legacy single-team field — prefer [teamIds]. Kept for older docs.
  final String? teamId;

  /// All teams this player belongs to (club cricket: multiple teams).
  final List<String> teamIds;

  /// Firebase Auth uid when this profile belongs to a registered player account.
  final String? userId;

  /// Public sequential ID (e.g. CF000001) — synced from user profile.
  final String? playerId;
  final int? jerseyNumber;
  final String battingStyle;
  final String bowlingStyle;
  final String? photoUrl;
  final String role;
  final LocationModel location;
  final PlayerStatsModel stats;
  final Map<CricketBallType, PlayerStatsModel> statsByBallType;
  final List<String> badgeIds;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? teamJoinedAt;

  DateTime get effectiveJoinedAt => teamJoinedAt ?? createdAt ?? DateTime(2100);

  /// Every team id this profile is linked to (legacy [teamId] included).
  List<String> get effectiveTeamIds {
    final ids = <String>{...teamIds};
    final legacy = teamId;
    if (legacy != null && legacy.isNotEmpty) ids.add(legacy);
    return ids.toList();
  }

  bool isOnTeam(String id) => effectiveTeamIds.contains(id);

  String get effectiveFullName =>
      fullName.isNotEmpty ? fullName : name;

  PlayerStatsModel statsForBallType(CricketBallType type) =>
      statsByBallType[type] ?? const PlayerStatsModel();

  factory PlayerModel.fromMap(String id, Map<String, dynamic> map) {
    return PlayerModel(
      id: id,
      name: map['name'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      teamId: map['teamId'] as String?,
      teamIds: _teamIdsFromMap(map),
      userId: map['userId'] as String?,
      playerId: map['playerId'] as String? ?? map['cfPlayerId'] as String?,
      jerseyNumber: map['jerseyNumber'] as int?,
      battingStyle: map['battingStyle'] as String? ?? '',
      bowlingStyle: map['bowlingStyle'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String? ?? '',
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      stats: PlayerStatsModel.fromMap(map['stats'] as Map<String, dynamic>?),
      statsByBallType: _statsByBallTypeFromMap(
        map['statsByBallType'] as Map<String, dynamic>?,
      ),
      badgeIds: List<String>.from(map['badgeIds'] as List? ?? []),
      createdBy: map['createdBy'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      teamJoinedAt: DateTime.tryParse(map['teamJoinedAt']?.toString() ?? ''),
    );
  }

  static List<String> _teamIdsFromMap(Map<String, dynamic> map) {
    final fromList = List<String>.from(map['teamIds'] as List? ?? []);
    if (fromList.isNotEmpty) return fromList;
    final legacy = map['teamId'] as String?;
    if (legacy != null && legacy.isNotEmpty) return [legacy];
    return const [];
  }

  static Map<CricketBallType, PlayerStatsModel> _statsByBallTypeFromMap(
    Map<String, dynamic>? map,
  ) {
    if (map == null) return {};
    final out = <CricketBallType, PlayerStatsModel>{};
    for (final type in CricketBallType.values) {
      final raw = map[type.name];
      if (raw is Map<String, dynamic>) {
        out[type] = PlayerStatsModel.fromMap(raw);
      }
    }
    return out;
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (fullName.isNotEmpty) 'fullName': fullName,
    if (teamId != null) 'teamId': teamId,
    if (teamIds.isNotEmpty) 'teamIds': teamIds,
    if (userId != null) 'userId': userId,
    if (playerId != null) 'playerId': playerId,
    if (jerseyNumber != null) 'jerseyNumber': jerseyNumber,
    'battingStyle': battingStyle,
    'bowlingStyle': bowlingStyle,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'role': role,
    'location': location.toMap(),
    'stats': stats.toMap(),
    if (statsByBallType.isNotEmpty)
      'statsByBallType': {
        for (final e in statsByBallType.entries) e.key.name: e.value.toMap(),
      },
    'badgeIds': badgeIds,
    if (createdBy != null) 'createdBy': createdBy,
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    if (teamJoinedAt != null) 'teamJoinedAt': teamJoinedAt!.toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };

  PlayerModel copyWith({
    String? name,
    String? fullName,
    String? teamId,
    List<String>? teamIds,
    String? userId,
    String? playerId,
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
      fullName: fullName ?? this.fullName,
      teamId: teamId ?? this.teamId,
      teamIds: teamIds ?? this.teamIds,
      userId: userId ?? this.userId,
      playerId: playerId ?? this.playerId,
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
  List<Object?> get props => [id, name, teamId, teamIds];
}
