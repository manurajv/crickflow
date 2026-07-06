import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/utils/cricket_math.dart';
import '../../../data/models/ball_event_model.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/match_model.dart';
import '../../../domain/scoring/ball_event_aggregator.dart';
import '../../../domain/services/dismissal_formatter.dart';
import '../../../domain/services/scorecard_display_service.dart';
import '../../../domain/wagon_wheel/wagon_wheel_analytics_service.dart';
import '../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../shared/providers/match_squads_provider.dart';
import '../data/models/innings_break_snapshot.dart';

/// Builds read-only snapshots for the innings break broadcast presentation.
class InningsBreakSnapshotBuilder {
  InningsBreakSnapshotBuilder._();

  static InningsBreakSnapshot build({
    required MatchModel match,
    required List<BallEventModel> events,
    required MatchDualSquads squads,
    String? tournamentName,
    String? tournamentLogoUrl,
    List<String> sponsorLogoUrls = const [],
  }) {
    final firstInnings = _completedFirstInnings(match);
    if (firstInnings == null) return InningsBreakSnapshot.empty;

    final projection = BallEventAggregator().projectInnings(
      match: match,
      lineupInnings: firstInnings,
      allEvents: events,
    );
    final innings = projection.innings;
    final bpo = match.rules.ballsPerOver;
    final battingTeam = _teamSide(squads, firstInnings.battingTeamId, match);
    final bowlingTeam = _teamSide(squads, firstInnings.bowlingTeamId, match);
    final photos = _photoMap(squads);

    final names = ScorecardDisplayService.playerNamesForInnings(match, innings);
    for (final b in innings.batsmen) {
      if (b.playerId.isNotEmpty) {
        names.putIfAbsent(b.playerId, () => b.playerName);
      }
    }

    final wicketEventsByBatsman = ScorecardDisplayService.wicketEventsByBatsman(
      innings: innings,
      events: projection.events,
    );

    final batters = _buildBatters(
      innings: innings,
      wicketEvents: wicketEventsByBatsman,
      playerNames: names,
    );
    final bowlers = _buildBowlers(
      innings: innings,
      maidens: projection.bowlerMaidens,
      bpo: bpo,
    );
    final extras = projection.extrasBreakdown.total;
    final extrasDetail =
        ScorecardDisplayService.extrasDetailLabel(projection.extrasBreakdown);
    final overs = CricketMath.formatOvers(innings.legalBalls, bpo);
    final runRate =
        CricketMath.runRate(innings.totalRuns, innings.legalBalls, bpo);

    var fours = 0;
    var sixes = 0;
    for (final b in innings.batsmen) {
      fours += b.fours;
      sixes += b.sixes;
    }
    final dotBalls = _dotBalls(projection.events);
    final boundaries = fours + sixes;

    final partnerships = _partnershipRows(projection.partnerships, photos);
    final partnershipTotal =
        partnerships.fold<int>(0, (sum, p) => sum + p.runs);

    final battingHighlights =
        _battingHighlights(innings, photos, projection.events, bpo, names);
    final bowlingHighlights =
        _bowlingHighlights(bowlers, photos, projection.events, bpo);

    final fallOfWickets = projection.fallOfWickets
        .map(
          (f) {
            final event = wicketEventsByBatsman[f.batsmanId];
            final columns = DismissalFormatter.broadcastColumnsForDismissal(
              event: event,
              playerNames: names,
              fallbackText: f.dismissal,
            );
            return InningsBreakFallOfWicketRow(
              wicketNumber: f.wicketNumber,
              score: f.teamScore,
              over: CricketMath.formatOvers(f.legalBalls, bpo),
              batterName: f.batsmanName.isNotEmpty ? f.batsmanName : 'Batter',
              dismissal: f.dismissal,
              fielderNames: columns.fielders,
              bowlerName: columns.bowler,
            );
          },
        )
        .toList();

    final chaseOvers = match.rules.totalOvers;
    final target = _chaseTarget(match, firstInnings);
    final ballsRemaining = chaseOvers * bpo;
    final requiredRr = CricketMath.requiredRunRate(
      runsNeeded: target,
      ballsRemaining: ballsRemaining,
      ballsPerOver: bpo,
    );

    final wagon = _wagonWheel(
      match: match,
      events: events,
      inningsNumber: firstInnings.inningsNumber,
    );

    const screens = InningsBreakScreenKind.values;

    return InningsBreakSnapshot(
      matchTitle: _matchTitle(match),
      inningsTitle: '1ST INNINGS',
      battingTeamName: battingTeam.name,
      bowlingTeamName: bowlingTeam.name,
      battingTeamLogoUrl: battingTeam.logoUrl,
      bowlingTeamLogoUrl: bowlingTeam.logoUrl,
      tournamentLogoUrl: tournamentLogoUrl,
      tournamentName: tournamentName ?? '',
      venue: match.venue.trim(),
      crickflowLogoUrl: AppConstants.crickflowLogoUrl,
      sponsorLogoUrls: sponsorLogoUrls,
      batters: batters,
      bowlers: bowlers,
      extras: extras,
      extrasDetail: extrasDetail,
      totalRuns: innings.totalRuns,
      totalWickets: innings.totalWickets,
      overs: overs,
      runRate: runRate,
      fours: fours,
      sixes: sixes,
      dotBalls: dotBalls,
      boundaries: boundaries,
      partnershipTotal: partnershipTotal,
      battingHighlights: battingHighlights,
      bowlingHighlights: bowlingHighlights,
      partnerships: partnerships,
      fallOfWickets: fallOfWickets,
      target: target,
      runsRequired: target,
      oversRemaining: chaseOvers,
      requiredRunRate: requiredRr,
      chaseOvers: chaseOvers,
      ballsPerOver: bpo,
      wagonWheelShots: wagon.shots,
      wagonWheelInsights: wagon.insights,
      hasAnalytics: wagon.hasAnalytics,
      screens: screens,
    );
  }

