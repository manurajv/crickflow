import '../../core/constants/enums.dart';
import '../../core/utils/cricket_math.dart';
import '../../core/utils/match_score_display.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_player_snapshot.dart';
import '../../data/models/match_revision_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../domain/scoring/ball_event_aggregator.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';
import 'match_analytics_models.dart';
import 'match_mvp_models.dart';
import 'match_phase_service.dart';
import 'match_summary_models.dart';

class _PlayerStats {
  _PlayerStats({
    required this.playerId,
    required this.name,
    required this.teamName,
    this.photoUrl,
  });

  final String playerId;
  String name;
  String teamName;
  String? photoUrl;
  int runs = 0;
  int balls = 0;
  int fours = 0;
  int sixes = 0;
  int wickets = 0;
  int runsConceded = 0;
  int ballsBowled = 0;
  int catches = 0;
  int runOuts = 0;
  int stumpings = 0;
  double battingMvp = 0;
  double bowlingMvp = 0;
  double fieldingMvp = 0;
  double totalMvp = 0;

  double get strikeRate => CricketMath.strikeRate(runs, balls);

  String get battingLine =>
      runs > 0 || balls > 0 ? '$runs($balls)' : '';

  String get bowlingLine {
    if (wickets == 0 && ballsBowled == 0) return '';
    final overs = CricketMath.formatOvers(ballsBowled, 6);
    return '$overs-$runsConceded-$wickets';
  }

  String get fieldingLine {
    final parts = <String>[];
    if (catches > 0) parts.add('$catches C');
    if (runOuts > 0) parts.add('$runOuts RO');
    if (stumpings > 0) parts.add('$stumpings St');
    return parts.join(' · ');
  }
}

/// Read-only match summary for the Summary tab.
class MatchSummaryService {
  MatchSummaryService({BallEventAggregator? aggregator})
      : _aggregator = aggregator ?? BallEventAggregator();

  final BallEventAggregator _aggregator;

  MatchSummarySnapshot build({
    required MatchModel match,
    required MatchAnalyticsSnapshot analytics,
    required MatchMvpSnapshot mvp,
    List<BallEventModel> ballEvents = const [],
    List<MatchRevisionModel> revisions = const [],
    String? viewerPlayerId,
    String? viewerName,
  }) {
    final isLive = match.status == MatchStatus.live ||
        match.status == MatchStatus.inningsBreak;
    final isCompleted = match.status == MatchStatus.completed;
    final projections = _projections(match, ballEvents);
    final players = _playerStats(match, projections, mvp);
    final result = _buildResult(match, mvp, isLive, isCompleted);
    final insight = _buildInsight(
      match,
      analytics,
      mvp,
      players,
      viewerPlayerId: viewerPlayerId,
      viewerName: viewerName,
    );
    final heroes = _buildHeroes(match, mvp, players);
    final stars = _buildStarPerformers(players, match.rules.ballsPerOver);
    final partnership = _buildPartnership(analytics, match);
    final comparison = _buildTeamComparison(match, analytics, players);
    final timeline = _buildTimeline(
      match: match,
      analytics: analytics,
      ballEvents: ballEvents,
      revisions: revisions,
    );
    final awards = _buildAwards(match, mvp, players, analytics, partnership);

    return MatchSummarySnapshot(
      hasData: match.innings.isNotEmpty || ballEvents.isNotEmpty,
      isLive: isLive,
      isCompleted: isCompleted,
      result: result,
      insight: insight,
      heroes: heroes,
      starBatters: stars.$1,
      starBowlers: stars.$2,
      starFielders: stars.$3,
      starAllRounders: stars.$4,
      bestPartnership: partnership,
      teamComparison: comparison,
      timeline: timeline,
      awards: awards,
    );
  }

  List<InningsDerivedProjection> _projections(
    MatchModel match,
    List<BallEventModel> ballEvents,
  ) {
    if (ballEvents.isEmpty) return const [];
    return match.innings
        .map(
          (inn) => _aggregator.projectInnings(
            match: match,
            lineupInnings: inn,
            allEvents: ballEvents,
          ),
        )
        .toList();
  }

