import '../../../core/constants/enums.dart';
import '../../../core/constants/player_profile_constants.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/ball_event_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/match_player_snapshot.dart';
import '../../scoring/match_lifecycle.dart';
import '../match_analytics_service.dart';
import 'tournament_analytics_models.dart';
import 'tournament_hero_ranking_engine.dart';
import 'tournament_leaderboard_engine.dart';
import 'tournament_leaderboard_models.dart';
import 'tournament_player_stats_engine.dart';

/// Builds tournament-wide analytics by composing existing match/player engines.
class TournamentAnalyticsEngine {
  TournamentAnalyticsEngine({
    TournamentPlayerStatsEngine? statsEngine,
    TournamentLeaderboardEngine? leaderboardEngine,
    TournamentHeroRankingEngine? heroEngine,
    MatchAnalyticsService? matchAnalytics,
  })  : _statsEngine = statsEngine ?? TournamentPlayerStatsEngine(),
        _leaderboardEngine = leaderboardEngine ?? TournamentLeaderboardEngine(),
        _heroEngine = heroEngine ?? TournamentHeroRankingEngine(),
        _matchAnalytics = matchAnalytics ?? MatchAnalyticsService();

  final TournamentPlayerStatsEngine _statsEngine;
  final TournamentLeaderboardEngine _leaderboardEngine;
  final TournamentHeroRankingEngine _heroEngine;
  final MatchAnalyticsService _matchAnalytics;

  TournamentAnalyticsSnapshot build({
    required List<MatchModel> allMatches,
    required Map<String, List<BallEventModel>> eventsByMatch,
    TournamentAnalyticsFilter filter = const TournamentAnalyticsFilter(),
    Map<String, MatchPlayerSnapshot> playerProfiles = const {},
  }) {
    final matches =
        allMatches.where((m) => m.tournamentId != null && filter.includesMatch(m)).toList();
    final scored = matches.where(_isScored).toList();
    if (scored.isEmpty && matches.isEmpty) {
      return TournamentAnalyticsSnapshot(filter: filter);
    }

    final groupId = filter.scope == TournamentAnalyticsScope.group
        ? filter.groupId
        : null;
    final roundId = filter.scope == TournamentAnalyticsScope.round
        ? filter.roundId
        : null;

    final agg = _statsEngine.aggregate(
      matches: matches,
      eventsByMatch: eventsByMatch,
      groupId: groupId,
      roundId: roundId,
      leagueStageOnly: filter.scope == TournamentAnalyticsScope.leagueStage,
      knockoutStageOnly: filter.scope == TournamentAnalyticsScope.knockoutStage,
    );

    final leaderboardScope = switch (filter.scope) {
      TournamentAnalyticsScope.round => TournamentStatsScope.round,
      TournamentAnalyticsScope.group => TournamentStatsScope.group,
      _ => TournamentStatsScope.tournament,
    };

    final leaderboard = _leaderboardEngine.build(
      matches: matches,
      eventsByMatch: eventsByMatch,
      scope: leaderboardScope,
      scopeLabel: filter.scopeLabel,
      groupId: groupId,
      roundId: roundId,
      leagueStageOnly: filter.scope == TournamentAnalyticsScope.leagueStage,
      knockoutStageOnly: filter.scope == TournamentAnalyticsScope.knockoutStage,
      limit: 50,
    );

    final heroes = _heroEngine.build(
      matches: matches,
      eventsByMatch: eventsByMatch,
      groupId: groupId,
      roundId: roundId,
      leagueStageOnly: filter.scope == TournamentAnalyticsScope.leagueStage,
      knockoutStageOnly: filter.scope == TournamentAnalyticsScope.knockoutStage,
    );

    final matchInsights = _buildMatchInsights(scored, eventsByMatch);
    final summary = _buildSummary(matches, scored, agg, matchInsights);
    final matchSummary = _buildMatchSummarySection(matches, matchInsights);
    final charts = _buildCharts(scored, eventsByMatch, agg, matchInsights);
    final playerDetails = _buildPlayerDetails(
      scored,
      eventsByMatch,
      agg,
      heroes,
      playerProfiles,
    );

    final sections = _buildSections(
      summary: summary,
      matchSummary: matchSummary,
      leaderboard: leaderboard,
      matchInsights: matchInsights,
      agg: agg,
      charts: charts,
      heroes: heroes,
      scoredMatchCount: scored.length,
    );

    return TournamentAnalyticsSnapshot(
      filter: filter,
      hasData: scored.isNotEmpty,
      summary: summary,
      matchSummary: matchSummary,
      sections: sections,
      leaderboards: leaderboard.byCategory,
      charts: charts,
      awards: heroes,
      playerDetails: playerDetails,
      matchCount: matches.length,
      scoredMatchCount: scored.length,
      updatedAt: DateTime.now(),
    );
  }

  bool _isScored(MatchModel match) {
    if (MatchLifecycle.isEffectivelyLive(match)) return true;
    final status = MatchLifecycle.effectiveStatus(match);
    return status == MatchStatus.completed || status == MatchStatus.abandoned;
  }