  static ChaseOpeningBatsmenSnapshot? buildChaseOpeningBatsmen({
    required MatchModel match,
    MatchDualSquads? squads,
  }) {
    final inn = match.currentInnings;
    if (inn == null || inn.inningsNumber < 2) return null;
    final strikerId = inn.strikerId;
    final nonStrikerId = inn.nonStrikerId;
    if (strikerId == null ||
        strikerId.isEmpty ||
        nonStrikerId == null ||
        nonStrikerId.isEmpty) {
      return null;
    }

    final first = _completedFirstInnings(match);
    if (first == null) return null;

    final battingTeam = squads != null
        ? _teamSide(squads, inn.battingTeamId, match)
        : (
            name: inn.battingTeamId == match.teamAId
                ? match.teamAName
                : match.teamBName,
            logoUrl: null as String?,
          );
    final bpo = match.rules.ballsPerOver;
    final target = inn.targetRuns ?? first.totalRuns + 1;
    final chaseOvers = match.rules.totalOvers;
    final ballsRemaining = chaseOvers * bpo;
    final requiredRr = CricketMath.requiredRunRate(
      runsNeeded: target,
      ballsRemaining: ballsRemaining,
      ballsPerOver: bpo,
    );

    var strikerName = '';
    var nonStrikerName = '';
    for (final b in inn.batsmen) {
      if (b.playerId == strikerId) strikerName = b.playerName;
      if (b.playerId == nonStrikerId) nonStrikerName = b.playerName;
    }

    return ChaseOpeningBatsmenSnapshot(
      strikerId: strikerId,
      strikerName: strikerName.isNotEmpty ? strikerName : 'Striker',
      nonStrikerId: nonStrikerId,
      nonStrikerName: nonStrikerName.isNotEmpty ? nonStrikerName : 'Non-striker',
      battingTeamName: battingTeam.name,
      battingTeamLogoUrl: battingTeam.logoUrl,
      matchTitle: _matchTitle(match),
      firstInningsScore:
          '${first.totalRuns}/${first.totalWickets}',
      target: target,
      requiredRunRate: requiredRr,
      crickflowLogoUrl: AppConstants.crickflowLogoUrl,
    );
  }

  static ChaseOpeningBowlerSnapshot? buildChaseOpeningBowler({
    required MatchModel match,
  }) {
    final inn = match.currentInnings;
    if (inn == null || inn.inningsNumber < 2) return null;
    final bowlerId = inn.currentBowlerId;
    if (bowlerId == null || bowlerId.isEmpty) return null;

    var name = '';
    BowlerInningsModel? bowlerLine;
    for (final b in inn.bowlers) {
      if (b.playerId == bowlerId) {
        name = b.playerName;
        bowlerLine = b;
        break;
      }
    }

    final bpo = match.rules.ballsPerOver;
    final economy = bowlerLine != null
        ? CricketMath.economyRate(
            bowlerLine.runsConceded,
            bowlerLine.oversBowledBalls,
            bpo,
          )
        : 0.0;
    final figures = bowlerLine != null && bowlerLine.oversBowledBalls > 0
        ? '${bowlerLine.wickets}/${bowlerLine.runsConceded}'
        : '—';

    return ChaseOpeningBowlerSnapshot(
      playerId: bowlerId,
      fallbackName: name.isNotEmpty ? name : 'Bowler',
      inningsBestFigures: figures,
      inningsEconomy: economy,
    );
  }