  Map<String, _PlayerStats> _playerStats(
    MatchModel match,
    List<InningsDerivedProjection> projections,
    MatchMvpSnapshot mvp,
  ) {
    final map = <String, _PlayerStats>{};

    void ensure(String id, String name, String teamId) {
      if (id.isEmpty) return;
      final team = MatchScoreDisplay.teamName(match, teamId);
      final snap = _snapshotFor(match, id);
      map.putIfAbsent(
        id,
        () => _PlayerStats(
          playerId: id,
          name: name.isNotEmpty ? name : (snap?.name ?? 'Player'),
          teamName: team,
          photoUrl: snap?.photoUrl,
        ),
      );
    }

    for (final p in mvp.players) {
      ensure(p.playerId, p.playerName, p.teamId);
      final stats = map[p.playerId]!;
      stats.battingMvp = p.battingMvp;
      stats.bowlingMvp = p.bowlingMvp;
      stats.fieldingMvp = p.fieldingMvp;
      stats.totalMvp = p.totalMvp;
      if (p.photoUrl != null) stats.photoUrl = p.photoUrl;
    }

    final inningsList =
        projections.isNotEmpty ? projections.map((p) => p.innings) : match.innings;

    for (final inn in inningsList) {
      for (final b in inn.batsmen) {
        if (b.playerId.isEmpty) continue;
        ensure(b.playerId, b.playerName, inn.battingTeamId);
        final s = map[b.playerId]!;
        s.runs += b.runs;
        s.balls += b.balls;
        s.fours += b.fours;
        s.sixes += b.sixes;
      }
      for (final b in inn.bowlers) {
        if (b.playerId.isEmpty) continue;
        ensure(b.playerId, b.playerName, inn.bowlingTeamId);
        final s = map[b.playerId]!;
        s.wickets += b.wickets;
        s.runsConceded += b.runsConceded;
        s.ballsBowled += b.oversBowledBalls;
      }
      if (projections.isNotEmpty) {
        final proj = projections.firstWhere(
          (p) => p.innings.inningsNumber == inn.inningsNumber,
          orElse: () => projections.first,
        );
        for (final f in proj.fielders) {
          if (f.playerId.isEmpty) continue;
          ensure(f.playerId, f.playerName, inn.bowlingTeamId);
          final s = map[f.playerId]!;
          s.catches += f.catches;
          s.runOuts += f.runOuts;
          s.stumpings += f.stumpings;
        }
      }
    }

    return map;
  }

  MatchResultSummary _buildResult(
    MatchModel match,
    MatchMvpSnapshot mvp,
    bool isLive,
    bool isCompleted,
  ) {
    final rules = match.rules;
    final teamAScore = _scoreLine(match, match.teamAId);
    final teamBScore = _scoreLine(match, match.teamBId);
    final resultLine = isCompleted
        ? _completedResultLine(match)
        : isLive
            ? 'Match in progress'
            : null;

    return MatchResultSummary(
      teamAName: match.teamAName,
      teamBName: match.teamBName,
      teamAScore: teamAScore,
      teamBScore: teamBScore,
      resultLine: resultLine,
      formatLabel: _formatLabel(rules),
      venue: _venueLabel(match),
      dateLabel: _dateLabel(match),
      durationLabel: _durationLabel(match),
      tossLabel: ScoringDisplayUtils.tossSummaryLine(match) ?? '',
      playerOfMatchName: mvp.playerOfTheMatch?.playerName ?? '',
      statusLabel: isLive
          ? 'LIVE'
          : isCompleted
              ? 'Result'
              : match.status.name,
    );
  }