  _MatchInsights _buildMatchInsights(
    List<MatchModel> scored,
    Map<String, List<BallEventModel>> eventsByMatch,
  ) {
    var totalRuns = 0;
    var totalWickets = 0;
    var totalBalls = 0;
    var totalSixes = 0;
    var totalFours = 0;
    var totalExtras = 0;
    var totalWides = 0;
    var totalNoBalls = 0;
    var totalByes = 0;
    var totalLegByes = 0;
    var highestTeamScore = 0;
    var highestTeamScoreLabel = '—';
    var lowestTeamScore = 999999;
    var highestChase = 0;
    var highestChaseLabel = '—';
    var biggestWinRuns = 0;
    var biggestWinRunsLabel = '—';
    var biggestWinWkts = 0;
    var biggestWinWktsLabel = '—';
    var closestWin = 999999;
    var closestWinLabel = '—';
    var ties = 0;
    var superOvers = 0;
    var walkovers = 0;
    var abandoned = 0;
    var noResults = 0;
    var highestIndividual = 0;
    var highestIndividualLabel = '—';
    var bestBowlingWkts = 0;
    var bestBowlingRuns = 999;
    var bestBowlingLabel = '—';
    var longestPartnership = 0;
    var longestPartnershipLabel = '—';
    var longestPartnershipSubtitle = '—';
    final partnershipEntries = <TournamentPartnershipEntry>[];
    var mostExtrasMatch = 0;
    var mostExtrasMatchLabel = '—';
    var mostSixesMatch = 0;
    var mostSixesMatchLabel = '—';
    var biggestOverRuns = 0;
    var biggestOverLabel = '—';
    var highestPowerplay = 0;
    var highestMiddle = 0;
    var highestDeath = 0;
    var firstInningsTotals = <int>[];
    var secondInningsTotals = <int>[];
    var winningTotals = <int>[];
    var tossWonMatch = 0;
    var tossTotal = 0;
    var batFirstWins = 0;
    var batFirstMatches = 0;
    var chaseWins = 0;
    var chaseMatches = 0;
    final venueStats = <String, _VenueAccum>{};
    final bowlingTypeStats = <String, _BowlingTypeAccum>{};
    final dismissalCounts = <String, int>{};

    for (final match in scored) {
      final events = eventsByMatch[match.id] ?? const [];
      final analytics = _matchAnalytics.build(match: match, ballEvents: events);
      final summary = match.resultSummary.toLowerCase();
      if (summary.contains('walkover')) walkovers++;
      if (match.status == MatchStatus.abandoned ||
          summary.contains('no result') ||
          summary.contains('abandoned')) {
        abandoned++;
        noResults++;
      }
      if (match.innings.any((i) => i.isSuperOver)) superOvers++;
      if (MatchLifecycle.isCompleted(match) &&
          (match.winnerTeamId == null || match.winnerTeamId!.isEmpty) &&
          !summary.contains('no result')) {
        ties++;
      }

      for (final inn in match.innings) {
        totalRuns += inn.totalRuns;
        totalWickets += inn.totalWickets;
        totalBalls += inn.legalBalls;
        if (inn.totalRuns > highestTeamScore) {
          highestTeamScore = inn.totalRuns;
          highestTeamScoreLabel =
              '${_teamName(match, inn.battingTeamId)} · ${inn.totalRuns}/${inn.totalWickets}';
        }
        if (inn.totalRuns < lowestTeamScore) lowestTeamScore = inn.totalRuns;

        for (final b in inn.batsmen) {
          if (b.runs > highestIndividual) {
            highestIndividual = b.runs;
            highestIndividualLabel =
                '${b.playerName} · ${b.runs} (${match.teamAName} vs ${match.teamBName})';
          }
        }
        for (final b in inn.bowlers) {
          if (b.wickets > bestBowlingWkts ||
              (b.wickets == bestBowlingWkts &&
                  b.runsConceded < bestBowlingRuns)) {
            bestBowlingWkts = b.wickets;
            bestBowlingRuns = b.runsConceded;
            bestBowlingLabel =
                '${b.playerName} · ${b.wickets}/${b.runsConceded}';
          }
        }
      }

      if (analytics.hasData) {
        totalSixes += analytics.boundaries.sixes;
        totalFours += analytics.boundaries.fours;
        totalExtras += analytics.extras.total;
        totalWides += analytics.extras.wides;
        totalNoBalls += analytics.extras.noBalls;
        totalByes += analytics.extras.byes;
        totalLegByes += analytics.extras.legByes;

        if (analytics.extras.total > mostExtrasMatch) {
          mostExtrasMatch = analytics.extras.total;
          mostExtrasMatchLabel =
              '${match.teamAName} vs ${match.teamBName} · ${analytics.extras.total}';
        }
        final matchSixes = analytics.boundaries.sixes;
        if (matchSixes > mostSixesMatch) {
          mostSixesMatch = matchSixes;
          mostSixesMatchLabel =
              '${match.teamAName} vs ${match.teamBName} · $matchSixes';
        }

        for (final p in analytics.partnerships) {
          final inn = match.innings
              .where((i) => i.inningsNumber == p.inningsNumber)
              .firstOrNull;
          final matchLabel = '${match.teamAName} vs ${match.teamBName}';
          final teamLabel =
              inn != null ? _teamName(match, inn.battingTeamId) : '';
          partnershipEntries.add(
            TournamentPartnershipEntry(
              matchLabel: matchLabel,
              teamLabel: teamLabel,
              inningsNumber: p.inningsNumber,
              wicketNumber: p.wicketNumber,
              runs: p.runs,
              balls: p.balls,
              batterAName: p.batterAName,
              batterBName: p.batterBName,
              batterARuns: p.batterARuns,
              batterABalls: p.batterABalls,
              batterBRuns: p.batterBRuns,
              batterBBalls: p.batterBBalls,
            ),
          );
          if (p.runs > longestPartnership) {
            longestPartnership = p.runs;
            longestPartnershipLabel = '${p.batterAName} & ${p.batterBName}';
            longestPartnershipSubtitle =
                '$matchLabel · $teamLabel · ${p.batterARuns}(${p.batterABalls}) & ${p.batterBRuns}(${p.batterBBalls})';
          }
        }

        for (final phase in analytics.phases) {
          if (phase.runs > highestPowerplay &&
              phase.label.toLowerCase().contains('power')) {
            highestPowerplay = phase.runs;
          } else if (phase.runs > highestMiddle &&
              phase.label.toLowerCase().contains('middle')) {
            highestMiddle = phase.runs;
          } else if (phase.runs > highestDeath &&
              (phase.label.toLowerCase().contains('death') ||
                  phase.label.toLowerCase().contains('last'))) {
            highestDeath = phase.runs;
          }
        }

        for (final series in analytics.manhattan.innings) {
          for (final over in series.overs) {
            if (over.runs > biggestOverRuns) {
              biggestOverRuns = over.runs;
              biggestOverLabel = 'Over ${over.overNumber} · ${over.runs} runs';
            }
          }
        }
      }

      if (MatchLifecycle.isCompleted(match)) {
        final regular = match.innings.where((i) => !i.isSuperOver).toList();
        if (regular.isNotEmpty) {
          firstInningsTotals.add(regular.first.totalRuns);
        }
        if (regular.length >= 2) {
          secondInningsTotals.add(regular[1].totalRuns);
          final target = regular.first.totalRuns + 1;
          if (regular[1].totalRuns >= target &&
              match.winnerTeamId == regular[1].battingTeamId) {
            final chase = regular[1].totalRuns;
            if (chase > highestChase) {
              highestChase = chase;
              highestChaseLabel =
                  '${match.teamAName} vs ${match.teamBName} · $chase';
            }
          }
        }
        final winner = match.winnerTeamId;
        if (winner != null && winner.isNotEmpty) {
          final winnerRuns = match.innings
              .where((i) => i.battingTeamId == winner)
              .fold<int>(0, (s, i) => s + i.totalRuns);
          winningTotals.add(winnerRuns);

          final loserId =
              match.teamAId == winner ? match.teamBId : match.teamAId;
          if (loserId != null) {
            final loserRuns = match.innings
                .where((i) => i.battingTeamId == loserId)
                .fold<int>(0, (s, i) => s + i.totalRuns);
            final margin = (winnerRuns - loserRuns).abs();
            if (margin > biggestWinRuns) {
              biggestWinRuns = margin;
              biggestWinRunsLabel =
                  '${_teamName(match, winner)} · by $margin runs';
            }
            if (margin < closestWin) {
              closestWin = margin;
              closestWinLabel =
                  '${match.teamAName} vs ${match.teamBName} · $margin runs';
            }
          }

          final winnerWktsLost = match.innings
              .where((i) => i.battingTeamId == winner)
              .fold<int>(0, (s, i) => s + (10 - i.totalWickets));
          if (winnerWktsLost > biggestWinWkts) {
            biggestWinWkts = winnerWktsLost;
            biggestWinWktsLabel =
                '${_teamName(match, winner)} · by ${10 - winnerWktsLost} wkts';
          }
        }
      }

      final venue = match.venue.isNotEmpty
          ? match.venue
          : match.location.displayLabel;
      if (venue.isNotEmpty) {
        final v = venueStats.putIfAbsent(venue, () => _VenueAccum(name: venue));
        v.matches++;
        for (final inn in match.innings) {
          v.totalRuns += inn.totalRuns;
          if (inn.totalRuns > v.highest) v.highest = inn.totalRuns;
          if (inn.totalRuns < v.lowest) v.lowest = inn.totalRuns;
        }
        if (analytics.hasData) v.sixes += analytics.boundaries.sixes;
        final toss = _tossInfo(match);
        if (toss != null) {
          final batFirstTeam = toss.batFirstTeamId;
          if (match.winnerTeamId == batFirstTeam) {
            v.batFirstWins++;
          } else if (match.winnerTeamId != null) {
            v.chaseWins++;
          }
        }
      }

      final tossInfo = _tossInfo(match);
      if (tossInfo != null && MatchLifecycle.isCompleted(match)) {
        tossTotal++;
        if (match.winnerTeamId == tossInfo.tossWinnerTeamId) tossWonMatch++;

        batFirstMatches++;
        if (match.winnerTeamId == tossInfo.batFirstTeamId) batFirstWins++;

        if (match.winnerTeamId != null && match.winnerTeamId!.isNotEmpty) {
          chaseMatches++;
          if (match.winnerTeamId != tossInfo.batFirstTeamId) chaseWins++;
        }
      }

      for (final e in events) {
        if (e.isWicket && e.wicketType != null) {
          final key = e.wicketType!.name;
          dismissalCounts[key] = (dismissalCounts[key] ?? 0) + 1;
        }
        if (e.bowlerId != null && e.bowlerId!.isNotEmpty && e.countsToBowler) {
          final style = _bowlingStyleLabel(
            _bowlerStyle(match, e.bowlerId!) ?? e.bowlerName ?? '',
          );
          final bucket = bowlingTypeStats.putIfAbsent(
            style,
            () => _BowlingTypeAccum(label: style),
          );
          if (e.bowlerGetsWicket) bucket.wickets++;
          if (e.countsInOver && e.isLegalDelivery) {
            bucket.runs += e.runs;
            bucket.balls++;
          }
        }
      }
    }

    if (lowestTeamScore == 999999) lowestTeamScore = 0;
    if (closestWin == 999999) closestWin = 0;
    partnershipEntries.sort((a, b) => b.runs.compareTo(a.runs));

    return _MatchInsights(
      totalRuns: totalRuns,
      totalWickets: totalWickets,
      totalBalls: totalBalls,
      totalSixes: totalSixes,
      totalFours: totalFours,
      totalExtras: totalExtras,
      totalWides: totalWides,
      totalNoBalls: totalNoBalls,
      totalByes: totalByes,
      totalLegByes: totalLegByes,
      highestTeamScore: highestTeamScore,
      highestTeamScoreLabel: highestTeamScoreLabel,
      lowestTeamScore: lowestTeamScore,
      highestChase: highestChase,
      highestChaseLabel: highestChaseLabel,
      biggestWinRuns: biggestWinRuns,
      biggestWinRunsLabel: biggestWinRunsLabel,
      biggestWinWkts: biggestWinWkts,
      biggestWinWktsLabel: biggestWinWktsLabel,
      closestWin: closestWin,
      closestWinLabel: closestWinLabel,
      ties: ties,
      superOvers: superOvers,
      walkovers: walkovers,
      abandoned: abandoned,
      noResults: noResults,
      highestIndividual: highestIndividual,
      highestIndividualLabel: highestIndividualLabel,
      bestBowlingLabel: bestBowlingLabel,
      longestPartnership: longestPartnership,
      longestPartnershipLabel: longestPartnershipLabel,
      longestPartnershipSubtitle: longestPartnershipSubtitle,
      partnershipEntries: partnershipEntries,
      mostExtrasMatch: mostExtrasMatch,
      mostExtrasMatchLabel: mostExtrasMatchLabel,
      mostSixesMatch: mostSixesMatch,
      mostSixesMatchLabel: mostSixesMatchLabel,
      biggestOverRuns: biggestOverRuns,
      biggestOverLabel: biggestOverLabel,
      highestPowerplay: highestPowerplay,
      highestMiddle: highestMiddle,
      highestDeath: highestDeath,
      avgFirstInnings: _avg(firstInningsTotals),
      avgSecondInnings: _avg(secondInningsTotals),
      avgWinningScore: _avg(winningTotals),
      tossWonMatchPct: tossTotal > 0 ? (tossWonMatch / tossTotal) * 100 : 0,
      tossLostMatchPct: tossTotal > 0
          ? ((tossTotal - tossWonMatch) / tossTotal) * 100
          : 0,
      batFirstWinPct: batFirstMatches > 0 ? (batFirstWins / batFirstMatches) * 100 : 0,
      chaseWinPct: chaseMatches > 0 ? (chaseWins / chaseMatches) * 100 : 0,
      tossMatches: tossTotal,
      tossWinnerWins: tossWonMatch,
      batFirstMatches: batFirstMatches,
      batFirstWins: batFirstWins,
      chaseMatches: chaseMatches,
      chaseWinsCount: chaseWins,
      venueStats: venueStats.values.toList(),
      bowlingTypeStats: bowlingTypeStats.values.toList(),
      dismissalCounts: dismissalCounts,
    );
  }

