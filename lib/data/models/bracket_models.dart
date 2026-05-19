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
