import '../../data/models/match_model.dart';
import '../../data/models/tournament_model.dart';

/// Client-side points table engine — mirrors Cloud Function logic in
/// `functions/src/utils/tournament.js` for previews and offline display.
class PointsTableEngineService {
  const PointsTableEngineService();

  double _oversFromBalls(int balls, int ballsPerOver) {
    if (ballsPerOver <= 0 || balls <= 0) return 0;
    final completed = balls ~/ ballsPerOver;
    final rem = balls % ballsPerOver;
    return completed + rem / ballsPerOver;
  }

  double _matchNrrDelta(MatchModel match, String teamId, int ballsPerOver) {
    final innings = match.innings;
    final batting = innings.where((i) => i.battingTeamId == teamId).firstOrNull;
    final bowling = innings.where((i) => i.bowlingTeamId == teamId).firstOrNull;
    if (batting == null || bowling == null) return 0;

    final oversFaced = _oversFromBalls(batting.legalBalls, ballsPerOver);
    final oversBowled = _oversFromBalls(bowling.legalBalls, ballsPerOver);
    final runsScored = batting.totalRuns;
    final runsConceded = bowling.totalRuns;

    final rpoScored = oversFaced > 0 ? runsScored / oversFaced : runsScored.toDouble();
    final rpoConceded =
        oversBowled > 0 ? runsConceded / oversBowled : runsConceded.toDouble();

    return rpoScored - rpoConceded;
  }

  List<PointsTableEntry> applyMatchResult({
    required List<PointsTableEntry> table,
    required MatchModel match,
    int winPts = 2,
    int tiePts = 1,
    int lossPts = 0,
    int noResultPts = 1,
  }) {
    final rows = table.map((e) => e).toList();
    final ballsPerOver = match.rules.ballsPerOver;
    final teamA = match.teamAId;
    final teamB = match.teamBId;
    if (teamA == null || teamB == null) return _rank(rows);

    final winner = match.winnerTeamId;
    final summary = match.resultSummary.toLowerCase();
    final isAbandoned = match.status.name == 'abandoned';
    final isNoResult = isAbandoned ||
        summary.contains('no result') ||
        summary.contains('abandoned');
    final isTie = !isNoResult &&
        (winner == null || winner.isEmpty || summary.contains('tie'));

    void bump(
      String teamId,
      String teamName, {
      required bool won,
      required bool lost,
      required bool tied,
      required bool noResult,
    }) {
      var row = rows.where((r) => r.teamId == teamId).firstOrNull;
      if (row == null) {
        row = PointsTableEntry(teamId: teamId, teamName: teamName);
        rows.add(row);
      }
      var played = row.played + 1;
      var wonCount = row.won;
      var lostCount = row.lost;
      var tiedCount = row.tied;
      var nrCount = row.noResult;
      var points = row.points;

      final batting = match.innings
          .where((i) => i.battingTeamId == teamId)
          .fold<int>(0, (s, i) => s + i.totalRuns);
      final bowlingAgainst = match.innings
          .where((i) => i.bowlingTeamId == teamId)
          .fold<int>(0, (s, i) => s + i.totalRuns);
      final ballsFaced = match.innings
          .where((i) => i.battingTeamId == teamId)
          .fold<int>(0, (s, i) => s + i.legalBalls);
      final ballsBowled = match.innings
          .where((i) => i.bowlingTeamId == teamId)
          .fold<int>(0, (s, i) => s + i.legalBalls);

      if (noResult) {
        nrCount += 1;
        points += noResultPts;
      } else if (tied) {
        tiedCount += 1;
        points += tiePts;
      } else if (won) {
        wonCount += 1;
        points += winPts;
      } else if (lost) {
        lostCount += 1;
        points += lossPts;
      }

      final nrr = row.netRunRate + _matchNrrDelta(match, teamId, ballsPerOver);
      final idx = rows.indexOf(row);
      rows[idx] = row.copyWith(
        teamName: teamName.isNotEmpty ? teamName : row.teamName,
        played: played,
        won: wonCount,
        lost: lostCount,
        tied: tiedCount,
        noResult: nrCount,
        points: points,
        netRunRate: double.parse(nrr.toStringAsFixed(3)),
        runsFor: row.runsFor + batting,
        runsAgainst: row.runsAgainst + bowlingAgainst,
        oversFaced: row.oversFaced + _oversFromBalls(ballsFaced, ballsPerOver),
        oversBowled: row.oversBowled + _oversFromBalls(ballsBowled, ballsPerOver),
      );
    }

    if (isNoResult) {
      bump(teamA, match.teamAName, won: false, lost: false, tied: false, noResult: true);
      bump(teamB, match.teamBName, won: false, lost: false, tied: false, noResult: true);
    } else if (isTie) {
      bump(teamA, match.teamAName, won: false, lost: false, tied: true, noResult: false);
      bump(teamB, match.teamBName, won: false, lost: false, tied: true, noResult: false);
    } else {
      bump(teamA, match.teamAName,
          won: winner == teamA, lost: winner == teamB, tied: false, noResult: false);
      bump(teamB, match.teamBName,
          won: winner == teamB, lost: winner == teamA, tied: false, noResult: false);
    }

    return _rank(rows);
  }

  List<PointsTableEntry> rebuildFromMatches({
    required List<PointsTableEntry> seed,
    required List<MatchModel> matches,
    int winPts = 2,
    int tiePts = 1,
    int lossPts = 0,
    int noResultPts = 1,
  }) {
    var table = seed
        .map((e) => PointsTableEntry(teamId: e.teamId, teamName: e.teamName))
        .toList();

    for (final match in matches) {
      if (match.status.name != 'completed' && match.status.name != 'abandoned') {
        continue;
      }
      table = applyMatchResult(
        table: table,
        match: match,
        winPts: winPts,
        tiePts: tiePts,
        lossPts: lossPts,
        noResultPts: noResultPts,
      );
    }
    return table;
  }

  List<PointsTableEntry> _rank(List<PointsTableEntry> rows) {
    final sorted = [...rows]
      ..sort((a, b) {
        if (b.points != a.points) return b.points.compareTo(a.points);
        return b.netRunRate.compareTo(a.netRunRate);
      });
    return sorted
        .asMap()
        .entries
        .map((e) => e.value.copyWith(position: e.key + 1))
        .toList();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
