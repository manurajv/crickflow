import 'package:equatable/equatable.dart';

/// One knockout fixture slot (round 1 has real teams; later rounds may be TBD).
class BracketSlotModel extends Equatable {
  const BracketSlotModel({
    this.matchId,
    this.teamAId,
    this.teamBId,
    this.teamAName = '',
    this.teamBName = '',
    this.winnerTeamId,
    this.winnerTeamName = '',
  });

  final String? matchId;
  final String? teamAId;
  final String? teamBId;
  final String teamAName;
  final String teamBName;
  final String? winnerTeamId;
  final String winnerTeamName;

  bool get isBye =>
      teamBName.toUpperCase() == 'BYE' ||
      teamBId == null ||
      teamBId!.isEmpty;

  factory BracketSlotModel.fromMap(Map<String, dynamic> map) {
    return BracketSlotModel(
      matchId: map['matchId'] as String?,
      teamAId: map['teamAId'] as String?,
      teamBId: map['teamBId'] as String?,
      teamAName: map['teamAName'] as String? ?? '',
      teamBName: map['teamBName'] as String? ?? '',
      winnerTeamId: map['winnerTeamId'] as String?,
      winnerTeamName: map['winnerTeamName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        if (matchId != null) 'matchId': matchId,
        if (teamAId != null) 'teamAId': teamAId,
        if (teamBId != null) 'teamBId': teamBId,
        'teamAName': teamAName,
        'teamBName': teamBName,
        if (winnerTeamId != null) 'winnerTeamId': winnerTeamId,
        'winnerTeamName': winnerTeamName,
      };

  @override
  List<Object?> get props => [matchId, teamAName, teamBName, winnerTeamId];
}

/// Firestore cannot store nested arrays. Encode rounds as a list of maps:
/// `[{roundIndex: 0, slots: [{...}, ...]}, ...]`.
List<Map<String, dynamic>> bracketRoundsToFirestore(
  List<List<BracketSlotModel>> rounds,
) {
  return rounds
      .asMap()
      .entries
      .map(
        (entry) => {
          'roundIndex': entry.key,
          'slots': entry.value.map((s) => s.toMap()).toList(),
        },
      )
      .toList();
}

List<List<BracketSlotModel>> bracketRoundsFromFirestore(dynamic raw) {
  if (raw == null) return const [];
  if (raw is! List || raw.isEmpty) return const [];

  final first = raw.first;
  if (first is Map) {
    final sorted = raw.cast<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return (
        index: map['roundIndex'] as int? ?? 0,
        slots: (map['slots'] as List? ?? [])
            .map((e) => BracketSlotModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    }).toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return sorted.map((e) => e.slots).toList();
  }

  // Legacy nested-list shape (local/tests only — not valid in Firestore).
  if (first is List) {
    return raw
        .map(
          (round) => (round as List)
              .map(
                (e) => BracketSlotModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),
        )
        .toList();
  }

  return const [];
}
