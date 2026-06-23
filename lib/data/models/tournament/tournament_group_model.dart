import 'package:equatable/equatable.dart';

class TournamentGroupModel extends Equatable {
  const TournamentGroupModel({
    required this.id,
    required this.tournamentId,
    required this.name,
    this.teamIds = const [],
    this.createdAt,
  });

  final String id;
  final String tournamentId;
  final String name;
  final List<String> teamIds;
  final DateTime? createdAt;

  factory TournamentGroupModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentGroupModel(
      id: id,
      tournamentId: map['tournamentId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      teamIds: List<String>.from(map['teamIds'] as List? ?? []),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'name': name,
        'teamIds': teamIds,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  TournamentGroupModel copyWith({
    String? id,
    String? name,
    List<String>? teamIds,
  }) {
    return TournamentGroupModel(
      id: id ?? this.id,
      tournamentId: tournamentId,
      name: name ?? this.name,
      teamIds: teamIds ?? this.teamIds,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, tournamentId, name, teamIds];
}