  MatchInsightSummary? _buildInsight(
    MatchModel match,
    MatchAnalyticsSnapshot analytics,
    MatchMvpSnapshot mvp,
    Map<String, _PlayerStats> players, {
    String? viewerPlayerId,
    String? viewerName,
  }) {
    if (!analytics.hasData && mvp.players.isEmpty) return null;

    final subject = _insightSubject(
      mvp: mvp,
      players: players,
      viewerPlayerId: viewerPlayerId,
      viewerName: viewerName,
    );
    if (subject == null) return null;

    final share = _teamEffortShare(
      mvp: mvp,
      playerId: subject.playerId,
      teamId: subject.teamId,
    );
    if (share <= 0) return null;

    final viewerWon = match.winnerTeamId != null &&
        match.winnerTeamId!.isNotEmpty &&
        match.winnerTeamId == subject.teamId;
    final isPersonalized =
        viewerPlayerId != null && viewerPlayerId == subject.playerId;
    final template = _insightTemplate(
      isPersonalized: isPersonalized,
      viewerWon: viewerWon,
      share: share,
      teamName: subject.teamName,
    );

    return MatchInsightSummary(
      headline: 'Performance Insights',
      playerName: subject.playerName,
      photoUrl: subject.photoUrl,
      contributionPercent: share,
      prefix: template.$1,
      middle: template.$2,
      suffix: template.$3,
      isPersonalized: isPersonalized,
    );
  }

  ({
    String playerId,
    String playerName,
    String teamId,
    String teamName,
    String? photoUrl,
  })? _insightSubject({
    required MatchMvpSnapshot mvp,
    required Map<String, _PlayerStats> players,
    String? viewerPlayerId,
    String? viewerName,
  }) {
    MvpPlayerScore? pick(String id) {
      for (final p in mvp.players) {
        if (p.playerId == id) return p;
      }
      return null;
    }

    if (viewerPlayerId != null && viewerPlayerId.isNotEmpty) {
      final mvpPlayer = pick(viewerPlayerId);
      if (mvpPlayer != null && mvpPlayer.totalMvp > 0) {
        final stats = players[viewerPlayerId];
        return (
          playerId: viewerPlayerId,
          playerName: viewerName?.isNotEmpty == true
              ? viewerName!
              : mvpPlayer.playerName,
          teamId: mvpPlayer.teamId,
          teamName: mvpPlayer.teamName,
          photoUrl: mvpPlayer.photoUrl ?? stats?.photoUrl,
        );
      }
    }

    final potm = mvp.playerOfTheMatch;
    if (potm != null) {
      final stats = players[potm.playerId];
      return (
        playerId: potm.playerId,
        playerName: potm.playerName,
        teamId: potm.teamId,
        teamName: potm.teamName,
        photoUrl: potm.photoUrl ?? stats?.photoUrl,
      );
    }

    return null;
  }

  double _teamEffortShare({
    required MatchMvpSnapshot mvp,
    required String playerId,
    required String teamId,
  }) {
    final teamTotal = mvp.players
        .where((p) => p.teamId == teamId)
        .fold<double>(0, (sum, p) => sum + p.totalMvp);
    if (teamTotal <= 0) return 0;

    final playerTotal = mvp.players
        .where((p) => p.playerId == playerId)
        .fold<double>(0, (sum, p) => sum + p.totalMvp);
    if (playerTotal <= 0) return 0;

    return (playerTotal / teamTotal) * 100;
  }

  (String, String, String) _insightTemplate({
    required bool isPersonalized,
    required bool viewerWon,
    required double share,
    required String teamName,
  }) {
    if (isPersonalized) {
      if (viewerWon) {
        if (share >= 20) {
          return (
            'Great win! ',
            ', you contributed ',
            ' of your team\'s total effort — a match-defining performance.',
          );
        }
        return (
          'Well played, ',
          ' — you contributed ',
          ' of your team\'s total effort to this win.',
        );
      }
      if (share >= 15) {
        return (
          'Tough match, ',
          ', but you contributed ',
          ' of your team\'s total effort. A strong individual performance despite the result.',
        );
      }
      return (
        'Challenging game, ',
        ', but you still contributed ',
        ' of your team\'s total effort.',
      );
    }

    if (viewerWon) {
      return (
        '',
        ' led the way with ',
        ' of $teamName\'s total team effort in this win.',
      );
    }
    return (
      '',
      ' contributed ',
      ' of $teamName\'s total team effort despite the result.',
    );
  }

