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
    );
  }

  @override
  List<Object?> get props => [teamId, points, netRunRate, position];
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

  String get effectiveOrganizerId => organizerId ?? createdBy ?? '';

  String get city => location.city;

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
      bracketRounds: (map['bracketRounds'] as List? ?? [])
          .map(
            (round) => (round as List)
                .map((e) => BracketSlotModel.fromMap(e as Map<String, dynamic>))
                .toList(),
          )
          .toList(),
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      bannerUrl: map['bannerUrl'] as String?,
      logoUrl: map['logoUrl'] as String?,
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
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'format': format.name,
        'status': status.name,
        'teamIds': teamIds,
        'matchIds': matchIds,
        'pointsTable': pointsTable.map((e) => e.toMap()).toList(),
        'bracketRounds':
            bracketRounds.map((r) => r.map((s) => s.toMap()).toList()).toList(),
        'location': location.toMap(),
        if (bannerUrl != null) 'bannerUrl': bannerUrl,
        if (logoUrl != null) 'logoUrl': logoUrl,
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
    );
  }

  @override
  List<Object?> get props => [id, name, status, tournamentCode];
}
