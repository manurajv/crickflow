import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import 'bracket_models.dart';
import 'location_model.dart';
import 'tournament/tournament_rules_model.dart';
import 'tournament/tournament_setup_meta.dart';

class PointsTableEntry extends Equatable {
  const PointsTableEntry({
    required this.teamId,
    this.teamName = '',
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.noResult = 0,
    this.points = 0,
    this.netRunRate = 0,
    this.position = 0,
    this.runsFor = 0,
    this.oversFaced = 0,
    this.runsAgainst = 0,
    this.oversBowled = 0,
    this.bonusPoints = 0,
    this.penaltyPoints = 0,
  });

  final String teamId;
  final String teamName;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int noResult;
  final int points;
  final double netRunRate;
  final int position;
  final int runsFor;
  final double oversFaced;
  final int runsAgainst;
  final double oversBowled;
  final int bonusPoints;
  final int penaltyPoints;

  factory PointsTableEntry.fromMap(Map<String, dynamic> map) {
    return PointsTableEntry(
      teamId: map['teamId'] as String? ?? '',
      teamName: map['teamName'] as String? ?? '',
      played: map['played'] as int? ?? 0,
      won: map['won'] as int? ?? 0,
      lost: map['lost'] as int? ?? 0,
      tied: map['tied'] as int? ?? 0,
      noResult: map['noResult'] as int? ?? 0,
      points: map['points'] as int? ?? 0,
      netRunRate: (map['netRunRate'] as num?)?.toDouble() ?? 0,
      position: map['position'] as int? ?? 0,
      runsFor: map['runsFor'] as int? ?? 0,
      oversFaced: (map['oversFaced'] as num?)?.toDouble() ?? 0,
      runsAgainst: map['runsAgainst'] as int? ?? 0,
      oversBowled: (map['oversBowled'] as num?)?.toDouble() ?? 0,
      bonusPoints: map['bonusPoints'] as int? ?? 0,
      penaltyPoints: map['penaltyPoints'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'teamId': teamId,
        'teamName': teamName,
        'played': played,
        'won': won,
        'lost': lost,
        'tied': tied,
        'noResult': noResult,
        'points': points,
        'netRunRate': netRunRate,
        'position': position,
        'runsFor': runsFor,
        'oversFaced': oversFaced,
        'runsAgainst': runsAgainst,
        'oversBowled': oversBowled,
        'bonusPoints': bonusPoints,
        'penaltyPoints': penaltyPoints,
      };

  PointsTableEntry copyWith({
    String? teamName,
    int? played,
    int? won,
    int? lost,
    int? tied,
    int? noResult,
    int? points,
    double? netRunRate,
    int? position,
    int? runsFor,
    double? oversFaced,
    int? runsAgainst,
    double? oversBowled,
    int? bonusPoints,
    int? penaltyPoints,
  }) {
    return PointsTableEntry(
      teamId: teamId,
      teamName: teamName ?? this.teamName,
      played: played ?? this.played,
      won: won ?? this.won,
      lost: lost ?? this.lost,
      tied: tied ?? this.tied,
      noResult: noResult ?? this.noResult,
      points: points ?? this.points,
      netRunRate: netRunRate ?? this.netRunRate,
      position: position ?? this.position,
      runsFor: runsFor ?? this.runsFor,
      oversFaced: oversFaced ?? this.oversFaced,
      runsAgainst: runsAgainst ?? this.runsAgainst,
      oversBowled: oversBowled ?? this.oversBowled,
      bonusPoints: bonusPoints ?? this.bonusPoints,
      penaltyPoints: penaltyPoints ?? this.penaltyPoints,
    );
  }

  @override
  List<Object?> get props => [teamId, points, netRunRate, position];
}

/// Ordered finishing place (1st, 2nd, …) for a completed tournament.
class TournamentPodiumPlace extends Equatable {
  const TournamentPodiumPlace({
    required this.place,
    required this.teamId,
    required this.teamName,
  });

  final int place;
  final String teamId;
  final String teamName;

  factory TournamentPodiumPlace.fromMap(Map<String, dynamic> map) {
    return TournamentPodiumPlace(
      place: map['place'] as int? ?? 0,
      teamId: map['teamId'] as String? ?? '',
      teamName: map['teamName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'place': place,
        'teamId': teamId,
        'teamName': teamName,
      };

  static String labelFor(int place) {
    switch (place) {
      case 1:
        return 'Champion';
      case 2:
        return 'Runner-up';
      case 3:
        return 'Third place';
      case 4:
        return 'Fourth place';
      case 5:
        return 'Fifth place';
      default:
        return '${place}th place';
    }
  }

  static String emojiFor(int place) {
    switch (place) {
      case 1:
        return '🏆';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$place';
    }
  }

  @override
  List<Object?> get props => [place, teamId, teamName];
}

class TournamentModel extends Equatable {
  const TournamentModel({
    required this.id,
    required this.name,
    this.format = TournamentFormat.league,
    this.status = TournamentStatus.draft,
    this.teamIds = const [],
    this.matchIds = const [],
    this.pointsTable = const [],
    this.bracketRounds = const [],
    this.location = const LocationModel(),
    this.bannerUrl,
    this.logoUrl,
    this.thumbnailUrl,
    this.thumbnailAspect = CommunityMediaAspect.landscape16x9,
    this.grounds = const [],
    this.startDate,
    this.endDate,
    this.createdBy,
    this.organizerId,
    this.description = '',
    this.tournamentCode,
    this.entryFee,
    this.winningPrize,
    this.ballType,
    this.pitchType,
    this.defaultRules = const TournamentRulesModel(),
    this.setupMeta = const TournamentSetupMeta(),
    this.createdAt,
    this.updatedAt,
    this.championTeamId,
    this.championTeamName,
    this.runnerUpTeamId,
    this.runnerUpTeamName,
    this.thirdPlaceTeamId,
    this.thirdPlaceTeamName,
    this.podiumPlaces = const [],
    this.isLocked = false,
    this.awards = const {},
  });

  final String id;
  final String name;
  final TournamentFormat format;
  final TournamentStatus status;
  final List<String> teamIds;
  final List<String> matchIds;
  final List<PointsTableEntry> pointsTable;
  final List<List<BracketSlotModel>> bracketRounds;
  final LocationModel location;
  final String? bannerUrl;
  final String? logoUrl;
  /// Dedicated Community / feed thumbnail (falls back to [bannerUrl] in UI).
  final String? thumbnailUrl;
  final CommunityMediaAspect thumbnailAspect;
  final List<String> grounds;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Legacy field — prefer [organizerId].
  final String? createdBy;
  final String? organizerId;
  final String description;
  final String? tournamentCode;
  final double? entryFee;
  final String? winningPrize;
  final CricketBallType? ballType;
  final PitchType? pitchType;
  final TournamentRulesModel defaultRules;
  final TournamentSetupMeta setupMeta;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? championTeamId;
  final String? championTeamName;
  final String? runnerUpTeamId;
  final String? runnerUpTeamName;
  final String? thirdPlaceTeamId;
  final String? thirdPlaceTeamName;
  /// Preferred ordered podium (1–5). Falls back to legacy champion fields when empty.
  final List<TournamentPodiumPlace> podiumPlaces;
  final bool isLocked;
  final Map<String, String> awards;

  String get effectiveOrganizerId => organizerId ?? createdBy ?? '';

  String get city => location.city;

  /// Podium for UI: [podiumPlaces] or synthesized from legacy champion fields.
  List<TournamentPodiumPlace> get effectivePodiumPlaces {
    if (podiumPlaces.isNotEmpty) {
      final sorted = [...podiumPlaces]..sort((a, b) => a.place.compareTo(b.place));
      return sorted;
    }
    final legacy = <TournamentPodiumPlace>[];
    if (championTeamId != null && championTeamId!.isNotEmpty) {
      legacy.add(
        TournamentPodiumPlace(
          place: 1,
          teamId: championTeamId!,
          teamName: championTeamName ?? '',
        ),
      );
    }
    if (runnerUpTeamId != null && runnerUpTeamId!.isNotEmpty) {
      legacy.add(
        TournamentPodiumPlace(
          place: 2,
          teamId: runnerUpTeamId!,
          teamName: runnerUpTeamName ?? '',
        ),
      );
    }
    if (thirdPlaceTeamId != null && thirdPlaceTeamId!.isNotEmpty) {
      legacy.add(
        TournamentPodiumPlace(
          place: 3,
          teamId: thirdPlaceTeamId!,
          teamName: thirdPlaceTeamName ?? '',
        ),
      );
    }
    return legacy;
  }

  factory TournamentModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentModel(
      id: id,
      name: map['name'] as String? ?? '',
      format: TournamentFormat.values.firstWhere(
        (e) => e.name == map['format'],
        orElse: () => TournamentFormat.league,
      ),
      status: TournamentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TournamentStatus.draft,
      ),
      teamIds: List<String>.from(map['teamIds'] as List? ?? []),
      matchIds: List<String>.from(map['matchIds'] as List? ?? []),
      pointsTable: (map['pointsTable'] as List? ?? [])
          .map((e) => PointsTableEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      bracketRounds: bracketRoundsFromFirestore(map['bracketRounds']),
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      bannerUrl: map['bannerUrl'] as String?,
      logoUrl: map['logoUrl'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String? ?? map['bannerUrl'] as String?,
      thumbnailAspect: CommunityMediaAspectX.parse(
        map['thumbnailAspect'] as String?,
      ),
      grounds: List<String>.from(map['grounds'] as List? ?? []),
      startDate: DateTime.tryParse(map['startDate']?.toString() ?? ''),
      endDate: DateTime.tryParse(map['endDate']?.toString() ?? ''),
      createdBy: map['createdBy'] as String?,
      organizerId: map['organizerId'] as String? ?? map['createdBy'] as String?,
      description: map['description'] as String? ?? '',
      tournamentCode: map['tournamentCode'] as String?,
      entryFee: (map['entryFee'] as num?)?.toDouble(),
      winningPrize: map['winningPrize'] as String?,
      ballType: map['ballType'] != null
          ? CricketBallType.values.firstWhere(
              (e) => e.name == map['ballType'],
              orElse: () => CricketBallType.tennis,
            )
          : null,
      pitchType: map['pitchType'] != null
          ? PitchType.values.firstWhere(
              (e) => e.name == map['pitchType'],
              orElse: () => PitchType.cement,
            )
          : null,
      defaultRules: TournamentRulesModel.fromMap(
        map['defaultRules'] as Map<String, dynamic>?,
      ),
      setupMeta: TournamentSetupMeta.fromMap(
        map['setupMeta'] as Map<String, dynamic>?,
      ),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
      championTeamId: map['championTeamId'] as String?,
      championTeamName: map['championTeamName'] as String?,
      runnerUpTeamId: map['runnerUpTeamId'] as String?,
      runnerUpTeamName: map['runnerUpTeamName'] as String?,
      thirdPlaceTeamId: map['thirdPlaceTeamId'] as String?,
      thirdPlaceTeamName: map['thirdPlaceTeamName'] as String?,
      podiumPlaces: _podiumPlacesFromMap(map),
      isLocked: map['isLocked'] as bool? ?? false,
      awards: Map<String, String>.from(map['awards'] as Map? ?? {}),
    );
  }

  static List<TournamentPodiumPlace> _podiumPlacesFromMap(
    Map<String, dynamic> map,
  ) {
    final raw = map['podiumPlaces'] as List?;
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => TournamentPodiumPlace.fromMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .where((p) => p.teamId.isNotEmpty && p.place > 0)
        .toList()
      ..sort((a, b) => a.place.compareTo(b.place));
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'format': format.name,
        'status': status.name,
        'teamIds': teamIds,
        'matchIds': matchIds,
        'pointsTable': pointsTable.map((e) => e.toMap()).toList(),
        'bracketRounds': bracketRoundsToFirestore(bracketRounds),
        'location': location.toMap(),
        if (bannerUrl != null) 'bannerUrl': bannerUrl,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'thumbnailAspect': thumbnailAspect.name,
        'grounds': grounds,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'createdBy': createdBy ?? effectiveOrganizerId,
        if (effectiveOrganizerId.isNotEmpty) 'organizerId': effectiveOrganizerId,
        'description': description,
        if (tournamentCode != null) 'tournamentCode': tournamentCode,
        if (entryFee != null) 'entryFee': entryFee,
        if (winningPrize != null) 'winningPrize': winningPrize,
        if (ballType != null) 'ballType': ballType!.name,
        if (pitchType != null) 'pitchType': pitchType!.name,
        'defaultRules': defaultRules.toMap(),
        'setupMeta': setupMeta.toMap(),
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        if (championTeamId != null) 'championTeamId': championTeamId,
        if (championTeamName != null) 'championTeamName': championTeamName,
        if (runnerUpTeamId != null) 'runnerUpTeamId': runnerUpTeamId,
        if (runnerUpTeamName != null) 'runnerUpTeamName': runnerUpTeamName,
        if (thirdPlaceTeamId != null) 'thirdPlaceTeamId': thirdPlaceTeamId,
        if (thirdPlaceTeamName != null) 'thirdPlaceTeamName': thirdPlaceTeamName,
        if (podiumPlaces.isNotEmpty)
          'podiumPlaces': podiumPlaces.map((e) => e.toMap()).toList(),
        'isLocked': isLocked,
        if (awards.isNotEmpty) 'awards': awards,
      };

  TournamentModel copyWith({
    String? name,
    TournamentFormat? format,
    TournamentStatus? status,
    List<String>? teamIds,
    List<String>? matchIds,
    List<PointsTableEntry>? pointsTable,
    List<List<BracketSlotModel>>? bracketRounds,
    LocationModel? location,
    String? bannerUrl,
    String? logoUrl,
    String? thumbnailUrl,
    CommunityMediaAspect? thumbnailAspect,
    List<String>? grounds,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    String? tournamentCode,
    double? entryFee,
    String? winningPrize,
    CricketBallType? ballType,
    PitchType? pitchType,
    TournamentRulesModel? defaultRules,
    TournamentSetupMeta? setupMeta,
    String? championTeamId,
    String? championTeamName,
    String? runnerUpTeamId,
    String? runnerUpTeamName,
    String? thirdPlaceTeamId,
    String? thirdPlaceTeamName,
    List<TournamentPodiumPlace>? podiumPlaces,
    bool? isLocked,
    Map<String, String>? awards,
  }) {
    return TournamentModel(
      id: id,
      name: name ?? this.name,
      format: format ?? this.format,
      status: status ?? this.status,
      teamIds: teamIds ?? this.teamIds,
      matchIds: matchIds ?? this.matchIds,
      pointsTable: pointsTable ?? this.pointsTable,
      bracketRounds: bracketRounds ?? this.bracketRounds,
      location: location ?? this.location,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailAspect: thumbnailAspect ?? this.thumbnailAspect,
      grounds: grounds ?? this.grounds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdBy: createdBy,
      organizerId: organizerId,
      description: description ?? this.description,
      tournamentCode: tournamentCode ?? this.tournamentCode,
      entryFee: entryFee ?? this.entryFee,
      winningPrize: winningPrize ?? this.winningPrize,
      ballType: ballType ?? this.ballType,
      pitchType: pitchType ?? this.pitchType,
      defaultRules: defaultRules ?? this.defaultRules,
      setupMeta: setupMeta ?? this.setupMeta,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      championTeamId: championTeamId ?? this.championTeamId,
      championTeamName: championTeamName ?? this.championTeamName,
      runnerUpTeamId: runnerUpTeamId ?? this.runnerUpTeamId,
      runnerUpTeamName: runnerUpTeamName ?? this.runnerUpTeamName,
      thirdPlaceTeamId: thirdPlaceTeamId ?? this.thirdPlaceTeamId,
      thirdPlaceTeamName: thirdPlaceTeamName ?? this.thirdPlaceTeamName,
      podiumPlaces: podiumPlaces ?? this.podiumPlaces,
      isLocked: isLocked ?? this.isLocked,
      awards: awards ?? this.awards,
    );
  }

  @override
  List<Object?> get props => [id, name, status, tournamentCode];
}