  static String? _completedResultLine(MatchModel match) {
    final computed = MatchScoreDisplay.completedResultLine(match);
    if (computed != null && computed.isNotEmpty) return computed;
    if (match.resultSummary.isNotEmpty &&
        _looksLikeMatchResult(match.resultSummary)) {
      return match.resultSummary;
    }
    return match.resultSummary.isNotEmpty ? match.resultSummary : null;
  }

  static bool _looksLikeMatchResult(String value) {
    final lower = value.toLowerCase();
    return lower.contains(' won ') ||
        lower.contains('won by') ||
        lower.contains('tie') ||
        lower.contains('draw') ||
        lower.contains('abandon') ||
        lower.contains('no result');
  }

  List<SummaryHeroCard> _buildHeroes(
    MatchModel match,
    MatchMvpSnapshot mvp,
    Map<String, _PlayerStats> players,
  ) {
    final heroes = <SummaryHeroCard>[];

    SummaryHeroCard? cardFor(MvpPlayerScore? mvpPlayer, SummaryHeroKind kind, String title) {
      if (mvpPlayer == null) return null;
      final stats = players[mvpPlayer.playerId];
      return SummaryHeroCard(
        kind: kind,
        title: title,
        playerName: mvpPlayer.playerName,
        teamName: mvpPlayer.teamName,
        photoUrl: mvpPlayer.photoUrl ?? stats?.photoUrl,
        battingLine: stats?.battingLine ?? '',
        bowlingLine: stats?.bowlingLine ?? '',
        fieldingLine: stats?.fieldingLine ?? '',
        mvpScore: mvpPlayer.totalMvp,
      );
    }

    void add(MvpPlayerScore? p, SummaryHeroKind kind, String title) {
      final c = cardFor(p, kind, title);
      if (c != null) heroes.add(c);
    }

    add(mvp.playerOfTheMatch, SummaryHeroKind.playerOfMatch, 'Player Of The Match');
    add(mvp.fighterOfTheMatch, SummaryHeroKind.fighterOfMatch, 'Fighter Of The Match');

    final bestBatter = mvp.players.where((p) => p.battingMvp > 0).toList()
      ..sort((a, b) => b.battingMvp.compareTo(a.battingMvp));
    final bestBowler = mvp.players.where((p) => p.bowlingMvp > 0).toList()
      ..sort((a, b) => b.bowlingMvp.compareTo(a.bowlingMvp));
    final bestFielder = mvp.players.where((p) => p.fieldingMvp > 0).toList()
      ..sort((a, b) => b.fieldingMvp.compareTo(a.fieldingMvp));

    if (bestBatter.isNotEmpty &&
        bestBatter.first.playerId != mvp.playerOfTheMatch?.playerId) {
      add(bestBatter.first, SummaryHeroKind.bestBatter, 'Best Batter');
    } else if (bestBatter.isNotEmpty && heroes.length < 5) {
      add(bestBatter.first, SummaryHeroKind.bestBatter, 'Best Batter');
    }

    if (bestBowler.isNotEmpty) {
      add(bestBowler.first, SummaryHeroKind.bestBowler, 'Best Bowler');
    }
    if (bestFielder.isNotEmpty) {
      add(bestFielder.first, SummaryHeroKind.bestFielder, 'Best Fielder');
    }

    return heroes;
  }