  static InningsModel? _completedFirstInnings(MatchModel match) {
    for (final inn in match.innings) {
      if (inn.inningsNumber == 1 &&
          !inn.isSuperOver &&
          inn.status == InningsStatus.completed) {
        return inn;
      }
    }
    return null;
  }

  static int _chaseTarget(MatchModel match, InningsModel first) {
    final pending = match.targetState.pendingChaseTarget;
    if (pending != null && pending > 0) return pending;
    return first.totalRuns + 1;
  }

  static String _matchTitle(MatchModel match) {
    if (match.teamAName.isNotEmpty && match.teamBName.isNotEmpty) {
      return '${match.teamAName} vs ${match.teamBName}';
    }
    return match.title;
  }

  static ({String name, String? logoUrl}) _teamSide(
    MatchDualSquads squads,
    String teamId,
    MatchModel match,
  ) {
    if (match.teamAId == teamId) {
      return (
        name: squads.teamA.teamName.isNotEmpty
            ? squads.teamA.teamName
            : match.teamAName,
        logoUrl: squads.teamA.teamLogoUrl,
      );
    }
    return (
      name: squads.teamB.teamName.isNotEmpty
          ? squads.teamB.teamName
          : match.teamBName,
      logoUrl: squads.teamB.teamLogoUrl,
    );
  }

  static Map<String, String?> _photoMap(MatchDualSquads squads) {
    final map = <String, String?>{};
    for (final p in [...squads.teamA.playing, ...squads.teamB.playing]) {
      map[p.id] = p.photoUrl;
    }
    return map;
  }

  static List<InningsBreakBatterRow> _buildBatters({
    required InningsModel innings,
    required Map<String, BallEventModel> wicketEvents,
    required Map<String, String> playerNames,
  }) {
    final rows = innings.batsmen
        .where((b) => b.playerId.isNotEmpty)
        .map(
          (b) {
            final dismissalText = b.isOut
                ? ScorecardDisplayService.batsmanDismissalText(
                    b,
                    onCrease: false,
                    wicketEvent: wicketEvents[b.playerId],
                    playerNames: playerNames,
                  )
                : (b.runs > 0 || b.balls > 0 ? 'not out' : '');
            final columns = b.isOut
                ? DismissalFormatter.broadcastColumnsForDismissal(
                    event: wicketEvents[b.playerId],
                    playerNames: playerNames,
                    fallbackText: dismissalText,
                  )
                : (fielders: '', bowler: '');

            return InningsBreakBatterRow(
              playerId: b.playerId,
              name: b.playerName.isNotEmpty ? b.playerName : 'Batter',
              runs: b.runs,
              balls: b.balls,
              strikeRate: CricketMath.strikeRate(b.runs, b.balls),
              dismissal: dismissalText,
              fielderNames: columns.fielders,
              bowlerName: columns.bowler,
              isOut: b.isOut,
            );
          },
        )
        .toList();
    return rows;
  }

  static List<InningsBreakBowlerRow> _buildBowlers({
    required InningsModel innings,
    required Map<String, int> maidens,
    required int bpo,
  }) {
    final rows = <InningsBreakBowlerRow>[];

    for (var i = 0; i < innings.bowlers.length; i++) {
      final b = innings.bowlers[i];
      if (b.playerId.isEmpty || b.oversBowledBalls <= 0) continue;
      final economy = CricketMath.economyRate(
        b.runsConceded,
        b.oversBowledBalls,
        bpo,
      );
      rows.add(
        InningsBreakBowlerRow(
          playerId: b.playerId,
          name: b.playerName.isNotEmpty ? b.playerName : 'Bowler',
          overs: CricketMath.formatOvers(b.oversBowledBalls, bpo),
          maidens: maidens[b.playerId] ?? 0,
          runs: b.runsConceded,
          wickets: b.wickets,
          economy: economy,
        ),
      );
    }

    rows.sort((a, b) => b.wickets.compareTo(a.wickets));
    return rows;
  }

