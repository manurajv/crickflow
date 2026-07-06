import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../data/models/innings_break_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../../../../../wagon_wheel/presentation/widgets/wagon_wheel_chart.dart';
import '../scorebug/scorebug_tokens.dart';
import 'innings_break_shell.dart';
import 'innings_break_side_panels.dart';

class BattingScorecardScreen extends StatelessWidget {
  const BattingScorecardScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final scale = InningsBreakShell.scaleOf(context, landscape);

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: snapshot.inningsTitle,
      teamLogoUrl: snapshot.battingTeamLogoUrl,
      teamName: snapshot.battingTeamName,
      footer: InningsBreakScorecardFooter(
        extras: snapshot.extras,
        overs: snapshot.overs,
        totalRuns: snapshot.totalRuns,
        totalWickets: snapshot.totalWickets,
        scale: scale,
        landscape: landscape,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = snapshot.batters.length;
          final rowScale = InningsBreakVisuals.compactScale(count, scale);
          final rowHeight = InningsBreakVisuals.rowHeightFor(
            maxHeight: constraints.maxHeight,
            rowCount: count,
            landscape: landscape,
            scale: rowScale,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < count; index++)
                InningsBreakBatterRowTile(
                  name: snapshot.batters[index].name,
                  fielderNames: snapshot.batters[index].fielderNames,
                  bowlerName: snapshot.batters[index].bowlerName,
                  runs: snapshot.batters[index].runs,
                  balls: snapshot.batters[index].balls,
                  isOut: snapshot.batters[index].isOut,
                  scale: rowScale,
                  landscape: landscape,
                  alternate: index.isOdd,
                  rowHeight: rowHeight,
                ),
            ],
          );
        },
      ),
    );
  }
}

class BowlingScorecardScreen extends StatelessWidget {
  const BowlingScorecardScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final scale = InningsBreakShell.scaleOf(context, landscape);

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: 'Bowling Figures',
      teamLogoUrl: snapshot.bowlingTeamLogoUrl,
      teamName: snapshot.bowlingTeamName,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = snapshot.bowlers.length;
          final rowScale = InningsBreakVisuals.compactScale(count, scale);
          final headerH = (landscape ? 30 : 26) * rowScale;
          final rowHeight = InningsBreakVisuals.rowHeightFor(
            maxHeight: constraints.maxHeight - headerH,
            rowCount: count,
            landscape: landscape,
            scale: rowScale,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InningsBreakTableHeader(
                scale: rowScale,
                landscape: landscape,
                columns: const ['Bowler', 'O', 'M', 'R', 'W', 'Econ'],
              ),
              for (var i = 0; i < count; i++)
                InningsBreakBowlerRowTile(
                  name: snapshot.bowlers[i].name,
                  overs: snapshot.bowlers[i].overs,
                  maidens: snapshot.bowlers[i].maidens,
                  runs: snapshot.bowlers[i].runs,
                  wickets: snapshot.bowlers[i].wickets,
                  economy: snapshot.bowlers[i].economy,
                  scale: rowScale,
                  landscape: landscape,
                    isBest: false,
                  alternate: i.isOdd,
                  rowHeight: rowHeight,
                ),
            ],
          );
        },
      ),
    );
  }
}

class MatchSummaryScreen extends StatelessWidget {
  const MatchSummaryScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final scale = InningsBreakShell.scaleOf(context, landscape);
    final cols = landscape ? 4 : 3;