  TournamentSummarySection _buildSummary(
    List<MatchModel> matches,
    List<MatchModel> scored,
    ({Map<String, TournamentPlayerAccum> players, Map<String, TournamentTeamAccum> teams}) agg,
    _MatchInsights insights,
  ) {
    var completed = 0;
    var live = 0;
    var upcoming = 0;
    var cancelled = 0;

    for (final m in matches) {
      if (MatchLifecycle.isEffectivelyLive(m)) {
        live++;
      } else if (MatchLifecycle.isCompleted(m)) {
        completed++;
      } else if (MatchLifecycle.effectiveStatus(m) == MatchStatus.abandoned) {
        cancelled++;
      } else if (MatchLifecycle.isUpcoming(m)) {
        upcoming++;
      }
    }

    final overs = CricketMath.formatOvers(insights.totalBalls, 6);
    final runRate = insights.totalBalls > 0
        ? CricketMath.runRate(insights.totalRuns, insights.totalBalls, 6)
        : 0.0;
    final battingAvg = insights.totalWickets > 0
        ? insights.totalRuns / insights.totalWickets
        : 0.0;

    final topRuns = agg.players.values.isEmpty
        ? null
        : (agg.players.values.toList()
          ..sort((a, b) => b.runs.compareTo(a.runs)))
            .first;

    return TournamentSummarySection(
      metrics: [
        StatsMetric(label: 'Matches', value: '${matches.length}'),
        StatsMetric(label: 'Completed', value: '$completed'),
        StatsMetric(label: 'Live', value: '$live'),
        StatsMetric(label: 'Upcoming', value: '$upcoming'),
        StatsMetric(label: 'Abandoned', value: '$cancelled'),
        StatsMetric(label: 'Overs bowled', value: overs),
        StatsMetric(label: 'Runs scored', value: '${insights.totalRuns}'),
        StatsMetric(label: 'Balls bowled', value: '${insights.totalBalls}'),
        StatsMetric(label: 'Boundaries', value: '${insights.totalFours + insights.totalSixes}'),
        StatsMetric(label: 'Sixes', value: '${insights.totalSixes}'),
        StatsMetric(label: 'Fours', value: '${insights.totalFours}'),
        StatsMetric(label: 'Extras', value: '${insights.totalExtras}'),
        StatsMetric(label: 'Wickets fallen', value: '${insights.totalWickets}'),
        StatsMetric(
          label: 'Batting average',
          value: battingAvg.toStringAsFixed(1),
        ),
        StatsMetric(label: 'Run rate', value: runRate.toStringAsFixed(2)),
        StatsMetric(
          label: 'Highest team score',
          value: '${insights.highestTeamScore}',
        ),
        StatsMetric(
          label: 'Lowest team score',
          value: insights.lowestTeamScore > 0
              ? '${insights.lowestTeamScore}'
              : '—',
        ),
        StatsMetric(
          label: 'Highest chase',
          value: insights.highestChase > 0
              ? insights.highestChaseLabel
              : '—',
        ),
        StatsMetric(
          label: 'Biggest win',
          value: insights.biggestWinRuns > 0
              ? insights.biggestWinRunsLabel
              : '—',
        ),
        StatsMetric(
          label: 'Closest match',
          value: insights.closestWin > 0 ? insights.closestWinLabel : '—',
        ),
        StatsMetric(
          label: 'Most extras in a match',
          value: insights.mostExtrasMatchLabel,
        ),
        StatsMetric(
          label: 'Most sixes in a match',
          value: insights.mostSixesMatchLabel,
        ),
        StatsMetric(
          label: 'Longest partnership',
          value: insights.longestPartnership > 0
              ? insights.longestPartnershipLabel
              : '—',
        ),
        StatsMetric(
          label: 'Highest individual score',
          value: insights.highestIndividualLabel,
        ),
        StatsMetric(label: 'Best bowling', value: insights.bestBowlingLabel),
        StatsMetric(
          label: 'Orange Cap',
          value: topRuns != null ? '${topRuns.playerName} · ${topRuns.runs}' : '—',
        ),
        StatsMetric(
          label: 'Purple Cap',
          value: _purpleCapLabel(agg.players.values),
        ),
      ],
    );
  }