  (
    List<SummaryPerformerCard>,
    List<SummaryPerformerCard>,
    List<SummaryPerformerCard>,
    List<SummaryPerformerCard>,
  ) _buildStarPerformers(
    Map<String, _PlayerStats> players,
    int ballsPerOver,
  ) {
    SummaryPerformerCard toCard(_PlayerStats p, String line, [String sub = '']) =>
        SummaryPerformerCard(
          playerId: p.playerId,
          playerName: p.name,
          teamName: p.teamName,
          photoUrl: p.photoUrl,
          statLine: line,
          subtitle: sub,
        );

    final batters = players.values.where((p) => p.runs > 0).toList()
      ..sort((a, b) => b.runs.compareTo(a.runs));
    final bowlers = players.values.where((p) => p.wickets > 0).toList()
      ..sort((a, b) => b.wickets.compareTo(a.wickets));
    final fielders = players.values
        .where((p) => p.catches + p.runOuts + p.stumpings > 0)
        .toList()
      ..sort(
        (a, b) => (b.catches + b.runOuts + b.stumpings)
            .compareTo(a.catches + a.runOuts + a.stumpings),
      );
    final allRounders = players.values
        .where((p) => p.runs >= 10 && p.wickets >= 1)
        .toList()
      ..sort((a, b) => (b.runs + b.wickets * 20).compareTo(a.runs + a.wickets * 20));

    return (
      batters
          .take(4)
          .map(
            (p) => toCard(
              p,
              '${p.runs}(${p.balls})',
              '${p.fours}×4 · ${p.sixes}×6 · SR ${p.strikeRate.toStringAsFixed(0)}',
            ),
          )
          .toList(),
      bowlers
          .take(4)
          .map(
            (p) => toCard(
              p,
              '${CricketMath.formatOvers(p.ballsBowled, ballsPerOver)}-${p.runsConceded}-${p.wickets}',
              'Economy ${CricketMath.economyRate(p.runsConceded, p.ballsBowled, ballsPerOver).toStringAsFixed(1)}',
            ),
          )
          .toList(),
      fielders
          .take(4)
          .map((p) => toCard(p, p.fieldingLine, p.teamName))
          .toList(),
      allRounders
          .take(4)
          .map(
            (p) => toCard(
              p,
              '${p.runs}(${p.balls}) · ${p.wickets} wkts',
              'All-round impact',
            ),
          )
          .toList(),
    );
  }

  SummaryPartnershipCard? _buildPartnership(
    MatchAnalyticsSnapshot analytics,
    MatchModel match,
  ) {
    PartnershipAnalytics? best;
    for (final p in analytics.partnerships) {
      if (best == null || p.runs > best.runs) best = p;
    }
    if (best == null || best.runs <= 0) return null;

    final inn = match.innings.firstWhere(
      (i) => i.inningsNumber == best!.inningsNumber,
      orElse: () => match.innings.first,
    );
    final team = MatchScoreDisplay.battingTeamName(match, inn);

    return SummaryPartnershipCard(
      runs: best.runs,
      balls: best.balls,
      batterAName: best.batterAName,
      batterBName: best.batterBName,
      batterARuns: best.batterARuns,
      batterBRuns: best.batterBRuns,
      inningsLabel: team,
    );
  }

