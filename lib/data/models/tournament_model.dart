import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import 'bracket_models.dart';
import 'location_model.dart';

class PointsTableEntry extends Equatable {
  const PointsTableEntry({
    required this.teamId,
    this.teamName = '',
    this.played = 0,
    this.won = 0,
    this.lost = 0,
    this.tied = 0,
    this.points = 0,
    this.netRunRate = 0,
  });

  final String teamId;
  final String teamName;
  final int played;
  final int won;
  final int lost;
  final int tied;
  final int points;
  final double netRunRate;

  factory PointsTableEntry.fromMap(Map<String, dynamic> map) {
    return PointsTableEntry(
      teamId: map['teamId'] as String? ?? '',
      teamName: map['teamName'] as String? ?? '',
      played: map['played'] as int? ?? 0,
      won: map['won'] as int? ?? 0,
      lost: map['lost'] as int? ?? 0,
      tied: map['tied'] as int? ?? 0,
      points: map['points'] as int? ?? 0,
      netRunRate: (map['netRunRate'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'teamId': teamId,
        'teamName': teamName,
        'played': played,
        'won': won,
        'lost': lost,
        'tied': tied,
        'points': points,
        'netRunRate': netRunRate,
      };

  @override
  List<Object?> get props => [teamId, points, netRunRate];
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
    this.startDate,
    this.endDate,
    this.createdBy,
    this.description = '',
    this.createdAt,
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
  final DateTime? startDate;
  final DateTime? endDate;
  final String? createdBy;
  final String description;
  final DateTime? createdAt;

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
      startDate: DateTime.tryParse(map['startDate']?.toString() ?? ''),
      endDate: DateTime.tryParse(map['endDate']?.toString() ?? ''),
      createdBy: map['createdBy'] as String?,
      description: map['description'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
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
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        if (createdBy != null) 'createdBy': createdBy,
        'description': description,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, status];
}
