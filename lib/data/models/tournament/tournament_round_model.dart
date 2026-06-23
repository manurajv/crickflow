import 'package:equatable/equatable.dart';
import '../../../core/constants/enums.dart';

class TournamentRoundModel extends Equatable {
  const TournamentRoundModel({
    required this.id,
    required this.tournamentId,
    required this.name,
    this.roundType = RoundType.custom,
    this.groupIds = const [],
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String tournamentId;
  final String name;
  final RoundType roundType;
  final List<String> groupIds;
  final int sortOrder;
  final DateTime? createdAt;

  factory TournamentRoundModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentRoundModel(
      id: id,
      tournamentId: map['tournamentId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      roundType: RoundTypeX.fromFirestore(map['roundType'] as String?),
      groupIds: List<String>.from(map['groupIds'] as List? ?? []),
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'name': name,
        'roundType': roundType.firestoreName,
        'groupIds': groupIds,
        'sortOrder': sortOrder,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  TournamentRoundModel copyWithId(String id) {
    return TournamentRoundModel(
      id: id,
      tournamentId: tournamentId,
      name: name,
      roundType: roundType,
      groupIds: groupIds,
      sortOrder: sortOrder,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, tournamentId, name, roundType];
}
