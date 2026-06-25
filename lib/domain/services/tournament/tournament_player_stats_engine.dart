import '../../../core/constants/enums.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/ball_event_model.dart';
import '../../../data/models/match_model.dart';
import '../../scoring/ball_event_aggregator.dart';

/// Per-player tournament aggregates built from match innings + ball events.
class TournamentPlayerAccum {
  TournamentPlayerAccum({
    required this.playerId,
    this.playerName = '',
    this.teamId = '',
    this.teamName = '',
  });

  final String playerId;
  String playerName;
  String teamId;
  String teamName;
  String? photoUrl;

  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  int dismissals = 0;
  int fifties = 0;
  int hundreds = 0;
  int highScore = 0;

  int wickets = 0;
  int runsConceded = 0;
  int legalBallsBowled = 0;
  int maidens = 0;
  int bestWickets = 0;
  int bestRunsConceded = 999;

  int catches = 0;
  int runOuts = 0;
  int stumpings = 0;

  double mvpPoints = 0;
  int matchesPlayed = 0;

  double get strikeRate =>
      balls > 0 ? CricketMath.runRate(runs, balls, 1) * 100 / 6 : 0;

  double get economy => legalBallsBowled > 0
      ? CricketMath.runRate(runsConceded, legalBallsBowled, 6)
      : 0;

  double get bowlingStrikeRate => wickets > 0
      ? legalBallsBowled / wickets
      : double.infinity;
}

/// Per-team tournament aggregates.
class TournamentTeamAccum {
  TournamentTeamAccum({
    required this.teamId,
    this.teamName = '',
  });

  final String teamId;
  String teamName;
  int highestScore = 0;
  int lowestDefended = 999999;
  int biggestWinMargin = 0;
  int closestWinMargin = 999999;
  int wins = 0;
}

class TournamentPlayerStatsEngine {
  TournamentPlayerStatsEngine({BallEventAggregator? aggregator})
      : _aggregator = aggregator ?? BallEventAggregator();

  final BallEventAggregator _aggregator;

  ({
    Map<String, TournamentPlayerAccum> players,
    Map<String, TournamentTeamAccum> teams,
  }) aggregate({
    required List<MatchModel> matches,
    required Map<String, List<BallEventModel>> eventsByMatch,
    String? groupId,
    String? roundId,
    bool leagueStageOnly = false,
    bool knockoutStageOnly = false,
  }) {
    final players = <String, TournamentPlayerAccum>{};
    final teams = <String, TournamentTeamAccum>{};

    for (final match in matches) {
      if (!_includeMatch(
        match,
        groupId: groupId,
        roundId: roundId,
        leagueStageOnly: leagueStageOnly,
        knockoutStageOnly: knockoutStageOnly,
      )) continue;
      if (!_isScored(match)) continue;

      _accumulateTeamResults(match, teams);
      final events = eventsByMatch[match.id] ?? const [];

      for (final lineupInnings in match.innings) {
        final projection = events.isEmpty
            ? null
            : _aggregator.projectInnings(
                match: match,
                lineupInnings: lineupInnings,
                allEvents: events,
              );
        final inn = projection?.innings ?? lineupInnings;
        final battingTeamId = inn.battingTeamId;
        final bowlingTeamId = inn.bowlingTeamId;
        final battingName = _teamName(match, battingTeamId);
        final bowlingName = _teamName(match, bowlingTeamId);
        final maidens = projection?.bowlerMaidens ?? const {};

        for (final b in inn.batsmen) {
          if (b.playerId.isEmpty) continue;
          final p = _ensurePlayer(
            players,
            b.playerId,
            b.playerName,
            battingTeamId,
            battingName,
          );
          p.runs += b.runs;
          p.balls += b.balls;
          p.fours += b.fours;
          p.sixes += b.sixes;
          if (b.isOut) p.dismissals++;
          if (b.runs >= 100) {
            p.hundreds++;
          } else if (b.runs >= 50) {
            p.fifties++;
          }
          if (b.runs > p.highScore) p.highScore = b.runs;
        }

        for (final b in inn.bowlers) {
          if (b.playerId.isEmpty) continue;
          final p = _ensurePlayer(
            players,
            b.playerId,
            b.playerName,
            bowlingTeamId,
            bowlingName,
          );
          p.wickets += b.wickets;
          p.runsConceded += b.runsConceded;
          p.legalBallsBowled += b.oversBowledBalls;
          p.maidens += maidens[b.playerId] ?? 0;
          if (b.wickets > p.bestWickets ||
              (b.wickets == p.bestWickets &&
                  b.runsConceded < p.bestRunsConceded)) {
            p.bestWickets = b.wickets;
            p.bestRunsConceded = b.runsConceded;
          }
        }

        if (projection != null) {
          _scanFielding(projection.events, players, bowlingTeamId, bowlingName);
        }
      }

      _markMatchPlayed(players, match);
    }

    return (players: players, teams: teams);
  }

  bool _includeMatch(
    MatchModel match, {
    String? groupId,
    String? roundId,
    bool leagueStageOnly = false,
    bool knockoutStageOnly = false,
  }) {
    if (knockoutStageOnly && match.bracketRound == null) return false;
    if (leagueStageOnly && match.bracketRound != null) return false;
    if (groupId != null && groupId.isNotEmpty) {
      return match.groupId == groupId;
    }
    if (roundId != null && roundId.isNotEmpty) {
      return match.roundId == roundId;
    }
    return true;
  }