  String _purpleCapLabel(Iterable<TournamentPlayerAccum> players) {
    if (players.isEmpty) return '—';
    final sorted = players.toList()..sort((a, b) => b.wickets.compareTo(a.wickets));
    final top = sorted.first;
    return top.wickets > 0 ? '${top.playerName} · ${top.wickets}' : '—';
  }

  TournamentMatchSummarySection _buildMatchSummarySection(
    List<MatchModel> matches,
    _MatchInsights insights,
  ) {
    return TournamentMatchSummarySection(
      metrics: [
        StatsMetric(
          label: 'Highest total',
          value: '${insights.highestTeamScore}',
        ),
        StatsMetric(
          label: 'Lowest total',
          value: insights.lowestTeamScore > 0
              ? '${insights.lowestTeamScore}'
              : '—',
        ),
        StatsMetric(
          label: 'Highest chase',
          value: insights.highestChase > 0 ? '${insights.highestChase}' : '—',
        ),
        StatsMetric(
          label: 'Biggest victory (runs)',
          value: insights.biggestWinRuns > 0
              ? insights.biggestWinRunsLabel
              : '—',
        ),
        StatsMetric(
          label: 'Biggest victory (wickets)',
          value: insights.biggestWinWkts > 0
              ? insights.biggestWinWktsLabel
              : '—',
        ),
        StatsMetric(
          label: 'Closest victory',
          value: insights.closestWin > 0 ? insights.closestWinLabel : '—',
        ),
        StatsMetric(label: 'Tie matches', value: '${insights.ties}'),
        StatsMetric(label: 'Super overs', value: '${insights.superOvers}'),
        StatsMetric(label: 'Walkovers', value: '${insights.walkovers}'),
        StatsMetric(label: 'Abandoned', value: '${insights.abandoned}'),
        StatsMetric(label: 'No result', value: '${insights.noResults}'),
        StatsMetric(
          label: 'Avg 1st innings',
          value: insights.avgFirstInnings.toStringAsFixed(1),
        ),
        StatsMetric(
          label: 'Avg 2nd innings',
          value: insights.avgSecondInnings.toStringAsFixed(1),
        ),
        StatsMetric(
          label: 'Avg winning score',
          value: insights.avgWinningScore.toStringAsFixed(1),
        ),
        StatsMetric(
          label: 'Highest powerplay',
          value: insights.highestPowerplay > 0
              ? '${insights.highestPowerplay}'
              : '—',
        ),
        StatsMetric(
          label: 'Highest death overs',
          value: insights.highestDeath > 0 ? '${insights.highestDeath}' : '—',
        ),
      ],
    );
  }