  TeamComparisonSummary? _buildTeamComparison(
    MatchModel match,
    MatchAnalyticsSnapshot analytics,
    Map<String, _PlayerStats> players,
  ) {
    if (match.innings.isEmpty) return null;

    int runsFor(String? teamId) {
      var total = 0;
      for (final inn in match.innings) {
        if (inn.battingTeamId == teamId) total += inn.totalRuns;
      }
      return total;
    }

    int wktsFor(String? teamId) {
      var total = 0;
      for (final inn in match.innings) {
        if (inn.bowlingTeamId == teamId) total += inn.totalWickets;
      }
      return total;
    }

    int boundariesFor(String? teamId, {required bool sixes}) {
      var total = 0;
      for (final p in players.values) {
        if (p.teamName == MatchScoreDisplay.teamName(match, teamId)) {
          total += sixes ? p.sixes : p.fours;
        }
      }
      return total;
    }

    double rrFor(String? teamId) {
      var runs = 0;
      var balls = 0;
      for (final inn in match.innings) {
        if (inn.battingTeamId == teamId) {
          runs += inn.totalRuns;
          balls += inn.legalBalls;
        }
      }
      if (balls == 0) return 0;
      return CricketMath.runRate(runs, balls, match.rules.ballsPerOver);
    }

    double srFor(String? teamId) {
      var runs = 0;
      var balls = 0;
      for (final p in players.values) {
        if (p.teamName == MatchScoreDisplay.teamName(match, teamId)) {
          runs += p.runs;
          balls += p.balls;
        }
      }
      if (balls == 0) return 0;
      return CricketMath.strikeRate(runs, balls);
    }

    final teamAId = match.teamAId;
    final teamBId = match.teamBId;

    return TeamComparisonSummary(
      teamAName: match.teamAName,
      teamBName: match.teamBName,
      metrics: [
        TeamComparisonMetric(
          label: 'Runs',
          teamAValue: '${runsFor(teamAId)}',
          teamBValue: '${runsFor(teamBId)}',
          teamANumeric: runsFor(teamAId).toDouble(),
          teamBNumeric: runsFor(teamBId).toDouble(),
        ),
        TeamComparisonMetric(
          label: 'Wickets',
          teamAValue: '${wktsFor(teamAId)}',
          teamBValue: '${wktsFor(teamBId)}',
          teamANumeric: wktsFor(teamAId).toDouble(),
          teamBNumeric: wktsFor(teamBId).toDouble(),
        ),
        TeamComparisonMetric(
          label: 'Boundaries',
          teamAValue:
              '${boundariesFor(teamAId, sixes: false)}/${boundariesFor(teamAId, sixes: true)}',
          teamBValue:
              '${boundariesFor(teamBId, sixes: false)}/${boundariesFor(teamBId, sixes: true)}',
        ),
        TeamComparisonMetric(
          label: 'Dot balls',
          teamAValue: '${analytics.dotBalls.dotBallPercent.toStringAsFixed(0)}%',
          teamBValue: '${analytics.dotBalls.dotBallPercent.toStringAsFixed(0)}%',
          teamANumeric: analytics.dotBalls.dotBallPercent,
          teamBNumeric: analytics.dotBalls.dotBallPercent,
        ),
        TeamComparisonMetric(
          label: 'Extras',
          teamAValue: '${analytics.extras.total}',
          teamBValue: '${analytics.extras.total}',
          teamANumeric: analytics.extras.total.toDouble(),
          teamBNumeric: analytics.extras.total.toDouble(),
        ),
        TeamComparisonMetric(
          label: 'Strike rate',
          teamAValue: srFor(teamAId).toStringAsFixed(1),
          teamBValue: srFor(teamBId).toStringAsFixed(1),
          teamANumeric: srFor(teamAId),
          teamBNumeric: srFor(teamBId),
        ),
        TeamComparisonMetric(
          label: 'Run rate',
          teamAValue: rrFor(teamAId).toStringAsFixed(2),
          teamBValue: rrFor(teamBId).toStringAsFixed(2),
          teamANumeric: rrFor(teamAId),
          teamBNumeric: rrFor(teamBId),
        ),
        TeamComparisonMetric(
          label: 'Partnerships',
          teamAValue: '${analytics.partnerships.length}',
          teamBValue: '${analytics.partnerships.length}',
        ),
      ],
    );
  }

