import 'package:equatable/equatable.dart';
import '../../../core/constants/enums.dart';

class TournamentRoundModel extends Equatable {
  const TournamentRoundModel({
    required this.id,
    required this.tournamentId,
    required this.name,
    this.description = '',
    this.roundType = RoundType.custom,
    this.groupIds = const [],
    this.sortOrder = 0,
    this.isActive = true,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tournamentId;
  final String name;
  final String description;
  final RoundType roundType;
  final List<String> groupIds;
  final int sortOrder;
  final bool isActive;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TournamentRoundModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentRoundModel(
      id: id,
      tournamentId: map['tournamentId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      roundType: RoundTypeX.fromFirestore(map['roundType'] as String?),
      groupIds: List<String>.from(map['groupIds'] as List? ?? []),
      sortOrder: map['sortOrder'] as int? ?? map['sequence'] as int? ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'name': name,
        'description': description,
        'roundType': roundType.firestoreName,
        'groupIds': groupIds,
        'sortOrder': sortOrder,
        'sequence': sortOrder,
        'isActive': isActive,
        'isArchived': isArchived,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  TournamentRoundModel copyWith({
    String? id,
    String? name,
    String? description,
    RoundType? roundType,
    List<String>? groupIds,
    int? sortOrder,
    bool? isActive,
    bool? isArchived,
  }) {
    return TournamentRoundModel(
      id: id ?? this.id,
      tournamentId: tournamentId,
      name: name ?? this.name,
      description: description ?? this.description,
      roundType: roundType ?? this.roundType,
      groupIds: groupIds ?? this.groupIds,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  TournamentRoundModel copyWithId(String id) => copyWith(id: id);

  @override
  List<Object?> get props =>
      [id, tournamentId, name, roundType, sortOrder, isActive];
}