  Map<TournamentStatsSectionId, TournamentSectionSnapshot> _buildSections({
    required TournamentSummarySection summary,
    required TournamentMatchSummarySection matchSummary,
    required TournamentLeaderboardSnapshot leaderboard,
    required _MatchInsights matchInsights,
    required ({Map<String, TournamentPlayerAccum> players, Map<String, TournamentTeamAccum> teams}) agg,
    required List<StatsChartSeries> charts,
    required TournamentHeroesSnapshot heroes,
    required int scoredMatchCount,
  }) {
    TournamentSectionSnapshot section(
      TournamentStatsSectionId id,
      List<StatsMetric> metrics,
      TournamentLeaderboardCategory? cat, {
      StatsChartSeries? chart,
      List<TournamentPartnershipEntry> partnershipPreview = const [],
      TournamentTossInsights? tossInsights,
    }) {
      return TournamentSectionSnapshot(
        id: id,
        metrics: metrics,
        primaryCategory: cat,
        leaderboardPreview:
            cat != null ? leaderboard.entriesFor(cat).take(5).toList() : const [],
        partnershipPreview: partnershipPreview,
        tossInsights: tossInsights,
        chartPreview: chart,
      );
    }

    var totalCatches = 0;
    var totalRunOuts = 0;
    var totalStumpings = 0;
    for (final p in agg.players.values) {
      totalCatches += p.catches;
      totalRunOuts += p.runOuts;
      totalStumpings += p.stumpings;
    }

    final fieldingMetrics = [
      StatsMetric(label: 'Total catches', value: '$totalCatches'),
      StatsMetric(label: 'Run outs', value: '$totalRunOuts'),
      StatsMetric(label: 'Stumpings', value: '$totalStumpings'),
    ];

    final teamMetrics = [
      StatsMetric(
        label: 'Highest team score',
        value: matchInsights.highestTeamScore > 0
            ? '${matchInsights.highestTeamScore}'
            : '—',
        subtitle: matchInsights.highestTeamScoreLabel != '—'
            ? matchInsights.highestTeamScoreLabel
            : null,
      ),
      StatsMetric(
        label: 'Lowest team score',
        value: matchInsights.lowestTeamScore > 0
            ? '${matchInsights.lowestTeamScore}'
            : '—',
      ),
      StatsMetric(
        label: 'Biggest win',
        value: matchInsights.biggestWinRuns > 0
            ? matchInsights.biggestWinRunsLabel
            : '—',
      ),
      StatsMetric(
        label: 'Closest win',
        value: matchInsights.closestWin > 0
            ? matchInsights.closestWinLabel
            : '—',
      ),
    ];

    final boundaryMetrics = [
      StatsMetric(label: 'Tournament sixes', value: '${matchInsights.totalSixes}'),
      StatsMetric(label: 'Tournament fours', value: '${matchInsights.totalFours}'),
      StatsMetric(
        label: 'Sixes per match',
        value: scoredMatchCount > 0
            ? (matchInsights.totalSixes / scoredMatchCount).toStringAsFixed(1)
            : '—',
      ),
      StatsMetric(
        label: 'Biggest over',
        value: matchInsights.biggestOverRuns > 0
            ? matchInsights.biggestOverLabel
            : '—',
      ),
    ];

    final partnerships = matchInsights.partnershipEntries;
    final avgPartnership = partnerships.isEmpty
        ? 0.0
        : partnerships.fold<int>(0, (s, p) => s + p.runs) / partnerships.length;
    final fiftyPlus = partnerships.where((p) => p.runs >= 50).length;
    final hundredPlus = partnerships.where((p) => p.runs >= 100).length;

    final partnershipMetrics = [
      if (matchInsights.longestPartnership > 0)
        StatsMetric(
          label: 'Highest partnership',
          value: '${matchInsights.longestPartnership}',
        ),
      StatsMetric(
        label: 'Average partnership',
        value: partnerships.isEmpty ? '—' : avgPartnership.toStringAsFixed(1),
      ),
      StatsMetric(label: '50+ stands', value: '$fiftyPlus'),
      StatsMetric(label: '100+ stands', value: '$hundredPlus'),
    ];

    final tossInsights = TournamentTossInsights(
      matchesWithToss: matchInsights.tossMatches,
      tossWinnerWins: matchInsights.tossWinnerWins,
      batFirstWins: matchInsights.batFirstWins,
      batFirstMatches: matchInsights.batFirstMatches,
      chaseWins: matchInsights.chaseWinsCount,
      chaseMatches: matchInsights.chaseMatches,
    );

    final tossMetrics = tossInsights.matchesWithToss > 0
        ? [
            StatsMetric(
              label: 'Matches with toss',
              value: '${tossInsights.matchesWithToss}',
            ),
            StatsMetric(
              label: 'Won toss · won match',
              value: '${tossInsights.tossWinnerWinPct.toStringAsFixed(0)}%',
            ),
            StatsMetric(
              label: 'Bat first · won',
              value: '${tossInsights.batFirstWinPct.toStringAsFixed(0)}%',
            ),
            StatsMetric(
              label: 'Chase · won',
              value: '${tossInsights.chaseWinPct.toStringAsFixed(0)}%',
            ),
          ]
        : const <StatsMetric>[];
    final extrasMetrics = [
      StatsMetric(label: 'Total extras', value: '${matchInsights.totalExtras}'),
      StatsMetric(label: 'Wides', value: '${matchInsights.totalWides}'),
      StatsMetric(label: 'No balls', value: '${matchInsights.totalNoBalls}'),
      StatsMetric(label: 'Byes', value: '${matchInsights.totalByes}'),
      StatsMetric(label: 'Leg byes', value: '${matchInsights.totalLegByes}'),
    ];
    final sortedVenues = matchInsights.venueStats.toList()
      ..sort((a, b) => b.matches.compareTo(a.matches));
    final venueMetrics = [
      for (final v in sortedVenues.take(5))
        StatsMetric(
          label: v.name,
          value: '${v.matches} matches · avg ${_avgInt(v.totalRuns, v.matches)}',
        ),
    ];

    final progressMetrics = [
      StatsMetric(
        label: 'Highest powerplay',
        value: matchInsights.highestPowerplay > 0
            ? '${matchInsights.highestPowerplay}'
            : '—',
      ),
      StatsMetric(
        label: 'Highest middle overs',
        value: matchInsights.highestMiddle > 0
            ? '${matchInsights.highestMiddle}'
            : '—',
      ),
      StatsMetric(
        label: 'Highest death overs',
        value: matchInsights.highestDeath > 0
            ? '${matchInsights.highestDeath}'
            : '—',
      ),
      StatsMetric(
        label: 'Best chase',
        value: matchInsights.highestChase > 0
            ? matchInsights.highestChaseLabel
            : '—',
      ),
    ];

    final bowlingTypeMetrics = [
      for (final b in matchInsights.bowlingTypeStats)
        StatsMetric(
          label: b.label,
          value: '${b.wickets} wkts · econ ${b.economy.toStringAsFixed(2)}',
        ),
    ];

    final nonEmptyCharts = charts.where((c) => c.points.isNotEmpty).toList();

    return {
      TournamentStatsSectionId.summary:
          section(TournamentStatsSectionId.summary, summary.metrics, null),
      TournamentStatsSectionId.matchSummary: section(
        TournamentStatsSectionId.matchSummary,
        matchSummary.metrics,
        null,
      ),
      TournamentStatsSectionId.batting: section(
        TournamentStatsSectionId.batting,
        const [],
        TournamentLeaderboardCategory.mostRuns,
      ),
      TournamentStatsSectionId.bowling: section(
        TournamentStatsSectionId.bowling,
        const [],
        TournamentLeaderboardCategory.mostWickets,
      ),
      TournamentStatsSectionId.fielding: section(
        TournamentStatsSectionId.fielding,
        fieldingMetrics,
        TournamentLeaderboardCategory.mostCatches,
      ),
      TournamentStatsSectionId.team: section(
        TournamentStatsSectionId.team,
        teamMetrics,
        TournamentLeaderboardCategory.highestTeamScore,
      ),
      TournamentStatsSectionId.boundaries: section(
        TournamentStatsSectionId.boundaries,
        boundaryMetrics,
        TournamentLeaderboardCategory.mostSixes,
      ),
      TournamentStatsSectionId.partnerships: section(
        TournamentStatsSectionId.partnerships,
        partnershipMetrics,
        null,
        partnershipPreview: partnerships.take(25).toList(),
      ),
      TournamentStatsSectionId.extras: section(
        TournamentStatsSectionId.extras,
        extrasMetrics,
        null,
      ),
      TournamentStatsSectionId.bowlingTypes: section(
        TournamentStatsSectionId.bowlingTypes,
        bowlingTypeMetrics,
        null,
        chart: nonEmptyCharts.where((c) => c.title.contains('Bowling type')).firstOrNull,
      ),
      TournamentStatsSectionId.toss: section(
        TournamentStatsSectionId.toss,
        tossMetrics,
        null,
        tossInsights:
            tossInsights.matchesWithToss > 0 ? tossInsights : null,
      ),
      TournamentStatsSectionId.venue: section(
        TournamentStatsSectionId.venue,
        venueMetrics,
        null,
      ),
      TournamentStatsSectionId.matchProgress: section(
        TournamentStatsSectionId.matchProgress,
        progressMetrics,
        null,
      ),
      TournamentStatsSectionId.awards: section(
        TournamentStatsSectionId.awards,
        [
          for (final h in heroes.heroes.take(8))
            StatsMetric(label: h.award.title, value: h.valueLabel),
        ],
        null,
      ),
      TournamentStatsSectionId.charts: section(
        TournamentStatsSectionId.charts,
        const [],
        null,
        chart: nonEmptyCharts.isNotEmpty ? nonEmptyCharts.first : null,
      ),
    };
  }