  bool _isScored(MatchModel match) {
    final status = match.status;
    return status == MatchStatus.live ||
        status == MatchStatus.inningsBreak ||
        status == MatchStatus.completed ||
        status == MatchStatus.abandoned;
  }

  void _accumulateTeamResults(
    MatchModel match,
    Map<String, TournamentTeamAccum> teams,
  ) {
    if (match.status != MatchStatus.completed) return;
    for (final inn in match.innings) {
      final t = _ensureTeam(teams, inn.battingTeamId, _teamName(match, inn.battingTeamId));
      if (inn.totalRuns > t.highestScore) t.highestScore = inn.totalRuns;
    }

    final winner = match.winnerTeamId;
    if (winner == null || winner.isEmpty) return;

    final winnerInnings = match.innings.where((i) => i.battingTeamId == winner);
    final loserId = match.teamAId == winner ? match.teamBId : match.teamAId;
    if (loserId == null) return;

    final winnerRuns = winnerInnings.fold<int>(0, (s, i) => s + i.totalRuns);
    final loserRuns = match.innings
        .where((i) => i.battingTeamId == loserId)
        .fold<int>(0, (s, i) => s + i.totalRuns);

    final margin = (winnerRuns - loserRuns).abs();
    final wt = _ensureTeam(teams, winner, _teamName(match, winner));
    wt.wins++;
    if (margin > wt.biggestWinMargin) wt.biggestWinMargin = margin;
    if (margin < wt.closestWinMargin) wt.closestWinMargin = margin;

    final defending = match.innings
        .where((i) => i.bowlingTeamId == winner && i.inningsNumber >= 2)
        .toList();
    if (defending.isNotEmpty) {
      final defended = defending.first.totalRuns - 1;
      if (defended > 0 && defended < wt.lowestDefended) {
        wt.lowestDefended = defended;
      }
    }
  }

  void _scanFielding(
    List<BallEventModel> events,
    Map<String, TournamentPlayerAccum> players,
    String bowlingTeamId,
    String bowlingTeamName,
  ) {
    for (final e in events) {
      if (!e.isWicket) continue;
      final wt = e.wicketType;
      if (wt == WicketType.caught || wt == WicketType.caughtBehind) {
        final id = e.fielderId ?? e.primaryFielderId ?? '';
        if (id.isEmpty) continue;
        final p = _ensurePlayer(
          players,
          id,
          e.fielderName ?? e.primaryFielderName ?? '',
          bowlingTeamId,
          bowlingTeamName,
        );
        p.catches++;
      } else if (wt == WicketType.runOut) {
        for (final id in [
          e.fielderId,
          e.primaryFielderId,
          e.secondaryFielderId,
          ...e.fielderIds,
        ]) {
          if (id == null || id.isEmpty) continue;
          final p = _ensurePlayer(
            players,
            id,
            '',
            bowlingTeamId,
            bowlingTeamName,
          );
          p.runOuts++;
        }
      } else if (wt == WicketType.stumped) {
        final id = e.wicketKeeperId ?? e.currentWicketKeeperId ?? '';
        if (id.isEmpty) continue;
        final p = _ensurePlayer(
          players,
          id,
          e.wicketKeeperName ?? e.currentWicketKeeperName ?? '',
          bowlingTeamId,
          bowlingTeamName,
        );
        p.stumpings++;
      }
    }
  }

  void _markMatchPlayed(
    Map<String, TournamentPlayerAccum> players,
    MatchModel match,
  ) {
    final seen = <String>{};
    for (final inn in match.innings) {
      for (final b in inn.batsmen) {
        if (b.playerId.isEmpty || !seen.add(b.playerId)) continue;
        _ensurePlayer(
          players,
          b.playerId,
          b.playerName,
          inn.battingTeamId,
          _teamName(match, inn.battingTeamId),
        ).matchesPlayed++;
      }
      for (final b in inn.bowlers) {
        if (b.playerId.isEmpty || !seen.add(b.playerId)) continue;
        _ensurePlayer(
          players,
          b.playerId,
          b.playerName,
          inn.bowlingTeamId,
          _teamName(match, inn.bowlingTeamId),
        ).matchesPlayed++;
      }
    }
  }

  TournamentPlayerAccum _ensurePlayer(
    Map<String, TournamentPlayerAccum> map,
    String id,
    String name,
    String teamId,
    String teamName,
  ) {
    var p = map[id];
    if (p == null) {
      p = TournamentPlayerAccum(
        playerId: id,
        playerName: name,
        teamId: teamId,
        teamName: teamName,
      );
      map[id] = p;
      return p;
    }
    if (name.isNotEmpty) p.playerName = name;
    if (teamId.isNotEmpty) p.teamId = teamId;
    if (teamName.isNotEmpty) p.teamName = teamName;
    return p;
  }

  TournamentTeamAccum _ensureTeam(
    Map<String, TournamentTeamAccum> map,
    String id,
    String name,
  ) {
    var t = map[id];
    if (t == null) {
      t = TournamentTeamAccum(teamId: id, teamName: name);
      map[id] = t;
      return t;
    }
    if (name.isNotEmpty) t.teamName = name;
    return t;
  }

  String _teamName(MatchModel match, String teamId) {
    if (teamId == match.teamAId) return match.teamAName;
    if (teamId == match.teamBId) return match.teamBName;
    return '';
  }
}
