import 'package:equatable/equatable.dart';
import '../tournament_model.dart';

/// Per-group points table document in `tournament_points_tables`.
class TournamentPointsTableModel extends Equatable {
  const TournamentPointsTableModel({
    required this.id,
    required this.tournamentId,
    this.groupId,
    this.groupName = '',
    this.entries = const [],
    this.updatedAt,
  });

  final String id;
  final String tournamentId;
  final String? groupId;
  final String groupName;
  final List<PointsTableEntry> entries;
  final DateTime? updatedAt;

  factory TournamentPointsTableModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentPointsTableModel(
      id: id,
      tournamentId: map['tournamentId'] as String? ?? '',
      groupId: map['groupId'] as String?,
      groupName: map['groupName'] as String? ?? '',
      entries: (map['entries'] as List? ?? [])
          .map((e) => PointsTableEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        if (groupId != null) 'groupId': groupId,
        'groupName': groupName,
        'entries': entries.map((e) => e.toMap()).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, tournamentId, groupId, entries];
}