  List<StatsChartSeries> _buildCharts(
    List<MatchModel> scored,
    Map<String, List<BallEventModel>> eventsByMatch,
    ({Map<String, TournamentPlayerAccum> players, Map<String, TournamentTeamAccum> teams}) agg,
    _MatchInsights insights,
  ) {
    final runsPerMatch = <StatsChartPoint>[];
    for (var i = 0; i < scored.length && i < 12; i++) {
      final m = scored[i];
      final runs = m.innings.fold<int>(0, (s, inn) => s + inn.totalRuns);
      runsPerMatch.add(
        StatsChartPoint(
          label: 'M${i + 1}',
          value: runs.toDouble(),
        ),
      );
    }

    final topBatters = agg.players.values.toList()
      ..sort((a, b) => b.runs.compareTo(a.runs));
    final topBowlers = agg.players.values.toList()
      ..sort((a, b) => b.wickets.compareTo(a.wickets));

    return [
      if (runsPerMatch.isNotEmpty)
        StatsChartSeries(
          title: 'Runs per match',
          points: runsPerMatch,
          kind: StatsChartKind.bar,
        ),
      if (topBatters.any((p) => p.runs > 0))
        StatsChartSeries(
          title: 'Top batters comparison',
          points: [
            for (final p in topBatters.take(5))
              if (p.runs > 0)
                StatsChartPoint(label: _shortName(p.playerName), value: p.runs.toDouble()),
          ],
          kind: StatsChartKind.bar,
        ),
      if (topBowlers.any((p) => p.wickets > 0))
        StatsChartSeries(
          title: 'Top bowlers comparison',
          points: [
            for (final p in topBowlers.take(5))
              if (p.wickets > 0)
                StatsChartPoint(
                  label: _shortName(p.playerName),
                  value: p.wickets.toDouble(),
                ),
          ],
          kind: StatsChartKind.bar,
        ),
      if (insights.dismissalCounts.isNotEmpty)
        StatsChartSeries(
          title: 'Dismissal types',
          points: [
            for (final e in insights.dismissalCounts.entries)
              StatsChartPoint(label: e.key, value: e.value.toDouble()),
          ],
          kind: StatsChartKind.pie,
        ),
      if (insights.bowlingTypeStats.any((b) => b.wickets > 0))
        StatsChartSeries(
          title: 'Bowling type wickets',
          points: [
            for (final b in insights.bowlingTypeStats)
              if (b.wickets > 0)
                StatsChartPoint(label: b.label, value: b.wickets.toDouble()),
          ],
          kind: StatsChartKind.pie,
        ),
    ];
  }

