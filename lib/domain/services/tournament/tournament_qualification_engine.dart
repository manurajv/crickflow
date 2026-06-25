import '../../../data/models/match_model.dart';
import '../../../data/models/tournament/tournament_group_model.dart';
import '../../../data/models/tournament/tournament_points_table_model.dart';
import '../../../data/models/tournament_model.dart';
import '../points_table_engine_service.dart';

/// Qualified team from a group based on points table standings.
class QualifiedTeam {
  const QualifiedTeam({
    required this.teamId,
    required this.teamName,
    required this.groupId,
    required this.groupName,
    required this.position,
    required this.targetRound,
  });

  final String teamId;
  final String teamName;
  final String groupId;
  final String groupName;
  final int position;
  final String targetRound;
}

/// Determines group qualifiers from synced points tables.
class TournamentQualificationEngine {
  TournamentQualificationEngine({
    PointsTableEngineService? pointsEngine,
  }) : _pointsEngine = pointsEngine ?? PointsTableEngineService();

  final PointsTableEngineService _pointsEngine;

  List<QualifiedTeam> qualifiedTeams({
    required TournamentModel tournament,
    required List<TournamentGroupModel> groups,
    required List<TournamentPointsTableModel> groupTables,
    required List<MatchModel> matches,
  }) {
    final qualified = <QualifiedTeam>[];

    for (final group in groups) {
      if (group.qualificationCount <= 0) continue;
      final table =
          groupTables.where((t) => t.groupId == group.id).firstOrNull;
      var entries = table?.entries ?? [];
      if (entries.isEmpty && group.teamIds.isNotEmpty) {
        entries =
            group.teamIds.map((id) => PointsTableEntry(teamId: id)).toList();
      }
      if (entries.isNotEmpty && matches.isNotEmpty) {
        entries = _pointsEngine.rebuildFromMatches(
          seed: entries,
          matches: matches.where((m) => m.groupId == group.id).toList(),
          winPts: tournament.defaultRules.pointsPerWin,
          tiePts: tournament.defaultRules.pointsPerTie,
          lossPts: tournament.defaultRules.pointsPerLoss,
          noResultPts: tournament.defaultRules.pointsPerNoResult,
        );
      }

      final top = entries.take(group.qualificationCount);
      for (final row in top) {
        qualified.add(
          QualifiedTeam(
            teamId: row.teamId,
            teamName: row.teamName,
            groupId: group.id,
            groupName: group.name,
            position: row.position,
            targetRound: group.qualificationTargetRound.isNotEmpty
                ? group.qualificationTargetRound
                : 'Knockout',
          ),
        );
      }
    }

    return qualified;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