  List<MatchTimelineEvent> _buildTimeline({
    required MatchModel match,
    required MatchAnalyticsSnapshot analytics,
    required List<BallEventModel> ballEvents,
    required List<MatchRevisionModel> revisions,
  }) {
    final events = <MatchTimelineEvent>[];
    var order = 0;

    void add(String label, String detail, {String inningsLabel = ''}) {
      events.add(
        MatchTimelineEvent(
          label: label,
          detail: detail,
          inningsLabel: inningsLabel,
          order: order++,
        ),
      );
    }

    if (ballEvents.isNotEmpty && !match.rules.isTestMatch) {
      final phases = MatchPhaseService.forRules(match.rules);
      add('Powerplay', phases.powerplayLabel);
    }

    final sorted = [...ballEvents]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final runsByInnings = <int, int>{};
    final milestonesHit = <int, Set<int>>{};

    for (final e in sorted) {
      if (!e.isLegalDelivery) continue;
      final inn = e.inningsNumber;
      runsByInnings[inn] = (runsByInnings[inn] ?? 0) + e.runs;
      final total = runsByInnings[inn]!;
      milestonesHit.putIfAbsent(inn, () => {});
      for (final milestone in [50, 100, 150, 200, 250]) {
        if (total >= milestone && !milestonesHit[inn]!.contains(milestone)) {
          milestonesHit[inn]!.add(milestone);
          add(
            '$milestone runs',
            'Innings $inn reached $milestone',
            inningsLabel: 'Inn $inn',
          );
        }
      }
      if (e.isWicket && e.dismissedPlayerName != null) {
        add(
          'Wicket',
          e.dismissedPlayerName!,
          inningsLabel: 'Inn $inn · ${e.overNumber}.${e.ballInOver}',
        );
      }
    }

    for (final p in analytics.partnerships.where((p) => p.runs >= 50)) {
      add(
        'Partnership',
        '${p.batterAName} & ${p.batterBName} · ${p.runs} runs',
        inningsLabel: 'Inn ${p.inningsNumber}',
      );
    }

    if (match.status == MatchStatus.inningsBreak ||
        match.innings.length > 1) {
      add('Innings break', 'Second innings ready');
    }

    if (analytics.dlsInfo != null) {
      add(
        'DLS applied',
        'Target revised to ${analytics.dlsInfo!.revisedTarget ?? '—'}',
      );
    }

    for (final penalty in analytics.penalties) {
      add('Penalty runs', '${penalty.runs} — ${penalty.reason}');
    }

    if (match.status == MatchStatus.completed) {
      add(
        'Match won',
        match.resultSummary.isNotEmpty
            ? match.resultSummary
            : MatchScoreDisplay.completedResultLine(match) ?? '',
      );
    }

    return events;
  }