  Map<String, TournamentPlayerStatsDetail> _buildPlayerDetails(
    List<MatchModel> scored,
    Map<String, List<BallEventModel>> eventsByMatch,
    ({Map<String, TournamentPlayerAccum> players, Map<String, TournamentTeamAccum> teams}) agg,
    TournamentHeroesSnapshot heroes,
    Map<String, MatchPlayerSnapshot> profiles,
  ) {
    final out = <String, TournamentPlayerStatsDetail>{};
    for (final p in agg.players.values) {
      if (p.playerId.isEmpty) continue;
      final logs = <TournamentPlayerMatchLog>[];
      for (final m in scored) {
        var runs = 0;
        var balls = 0;
        var wkts = 0;
        var oversBalls = 0;
        var notOut = false;
        for (final inn in m.innings) {
          for (final b in inn.batsmen) {
            if (b.playerId == p.playerId) {
              runs += b.runs;
              balls += b.balls;
              notOut = !b.isOut;
            }
          }
          for (final b in inn.bowlers) {
            if (b.playerId == p.playerId) {
              wkts += b.wickets;
              oversBalls += b.oversBowledBalls;
            }
          }
        }
        if (runs == 0 && wkts == 0 && oversBalls == 0) continue;
        logs.add(
          TournamentPlayerMatchLog(
            matchId: m.id,
            opponentLabel: '${m.teamAName} vs ${m.teamBName}',
            runs: runs,
            balls: balls,
            wickets: wkts,
            oversBowled: oversBalls,
            isNotOut: notOut,
            matchDate: m.scheduledAt ?? m.completedAt,
          ),
        );
      }

      final playerAwards = heroes.heroes
          .where((h) => h.playerId == p.playerId)
          .toList();

      out[p.playerId] = TournamentPlayerStatsDetail(
        playerId: p.playerId,
        playerName: p.playerName,
        teamName: p.teamName,
        battingMetrics: [
          StatsMetric(label: 'Runs', value: '${p.runs}'),
          StatsMetric(
            label: 'Average',
            value: p.dismissals > 0
                ? (p.runs / p.dismissals).toStringAsFixed(1)
                : p.runs.toString(),
          ),
          StatsMetric(
            label: 'Strike rate',
            value: p.strikeRate.toStringAsFixed(1),
          ),
          StatsMetric(label: 'High score', value: '${p.highScore}'),
          StatsMetric(label: 'Fours', value: '${p.fours}'),
          StatsMetric(label: 'Sixes', value: '${p.sixes}'),
        ],
        bowlingMetrics: [
          StatsMetric(label: 'Wickets', value: '${p.wickets}'),
          StatsMetric(label: 'Economy', value: p.economy.toStringAsFixed(2)),
          StatsMetric(
            label: 'Best figures',
            value: p.bestWickets > 0
                ? '${p.bestWickets}/${p.bestRunsConceded}'
                : '—',
          ),
          StatsMetric(label: 'Maidens', value: '${p.maidens}'),
        ],
        fieldingMetrics: [
          StatsMetric(label: 'Catches', value: '${p.catches}'),
          StatsMetric(label: 'Run outs', value: '${p.runOuts}'),
          StatsMetric(label: 'Stumpings', value: '${p.stumpings}'),
        ],
        matchLogs: logs,
        runsChart: [
          for (var i = 0; i < logs.length; i++)
            StatsChartPoint(label: '${i + 1}', value: logs[i].runs.toDouble()),
        ],
        wicketsChart: [
          for (var i = 0; i < logs.length; i++)
            StatsChartPoint(
              label: '${i + 1}',
              value: logs[i].wickets.toDouble(),
            ),
        ],
        awards: playerAwards,
      );
    }
    return out;
  }

  String? _bowlerStyle(MatchModel match, String bowlerId) {
    final setup = match.setup;
    if (setup == null) return null;
    for (final isA in [true, false]) {
      final snap = setup.findPlayingSnapshot(isA, bowlerId);
      if (snap != null) return snap.bowlingStyle;
    }
    return null;
  }

  _TossInfo? _tossInfo(MatchModel match) {
    final setup = match.setup;
    if (setup == null ||
        setup.tossWinnerIsTeamA == null ||
        setup.tossWinnerBatsFirst == null) {
      return null;
    }
    final tossWinnerTeamId = setup.tossWinnerIsTeamA!
        ? match.teamAId
        : match.teamBId;
    if (tossWinnerTeamId == null) return null;
    final batFirstTeamId = setup.tossWinnerBatsFirst!
        ? tossWinnerTeamId
        : _otherTeam(match, tossWinnerTeamId);
    if (batFirstTeamId == null) return null;
    return _TossInfo(
      tossWinnerTeamId: tossWinnerTeamId,
      batFirstTeamId: batFirstTeamId,
    );
  }

  String _teamName(MatchModel match, String teamId) {
    if (teamId == match.teamAId) return match.teamAName;
    if (teamId == match.teamBId) return match.teamBName;
    return teamId;
  }

  String? _otherTeam(MatchModel match, String teamId) {
    if (teamId == match.teamAId) return match.teamBId;
    if (teamId == match.teamBId) return match.teamAId;
    return null;
  }

