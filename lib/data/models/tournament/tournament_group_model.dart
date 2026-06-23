import 'package:equatable/equatable.dart';

class TournamentGroupModel extends Equatable {
  const TournamentGroupModel({
    required this.id,
    required this.tournamentId,
    required this.name,
    this.description = '',
    this.teamIds = const [],
    this.qualificationCount = 2,
    this.qualificationTargetRound = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tournamentId;
  final String name;
  final String description;
  final List<String> teamIds;
  final int qualificationCount;
  final String qualificationTargetRound;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TournamentGroupModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentGroupModel(
      id: id,
      tournamentId: map['tournamentId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      teamIds: List<String>.from(map['teamIds'] as List? ?? []),
      qualificationCount: map['qualificationCount'] as int? ?? 2,
      qualificationTargetRound:
          map['qualificationTargetRound'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'name': name,
        'description': description,
        'teamIds': teamIds,
        'qualificationCount': qualificationCount,
        'qualificationTargetRound': qualificationTargetRound,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  TournamentGroupModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? teamIds,
    int? qualificationCount,
    String? qualificationTargetRound,
  }) {
    return TournamentGroupModel(
      id: id ?? this.id,
      tournamentId: tournamentId,
      name: name ?? this.name,
      description: description ?? this.description,
      teamIds: teamIds ?? this.teamIds,
      qualificationCount: qualificationCount ?? this.qualificationCount,
      qualificationTargetRound:
          qualificationTargetRound ?? this.qualificationTargetRound,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, tournamentId, name, teamIds, qualificationCount];
}