    final stats = [
      ('Total', '${snapshot.totalRuns}/${snapshot.totalWickets}'),
      ('Overs', snapshot.overs),
      ('Run Rate', snapshot.runRate.toStringAsFixed(2)),
      ('Extras', '${snapshot.extras}'),
      ('Fours', '${snapshot.fours}'),
      ('Sixes', '${snapshot.sixes}'),
      ('Dot Balls', '${snapshot.dotBalls}'),
      ('Boundaries', '${snapshot.boundaries}'),
    ];

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: 'Innings Summary',
      teamLogoUrl: snapshot.battingTeamLogoUrl,
      teamName: snapshot.battingTeamName,
      footer: InningsBreakScorecardFooter(
        extras: snapshot.extras,
        overs: snapshot.overs,
        totalRuns: snapshot.totalRuns,
        totalWickets: snapshot.totalWickets,
        scale: scale,
        landscape: landscape,
      ),
      child: InningsBreakPanel(
        scale: scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8 * scale,
              crossAxisSpacing: 8 * scale,
              childAspectRatio: landscape ? 2.4 : 2.1,
              children: stats
                  .map(
                    (s) => _StatCell(
                      label: s.$1,
                      value: s.$2,
                      scale: scale,
                      landscape: landscape,
                    ),
                  )
                  .toList(),
            ),
            if (snapshot.extrasDetail.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              Text(
                snapshot.extrasDetail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: InningsBreakVisuals.textMuted,
                  fontSize: (landscape ? 10 : 9) * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BattingHighlightsScreen extends StatelessWidget {
  const BattingHighlightsScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final tokens = ScorebugTokens.fromTheme(theme);
    final scale = InningsBreakShell.scaleOf(context, landscape);

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: 'Batting Highlights',
      teamLogoUrl: snapshot.battingTeamLogoUrl,
      child: snapshot.battingHighlights.isEmpty
          ? InningsBreakEmptyNote(
              message: 'No batting highlights for this innings.',
              scale: scale,
              landscape: landscape,
            )
          : _HighlightList(
              cards: snapshot.battingHighlights,
              tokens: tokens,
              scale: scale,
              landscape: landscape,
            ),
    );
  }
}

class BowlingHighlightsScreen extends StatelessWidget {
  const BowlingHighlightsScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final tokens = ScorebugTokens.fromTheme(theme);
    final scale = InningsBreakShell.scaleOf(context, landscape);

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: 'Bowling Highlights',
      teamLogoUrl: snapshot.bowlingTeamLogoUrl,
      teamName: snapshot.bowlingTeamName,
      child: snapshot.bowlingHighlights.isEmpty
          ? InningsBreakEmptyNote(
              message: 'No bowling highlights for this innings.',
              scale: scale,
              landscape: landscape,
            )
          : _HighlightList(
              cards: snapshot.bowlingHighlights,
              tokens: tokens,
              scale: scale,
              landscape: landscape,
            ),
    );
  }
}