  double _avg(List<int> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  int _avgInt(int total, int count) => count == 0 ? 0 : total ~/ count;

  String _shortName(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final only = parts.first;
      return only.length > 10 ? '${only.substring(0, 10)}…' : only;
    }
    final firstName = parts.first;
    final lastInitial = parts.last[0].toUpperCase();
    return '$firstName $lastInitial';
  }

  String _bowlingStyleLabel(String raw) {
    final parsed = PlayerBowlingStyleLabels.fromStored(raw);
    if (parsed == null) return 'Unknown';
    return switch (parsed) {
      PlayerBowlingStyle.rightArmFast ||
      PlayerBowlingStyle.leftArmFast =>
        'Fast',
      PlayerBowlingStyle.rightArmMediumFast ||
      PlayerBowlingStyle.leftArmMediumFast ||
      PlayerBowlingStyle.rightArmMedium ||
      PlayerBowlingStyle.leftArmMedium =>
        'Medium pace',
      PlayerBowlingStyle.rightArmOffSpin => 'Off spin',
      PlayerBowlingStyle.rightArmLegSpin ||
      PlayerBowlingStyle.rightArmLegBreak ||
      PlayerBowlingStyle.rightArmGoogly =>
        'Leg spin',
      PlayerBowlingStyle.leftArmOrthodoxSpin => 'Left arm orthodox',
      PlayerBowlingStyle.leftArmChinaman ||
      PlayerBowlingStyle.leftArmWristSpin =>
        'Left arm chinaman',
      PlayerBowlingStyle.doNotBowl => 'Unknown',
    };
  }
}

class _MatchInsights {
  const _MatchInsights({
    this.totalRuns = 0,
    this.totalWickets = 0,
    this.totalBalls = 0,
    this.totalSixes = 0,
    this.totalFours = 0,
    this.totalExtras = 0,
    this.totalWides = 0,
    this.totalNoBalls = 0,
    this.totalByes = 0,
    this.totalLegByes = 0,
    this.highestTeamScore = 0,
    this.highestTeamScoreLabel = '—',
    this.lowestTeamScore = 0,
    this.highestChase = 0,
    this.highestChaseLabel = '—',
    this.biggestWinRuns = 0,
    this.biggestWinRunsLabel = '—',
    this.biggestWinWkts = 0,
    this.biggestWinWktsLabel = '—',
    this.closestWin = 0,
    this.closestWinLabel = '—',
    this.ties = 0,
    this.superOvers = 0,
    this.walkovers = 0,
    this.abandoned = 0,
    this.noResults = 0,
    this.highestIndividual = 0,
    this.highestIndividualLabel = '—',
    this.bestBowlingLabel = '—',
    this.longestPartnership = 0,
    this.longestPartnershipLabel = '—',
    this.longestPartnershipSubtitle = '—',
    this.partnershipEntries = const [],
    this.mostExtrasMatch = 0,
    this.mostExtrasMatchLabel = '—',
    this.mostSixesMatch = 0,
    this.mostSixesMatchLabel = '—',
    this.biggestOverRuns = 0,
    this.biggestOverLabel = '—',
    this.highestPowerplay = 0,
    this.highestMiddle = 0,
    this.highestDeath = 0,
    this.avgFirstInnings = 0,
    this.avgSecondInnings = 0,
    this.avgWinningScore = 0,
    this.tossWonMatchPct = 0,
    this.tossLostMatchPct = 0,
    this.batFirstWinPct = 0,
    this.chaseWinPct = 0,
    this.tossMatches = 0,
    this.tossWinnerWins = 0,
    this.batFirstMatches = 0,
    this.batFirstWins = 0,
    this.chaseMatches = 0,
    this.chaseWinsCount = 0,
    this.venueStats = const [],
    this.bowlingTypeStats = const [],
    this.dismissalCounts = const {},
  });

  final int totalRuns;
  final int totalWickets;
  final int totalBalls;
  final int totalSixes;
  final int totalFours;
  final int totalExtras;
  final int totalWides;
  final int totalNoBalls;
  final int totalByes;
  final int totalLegByes;
  final int highestTeamScore;
  final String highestTeamScoreLabel;
  final int lowestTeamScore;
  final int highestChase;
  final String highestChaseLabel;
  final int biggestWinRuns;
  final String biggestWinRunsLabel;
  final int biggestWinWkts;
  final String biggestWinWktsLabel;
  final int closestWin;
  final String closestWinLabel;
  final int ties;
  final int superOvers;
  final int walkovers;
  final int abandoned;
  final int noResults;
  final int highestIndividual;
  final String highestIndividualLabel;
  final String bestBowlingLabel;
  final int longestPartnership;
  final String longestPartnershipLabel;
  final String longestPartnershipSubtitle;
  final List<TournamentPartnershipEntry> partnershipEntries;
  final int mostExtrasMatch;
  final String mostExtrasMatchLabel;
  final int mostSixesMatch;
  final String mostSixesMatchLabel;
  final int biggestOverRuns;
  final String biggestOverLabel;
  final int highestPowerplay;
  final int highestMiddle;
  final int highestDeath;
  final double avgFirstInnings;
  final double avgSecondInnings;
  final double avgWinningScore;
  final double tossWonMatchPct;
  final double tossLostMatchPct;
  final double batFirstWinPct;
  final double chaseWinPct;
  final int tossMatches;
  final int tossWinnerWins;
  final int batFirstMatches;
  final int batFirstWins;
  final int chaseMatches;
  final int chaseWinsCount;
  final List<_VenueAccum> venueStats;
  final List<_BowlingTypeAccum> bowlingTypeStats;
  final Map<String, int> dismissalCounts;
}

class _VenueAccum {
  _VenueAccum({required this.name});

  final String name;
  int matches = 0;
  int totalRuns = 0;
  int highest = 0;
  int lowest = 999999;
  int sixes = 0;
  int batFirstWins = 0;
  int chaseWins = 0;
}

class _BowlingTypeAccum {
  _BowlingTypeAccum({required this.label});

  final String label;
  int wickets = 0;
  int runs = 0;
  int balls = 0;

  double get economy =>
      balls > 0 ? CricketMath.runRate(runs, balls, 6) : 0;
}

class _TossInfo {
  const _TossInfo({
    required this.tossWinnerTeamId,
    required this.batFirstTeamId,
  });

  final String tossWinnerTeamId;
  final String batFirstTeamId;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