  List<MatchSummaryAward> _buildAwards(
    MatchModel match,
    MatchMvpSnapshot mvp,
    Map<String, _PlayerStats> players,
    MatchAnalyticsSnapshot analytics,
    SummaryPartnershipCard? partnership,
  ) {
    final awards = <MatchSummaryAward>[];
    final list = players.values.toList();

    void add(String emoji, String title, _PlayerStats? p, [String sub = '']) {
      if (p == null) return;
      awards.add(
        MatchSummaryAward(
          emoji: emoji,
          title: title,
          playerName: p.name,
          subtitle: sub,
        ),
      );
    }

    if (mvp.playerOfTheMatch != null) {
      final p = players[mvp.playerOfTheMatch!.playerId];
      add('🏆', 'Player Of The Match', p, 'MVP ${mvp.playerOfTheMatch!.totalMvp.toStringAsFixed(2)}');
    }
    if (mvp.fighterOfTheMatch != null) {
      final p = players[mvp.fighterOfTheMatch!.playerId];
      add('💪', 'Fighter Of The Match', p);
    }

    if (match.winnerTeamId != null) {
      final winnerName = MatchScoreDisplay.teamName(match, match.winnerTeamId);
      if (winnerName.isNotEmpty) {
        awards.add(
          MatchSummaryAward(
            emoji: '🔥',
            title: 'Match Winner',
            playerName: winnerName,
            subtitle: 'Team award',
          ),
        );
      }
    }

    final century = list.where((p) => p.runs >= 100).toList()
      ..sort((a, b) => b.runs.compareTo(a.runs));
    if (century.isNotEmpty) {
      add('🏏', 'Century Hero', century.first, '${century.first.runs} runs');
    }

    final sixHitter = list.where((p) => p.sixes > 0).toList()
      ..sort((a, b) => b.sixes.compareTo(a.sixes));
    if (sixHitter.isNotEmpty) {
      add('💥', 'Six Hitter', sixHitter.first, '${sixHitter.first.sixes} sixes');
    }

    final threeWkts = list.where((p) => p.wickets >= 3).toList()
      ..sort((a, b) => b.wickets.compareTo(a.wickets));
    for (final p in threeWkts.take(2)) {
      add(
        '🎯',
        p.wickets >= 5 ? '5 Wickets' : '3 Wickets',
        p,
        p.bowlingLine,
      );
    }

    final fastScorer = list.where((p) => p.balls >= 6 && p.strikeRate >= 150).toList()
      ..sort((a, b) => b.strikeRate.compareTo(a.strikeRate));
    if (fastScorer.isNotEmpty) {
      add(
        '⚡',
        'Fast Scorer',
        fastScorer.first,
        'SR ${fastScorer.first.strikeRate.toStringAsFixed(0)}',
      );
    }

    final safeHands = list.where((p) => p.catches > 0).toList()
      ..sort((a, b) => b.catches.compareTo(a.catches));
    if (safeHands.isNotEmpty) {
      add('🧤', 'Safe Hands', safeHands.first, '${safeHands.first.catches} catches');
    }

    if (partnership != null) {
      awards.add(
        MatchSummaryAward(
          emoji: '🤝',
          title: 'Best Partnership',
          playerName: '${partnership.batterAName} & ${partnership.batterBName}',
          subtitle: '${partnership.runs} runs',
        ),
      );
    }

    final runMachine = list.where((p) => p.runs > 0).toList()
      ..sort((a, b) => b.runs.compareTo(a.runs));
    if (runMachine.isNotEmpty && runMachine.first.runs < 100) {
      add('🏃', 'Run Machine', runMachine.first, '${runMachine.first.runs} runs');
    }

    final srKing = list.where((p) => p.balls >= 10).toList()
      ..sort((a, b) => b.strikeRate.compareTo(a.strikeRate));
    if (srKing.isNotEmpty && srKing.first.strikeRate >= 120) {
      add(
        '🚀',
        'Strike Rate King',
        srKing.first,
        'SR ${srKing.first.strikeRate.toStringAsFixed(0)}',
      );
    }

    return awards;
  }

  static String? _scoreLine(MatchModel match, String? teamId) {
    final inn = MatchScoreDisplay.inningsBattingTeam(match, teamId);
    if (inn == null) return null;
    final overs =
        CricketMath.formatOvers(inn.legalBalls, match.rules.ballsPerOver);
    return '${inn.totalRuns}/${inn.totalWickets} ($overs)';
  }

  static String _formatLabel(MatchRulesModel rules) {
    if (rules.isTestMatch) return 'Test Match';
    return '${rules.totalOvers} Overs · ${rules.ballsPerOver} balls/over';
  }

  static String _venueLabel(MatchModel match) {
    if (match.venue.isNotEmpty) return match.venue;
    return match.location.displayLabel;
  }

  static String _dateLabel(MatchModel match) {
    final dt = match.scheduledAt ?? match.startedAt ?? match.createdAt;
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _durationLabel(MatchModel match) {
    if (match.startedAt == null) return '';
    final end = match.completedAt ?? DateTime.now();
    final mins = end.difference(match.startedAt!).inMinutes;
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  static MatchPlayerSnapshot? _snapshotFor(MatchModel match, String playerId) {
    final setup = match.setup;
    if (setup == null) return null;
    for (final p in [
      ...setup.teamAPlayingPlayers,
      ...setup.teamASubstitutePlayers,
      ...setup.teamBPlayingPlayers,
      ...setup.teamBSubstitutePlayers,
    ]) {
      if (p.id == playerId) return p;
    }
    return null;
  }
}