  static int _dotBalls(List<BallEventModel> events) {
    var dots = 0;
    for (final e in events) {
      if (!e.isLegalDelivery) continue;
      if (e.totalRuns <= 0 && !e.isWicket) dots++;
    }
    return dots;
  }

  static List<InningsBreakPartnershipRow> _partnershipRows(
    List<PartnershipRecord> records,
    Map<String, String?> photos,
  ) {
    final sorted = [...records]..sort((a, b) => b.runs.compareTo(a.runs));
    return sorted
        .take(5)
        .map(
          (p) => InningsBreakPartnershipRow(
            batterAName:
                p.batterAName.isNotEmpty ? p.batterAName : 'Batter A',
            batterBName:
                p.batterBName.isNotEmpty ? p.batterBName : 'Batter B',
            runs: p.runs,
            balls: p.balls,
            batterAPhotoUrl: photos[p.batterAId],
            batterBPhotoUrl: photos[p.batterBId],
          ),
        )
        .toList();
  }

  static List<InningsBreakHighlightCard> _battingHighlights(
    InningsModel innings,
    Map<String, String?> photos,
    List<BallEventModel> events,
    int bpo,
    Map<String, String> names,
  ) {
    final cards = <InningsBreakHighlightCard>[];
    final batters =
        innings.batsmen.where((b) => b.balls > 0 || b.runs > 0).toList();
    if (batters.isEmpty) return cards;

    batters.sort((a, b) => b.runs.compareTo(a.runs));
    final top = batters.first;
    cards.add(
      InningsBreakHighlightCard(
        title: 'HIGHEST SCORER',
        playerName: top.playerName,
        playerId: top.playerId,
        photoUrl: photos[top.playerId],
        value: '${top.runs}',
        subtitle:
            '${top.balls} balls · SR ${CricketMath.strikeRate(top.runs, top.balls).toStringAsFixed(1)}',
        statRuns: top.runs,
        statBalls: top.balls,
      ),
    );

    final fifties = _fastestMilestone(events, 50, names);
    if (fifties != null) {
      cards.add(
        InningsBreakHighlightCard(
          title: 'FASTEST FIFTY',
          playerName: fifties.name,
          playerId: fifties.playerId,
          photoUrl: photos[fifties.playerId],
          value: '${fifties.balls} balls',
          statRuns: 50,
          statBalls: fifties.balls,
        ),
      );
    }

    final hundreds = _fastestMilestone(events, 100, names);
    if (hundreds != null) {
      cards.add(
        InningsBreakHighlightCard(
          title: 'FASTEST HUNDRED',
          playerName: hundreds.name,
          playerId: hundreds.playerId,
          photoUrl: photos[hundreds.playerId],
          value: '${hundreds.balls} balls',
          statRuns: 100,
          statBalls: hundreds.balls,
        ),
      );
    }

    batters.sort((a, b) => (b.fours + b.sixes).compareTo(a.fours + a.sixes));
    final boundaries = batters.first;
    cards.add(
      InningsBreakHighlightCard(
        title: 'MOST BOUNDARIES',
        playerName: boundaries.playerName,
        playerId: boundaries.playerId,
        photoUrl: photos[boundaries.playerId],
        value: '${boundaries.fours + boundaries.sixes}',
        subtitle: '${boundaries.fours}×4 · ${boundaries.sixes}×6',
      ),
    );

    batters.sort((a, b) => b.sixes.compareTo(a.sixes));
    if (batters.first.sixes > 0) {
      final sixHitter = batters.first;
      cards.add(
        InningsBreakHighlightCard(
          title: 'MOST SIXES',
          playerName: sixHitter.playerName,
          playerId: sixHitter.playerId,
          photoUrl: photos[sixHitter.playerId],
          value: '${sixHitter.sixes}',
        ),
      );
    }

    final qualified = batters.where((b) => b.balls >= 10).toList()
      ..sort(
        (a, b) => CricketMath.strikeRate(b.runs, b.balls)
            .compareTo(CricketMath.strikeRate(a.runs, a.balls)),
      );
    if (qualified.isNotEmpty) {
      final sr = qualified.first;
      cards.add(
        InningsBreakHighlightCard(
          title: 'BEST STRIKE RATE',
          playerName: sr.playerName,
          playerId: sr.playerId,
          photoUrl: photos[sr.playerId],
          value: CricketMath.strikeRate(sr.runs, sr.balls).toStringAsFixed(1),
          subtitle: '${sr.runs} (${sr.balls})',
          statRuns: sr.runs,
          statBalls: sr.balls,
        ),
      );
    }

    return cards;
  }