class MatchSituationScreen extends StatelessWidget {
  const MatchSituationScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final scale = InningsBreakShell.scaleOf(context, landscape);

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: 'Match Situation',
      child: InningsBreakPanel(
        scale: scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TARGET ${snapshot.target}',
              style: TextStyle(
                color: InningsBreakVisuals.highlightBlue,
                fontWeight: FontWeight.w900,
                fontSize: (landscape ? 36 : 30) * scale,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 12 * scale),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: 'Runs Required',
                    value: '${snapshot.runsRequired}',
                    scale: scale,
                    landscape: landscape,
                  ),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: _StatCell(
                    label: 'Overs',
                    value: '${snapshot.oversRemaining}',
                    scale: scale,
                    landscape: landscape,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * scale),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: 'Required RR',
                    value: snapshot.requiredRunRate.toStringAsFixed(2),
                    scale: scale,
                    landscape: landscape,
                  ),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: _StatCell(
                    label: '1st Inn RR',
                    value: snapshot.runRate.toStringAsFixed(2),
                    scale: scale,
                    landscape: landscape,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PartnershipScreen extends StatelessWidget {
  const PartnershipScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final tokens = ScorebugTokens.fromTheme(theme);
    final scale = InningsBreakShell.scaleOf(context, landscape);

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: 'Partnership Highlights',
      teamLogoUrl: snapshot.battingTeamLogoUrl,
      child: snapshot.partnerships.isEmpty
          ? InningsBreakEmptyNote(
              message: 'No partnership data recorded.',
              scale: scale,
              landscape: landscape,
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(vertical: 4 * scale),
              physics: const ClampingScrollPhysics(),
              itemCount: snapshot.partnerships.length,
              separatorBuilder: (_, i) => Divider(
                height: 1,
                color: Colors.black.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, index) {
                final p = snapshot.partnerships[index];
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14 * scale,
                    vertical: 10 * scale,
                  ),
                  child: Row(
                    children: [
                      InningsBreakHighlightAvatar(
                        name: p.batterAName,
                        photoUrl: p.batterAPhotoUrl,
                        tokens: tokens,
                        scale: scale,
                      ),
                      SizedBox(width: 6 * scale),
                      InningsBreakHighlightAvatar(
                        name: p.batterBName,
                        photoUrl: p.batterBPhotoUrl,
                        tokens: tokens,
                        scale: scale,
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p.batterAName} & ${p.batterBName}'.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: InningsBreakVisuals.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: (landscape ? 13 : 11) * scale,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InningsBreakRunsBalls(
                        runs: p.runs,
                        balls: p.balls,
                        scale: scale,
                        landscape: landscape,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class FallOfWicketsScreen extends StatelessWidget {
  const FallOfWicketsScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final scale = InningsBreakShell.scaleOf(context, landscape);

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: 'Fall of Wickets',
      teamLogoUrl: snapshot.battingTeamLogoUrl,
      child: snapshot.fallOfWickets.isEmpty
          ? InningsBreakEmptyNote(
              message: 'No wickets fell in this innings.',
              scale: scale,
              landscape: landscape,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final count = snapshot.fallOfWickets.length;
                final rowScale = InningsBreakVisuals.compactScale(count, scale);
                final headerH = (landscape ? 30 : 26) * rowScale;
                final rowHeight = InningsBreakVisuals.rowHeightFor(
                  maxHeight: constraints.maxHeight - headerH,
                  rowCount: count,
                  landscape: landscape,
                  scale: rowScale,
                );
                const flex = InningsBreakVisuals.fallOfWicketsColumnFlex;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InningsBreakTableHeader(
                      scale: rowScale,
                      landscape: landscape,
                      columns: const [
                        'Wkt',
                        'Score',
                        'Over',
                        'Batter',
                        'Fielder',
                        'Bowler',
                      ],
                      columnFlex: flex,
                      textAlign: const [
                        TextAlign.center,
                        TextAlign.center,
                        TextAlign.center,
                        TextAlign.start,
                        TextAlign.center,
                        TextAlign.center,
                      ],
                    ),
                    for (var index = 0; index < count; index++)
                      InningsBreakFallOfWicketRowTile(
                        wicketNumber:
                            snapshot.fallOfWickets[index].wicketNumber,
                        score: snapshot.fallOfWickets[index].score,
                        over: snapshot.fallOfWickets[index].over,
                        batterName: snapshot.fallOfWickets[index].batterName,
                        fielderNames:
                            snapshot.fallOfWickets[index].fielderNames,
                        bowlerName: snapshot.fallOfWickets[index].bowlerName,
                        scale: rowScale,
                        landscape: landscape,
                        alternate: index.isOdd,
                        rowHeight: rowHeight,
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final scale = InningsBreakShell.scaleOf(context, landscape);
    final size = MediaQuery.sizeOf(context);

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: 'Scoring Analytics',
      teamLogoUrl: snapshot.battingTeamLogoUrl,
      maxBodyHeight: landscape ? size.height * 0.55 : size.height * 0.5,
      child: !snapshot.hasAnalytics
          ? InningsBreakEmptyNote(
              message: 'Shot map data is not available for this innings.',
              scale: scale,
              landscape: landscape,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final chartSide = math.min(
                  constraints.maxWidth - 16 * scale,
                  constraints.maxHeight - (snapshot.wagonWheelInsights != null
                      ? 28 * scale
                      : 8 * scale),
                ).clamp(120.0, landscape ? 300.0 : 220.0);

                return InningsBreakPanel(
                  scale: scale,
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 8 * scale,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: SizedBox(
                          width: chartSide,
                          height: chartSide,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: chartSide,
                              height: chartSide,
                              child: WagonWheelChart(
                                shots: snapshot.wagonWheelShots,
                                insights: snapshot.wagonWheelInsights,
                                compact: true,
                                maxWidth: chartSide,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (snapshot.wagonWheelInsights != null) ...[
                        SizedBox(height: 6 * scale),
                        Text(
                          'Off ${snapshot.wagonWheelInsights!.offSidePercent.toStringAsFixed(0)}% · '
                          'Leg ${snapshot.wagonWheelInsights!.legSidePercent.toStringAsFixed(0)}% · '
                          'Straight ${snapshot.wagonWheelInsights!.straightPercent.toStringAsFixed(0)}%',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF555555),
                            fontSize: (landscape ? 10 : 9) * scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
    this.subtitle = 'Innings Break',
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scale = InningsBreakShell.scaleOf(context, landscape);

    return InningsBreakShell(
      snapshot: snapshot,
      theme: theme,
      landscape: landscape,
      subtitle: subtitle,
      child: InningsBreakPanel(
        scale: scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (snapshot.tournamentLogoUrl?.isNotEmpty == true)
              Padding(
                padding: EdgeInsets.only(bottom: 10 * scale),
                child: Image.network(
                  snapshot.tournamentLogoUrl!,
                  height: 44 * scale,
                  errorBuilder: (_, a, b) => const SizedBox.shrink(),
                ),
              ),
            if (snapshot.crickflowLogoUrl.isNotEmpty)
              Image.network(
                snapshot.crickflowLogoUrl,
                height: 36 * scale,
                errorBuilder: (_, a, b) => Text(
                  'CRICKFLOW',
                  style: TextStyle(
                    color: InningsBreakVisuals.highlightBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 22 * scale,
                  ),
                ),
              ),
            SizedBox(height: 12 * scale),
            Text(
              snapshot.matchTitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: InningsBreakVisuals.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: (landscape ? 14 : 12) * scale,
              ),
            ),
            if (snapshot.venue.isNotEmpty) ...[
              SizedBox(height: 4 * scale),
              Text(
                snapshot.venue.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: InningsBreakVisuals.textMuted,
                  fontSize: (landscape ? 10 : 9) * scale,
                ),
              ),
            ],
            if (snapshot.sponsorLogoUrls.isNotEmpty) ...[
              SizedBox(height: 12 * scale),
              Wrap(
                spacing: 10 * scale,
                runSpacing: 6 * scale,
                alignment: WrapAlignment.center,
                children: snapshot.sponsorLogoUrls
                    .take(4)
                    .map(
                      (url) => Image.network(
                        url,
                        height: 24 * scale,
                        errorBuilder: (_, a, b) => const SizedBox.shrink(),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HighlightList extends StatelessWidget {
  const _HighlightList({
    required this.cards,
    required this.tokens,
    required this.scale,
    required this.landscape,
  });

  final List<InningsBreakHighlightCard> cards;
  final ScorebugTokens tokens;
  final double scale;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(vertical: 4 * scale),
      physics: const ClampingScrollPhysics(),
      itemCount: cards.length,
      separatorBuilder: (_, i) => Divider(
        height: 1,
        color: Colors.black.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 8 * scale,
          ),
          child: Row(
            children: [
              InningsBreakHighlightAvatar(
                name: card.playerName,
                photoUrl: card.photoUrl,
                tokens: tokens,
                scale: scale,
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: TextStyle(
                        color: InningsBreakVisuals.textMuted,
                        fontSize: (landscape ? 9 : 8) * scale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      card.playerName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: InningsBreakVisuals.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: (landscape ? 12 : 11) * scale,
                      ),
                    ),
                    if (card.subtitle.isNotEmpty)
                      Text(
                        card.subtitle,
                        style: TextStyle(
                          color: InningsBreakVisuals.textMuted,
                          fontSize: (landscape ? 9 : 8.5) * scale,
                        ),
                      ),
                  ],
                ),
              ),
              if (card.statRuns != null && card.statBalls != null)
                InningsBreakRunsBalls(
                  runs: card.statRuns!,
                  balls: card.statBalls!,
                  scale: scale,
                  landscape: landscape,
                )
              else
                Text(
                  card.value,
                  style: TextStyle(
                    color: InningsBreakVisuals.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: (landscape ? 20 : 17) * scale,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.scale,
    required this.landscape,
  });

  final String label;
  final String value;
  final double scale;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: InningsBreakVisuals.rowAlt,
        border: Border(
          left: BorderSide(
            color: InningsBreakVisuals.highlightBlue,
            width: 3 * scale,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: InningsBreakVisuals.textMuted,
              fontSize: (landscape ? 10 : 9) * scale,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 3 * scale),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: InningsBreakVisuals.textPrimary,
              fontSize: (landscape ? 20 : 17) * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