  static List<InningsBreakHighlightCard> _bowlingHighlights(
    List<InningsBreakBowlerRow> bowlers,
    Map<String, String?> photos,
    List<BallEventModel> events,
    int bpo,
  ) {
    if (bowlers.isEmpty) return const [];

    final cards = <InningsBreakHighlightCard>[];
    final best = bowlers.firstWhere((b) => b.isBest, orElse: () => bowlers.first);
    cards.add(
      InningsBreakHighlightCard(
        title: 'BEST BOWLING',
        playerName: best.name,
        playerId: best.playerId,
        photoUrl: photos[best.playerId],
        value: '${best.wickets}/${best.runs}',
        subtitle: '${best.overs} ov · Econ ${best.economy.toStringAsFixed(2)}',
      ),
    );

    final mostWkts = [...bowlers]
      ..sort((a, b) => b.wickets.compareTo(a.wickets));
    if (mostWkts.first.wickets > 0 && mostWkts.first.playerId != best.playerId) {
      final w = mostWkts.first;
      cards.add(
        InningsBreakHighlightCard(
          title: 'MOST WICKETS',
          playerName: w.name,
          playerId: w.playerId,
          photoUrl: photos[w.playerId],
          value: '${w.wickets}',
        ),
      );
    }

    final economy = bowlers.where((b) => b.overs != '0.0').toList()
      ..sort((a, b) => a.economy.compareTo(b.economy));
    if (economy.isNotEmpty) {
      final e = economy.first;
      cards.add(
        InningsBreakHighlightCard(
          title: 'BEST ECONOMY',
          playerName: e.name,
          playerId: e.playerId,
          photoUrl: photos[e.playerId],
          value: e.economy.toStringAsFixed(2),
          subtitle: '${e.overs} ov',
        ),
      );
    }

    final dots = _bowlerDots(events);
    if (dots.isNotEmpty) {
      dots.sort((a, b) => b.value.compareTo(a.value));
      final top = dots.first;
      cards.add(
        InningsBreakHighlightCard(
          title: 'MOST DOT BALLS',
          playerName: top.name,
          playerId: top.playerId,
          photoUrl: photos[top.playerId],
          value: '${top.value}',
        ),
      );
    }

    return cards;
  }

  static ({String playerId, String name, int balls})? _fastestMilestone(
    List<BallEventModel> events,
    int milestone,
    Map<String, String> names,
  ) {
    final runs = <String, int>{};
    final balls = <String, int>{};

    for (final e in events) {
      if (!e.isLegalDelivery) continue;
      final id = e.strikerId;
      if (id == null || id.isEmpty) continue;
      runs[id] = (runs[id] ?? 0) + e.batsmanRuns;
      balls[id] = (balls[id] ?? 0) + 1;
      if ((runs[id] ?? 0) >= milestone) {
        final name = names[id];
        return (
          playerId: id,
          name: name != null && name.isNotEmpty ? name : 'Batter',
          balls: balls[id]!,
        );
      }
    }
    return null;
  }

  static List<({String playerId, String name, int value})> _bowlerDots(
    List<BallEventModel> events,
  ) {
    final dots = <String, int>{};
    final names = <String, String>{};
    for (final e in events) {
      if (!e.isLegalDelivery || e.totalRuns > 0 || e.isWicket) continue;
      final id = e.bowlerId;
      if (id == null || id.isEmpty) continue;
      dots[id] = (dots[id] ?? 0) + 1;
      names[id] = e.bowlerName ?? names[id] ?? '';
    }
    return dots.entries
        .map(
          (e) => (
            playerId: e.key,
            name: names[e.key]!.isNotEmpty ? names[e.key]! : 'Bowler',
            value: e.value,
          ),
        )
        .toList();
  }

  static ({
    List<WagonWheelShotPoint> shots,
    WagonWheelInsights? insights,
    bool hasAnalytics,
  }) _wagonWheel({
    required MatchModel match,
    required List<BallEventModel> events,
    required int inningsNumber,
  }) {
    final service = WagonWheelAnalyticsService();
    final filter = WagonWheelFilter(
      matchId: match.id,
      inningsNumber: inningsNumber,
    );
    final shots = service.extractShots(
      events: events,
      matches: [match],
      filter: filter,
    );
    if (shots.isEmpty) {
      return (shots: const [], insights: null, hasAnalytics: false);
    }
    final insights = service.buildInsights(shots);
    return (shots: shots, insights: insights, hasAnalytics: true);
  }
}
