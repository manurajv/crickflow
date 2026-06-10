import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/scorecard_theme_extension.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../core/utils/match_score_display.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_rules_model.dart';
import '../../../../domain/scoring/ball_event_aggregator.dart';
import '../../../../domain/services/scorecard_display_service.dart';
import '../../../../shared/providers/providers.dart';

/// Professional collapsible innings scorecard (theme tokens only).
class MatchScorecardView extends ConsumerStatefulWidget {
  const MatchScorecardView({
    super.key,
    required this.match,
    this.bottomPadding = AppDimens.spaceXl,
  });

  final MatchModel match;
  final double bottomPadding;

  @override
  ConsumerState<MatchScorecardView> createState() => _MatchScorecardViewState();
}

class _MatchScorecardViewState extends ConsumerState<MatchScorecardView> {
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _expandedIndex = _defaultExpandedIndex(widget.match);
  }

  @override
  void didUpdateWidget(MatchScorecardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.innings.length != widget.match.innings.length) {
      _expandedIndex = _defaultExpandedIndex(widget.match);
    }
  }

  int? _defaultExpandedIndex(MatchModel match) {
    if (match.innings.isEmpty) return null;
    final cur = match.currentInnings;
    if (cur != null) {
      final idx = match.innings.indexWhere(
        (i) => i.inningsNumber == cur.inningsNumber,
      );
      if (idx >= 0) return idx;
    }
    return match.innings.length - 1;
  }

  void _toggleInnings(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final rules = match.rules;
    final events =
        ref.watch(ballEventsProvider(match.id)).valueOrNull ?? const [];

    if (match.innings.isEmpty) {
      return Center(
        child: Text(
          'No innings data yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      itemCount: match.innings.length,
      itemBuilder: (context, index) {
        final inn = match.innings[index];
        return _InningsScorecardCard(
          match: match,
          innings: inn,
          rules: rules,
          events: events,
          isExpanded: _expandedIndex == index,
          onHeaderTap: () => _toggleInnings(index),
        );
      },
    );
  }
}

class _InningsScorecardCard extends StatelessWidget {
  const _InningsScorecardCard({
    required this.match,
    required this.innings,
    required this.rules,
    required this.events,
    required this.isExpanded,
    required this.onHeaderTap,
  });

  final MatchModel match;
  final InningsModel innings;
  final MatchRulesModel rules;
  final List<BallEventModel> events;
  final bool isExpanded;
  final VoidCallback onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final teamName = MatchScoreDisplay.battingTeamName(match, innings);
    final overs =
        CricketMath.formatOvers(innings.legalBalls, rules.ballsPerOver);
    final scoreLine =
        '${innings.totalRuns}/${innings.totalWickets} ($overs Ov)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onHeaderTap,
                child: ColoredBox(
                  color: isExpanded
                      ? _scorecardTheme(context)
                          .inningsHeaderExpandedBackground
                      : _scorecardTheme(context).inningsHeaderBackground,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceMd,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            teamName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          scoreLine,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceXs),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.onSurfaceVariant,
                          size: AppDimens.iconMd,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isExpanded)
                _ScorecardTableScope(
                  child: _InningsExpandedBody(
                    match: match,
                    innings: innings,
                    rules: rules,
                    events: events,
                  ),
                ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: _subtleDividerColor(colorScheme),
        ),
      ],
    );
  }
}

class _ScorecardTableScope extends StatelessWidget {
  const _ScorecardTableScope({required this.child});

  final Widget child;

  static const double _minTableWidth = 360;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _minTableWidth) return child;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _minTableWidth,
            child: child,
          ),
        );
      },
    );
  }
}

class _InningsExpandedBody extends StatelessWidget {
  const _InningsExpandedBody({
    required this.match,
    required this.innings,
    required this.rules,
    required this.events,
  });

  final MatchModel match;
  final InningsModel innings;
  final MatchRulesModel rules;
  final List<BallEventModel> events;

  @override
  Widget build(BuildContext context) {
    final inningsEvents =
        BallEventAggregator.eventsForInnings(events, innings.inningsNumber);
    final derived = inningsEvents.isNotEmpty
        ? BallEventAggregator().projectInnings(
            match: match,
            lineupInnings: innings,
            allEvents: events,
          )
        : null;
    final displayInnings = derived?.innings ?? innings;
    final extras = derived?.extrasBreakdown ??
        ScorecardDisplayService.extrasBreakdown(
          innings: innings,
          events: inningsEvents,
          rules: rules,
        );
    final extrasDetail = ScorecardDisplayService.extrasDetailLabel(extras);
    final toBat = ScorecardDisplayService.toBatNames(match, displayInnings);
    final crr = MatchScoreDisplay.runRateFor(displayInnings, rules);
    final overs = CricketMath.formatOvers(
      displayInnings.legalBalls,
      rules.ballsPerOver,
    );
    final wicketByBatsman = ScorecardDisplayService.wicketEventsByBatsman(
      innings: displayInnings,
      events: inningsEvents,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BattingSection(
          innings: displayInnings,
          wicketByBatsman: wicketByBatsman,
          playerNames: ScorecardDisplayService.playerNamesForInnings(
            match,
            displayInnings,
          ),
          strikerId: displayInnings.strikerId,
          nonStrikerId: displayInnings.nonStrikerId,
          batterMinutes: derived?.batterMinutes ?? const {},
        ),
        _ExtrasRow(extras: extras, extrasDetail: extrasDetail),
        _TotalRow(
          totalLine:
              '${displayInnings.totalRuns}/${displayInnings.totalWickets} ($overs Ov)',
          crr: crr,
        ),
        if (toBat.isNotEmpty) _ToBatSection(names: toBat),
        _BowlingSection(
          innings: displayInnings,
          rules: rules,
          bowlerMaidens: derived?.bowlerMaidens ?? const {},
        ),
        _FallOfWicketsSection(
          entries: displayInnings.fallOfWickets,
          ballsPerOver: rules.ballsPerOver,
        ),
      ],
    );
  }
}

// ── Layout tokens ───────────────────────────────────────────────────────────

const double _kColR = 30;
const double _kColB = 30;
const double _kCol4s = 30;
const double _kCol6s = 30;
const double _kColSr = 40;
const double _kColMin = 36;
const double _kColO = 38;
const double _kColM = 30;
const double _kColBowR = 30;
const double _kColW = 30;
const double _kColEco = 42;
const double _kFowScoreCol = 96;

const double _kStatsBlockWidth =
    _kColR + _kColB + _kCol4s + _kCol6s + _kColSr + _kColMin;

const double _kBowlingStatsWidth =
    _kColO + _kColM + _kColBowR + _kColW + _kColEco;

const EdgeInsets _kRowPadding = EdgeInsets.symmetric(
  horizontal: AppDimens.spaceMd,
  vertical: 11,
);

Color _subtleDividerColor(ColorScheme scheme) =>
    scheme.outline.withValues(alpha: 0.22);

ScorecardTheme _scorecardTheme(BuildContext context) =>
    Theme.of(context).extension<ScorecardTheme>() ?? ScorecardTheme.dark;

/// Theme-derived scorecard text styles (no hardcoded colors).
class _ScorecardStyles {
  _ScorecardStyles(this.context);

  final BuildContext context;
  late final ThemeData _theme = Theme.of(context);
  late final ColorScheme _cs = _theme.colorScheme;
  late final ScorecardTheme _sc = _scorecardTheme(context);

  Color get dataRowBg => _sc.dataRowBackground;

  Color get sectionHeaderBg => _sc.sectionHeaderBackground;

  Color get summaryRowBg => _sc.summaryRowBackground;

  TextStyle get sectionLabel => _theme.textTheme.labelMedium!.copyWith(
        fontWeight: FontWeight.w600,
        color: _cs.onSurfaceVariant,
        letterSpacing: 0.1,
      );

  TextStyle get statHeader => _theme.textTheme.labelSmall!.copyWith(
        fontWeight: FontWeight.w600,
        color: _cs.onSurfaceVariant,
        letterSpacing: 0.15,
      );

  TextStyle get playerName => _theme.textTheme.bodyLarge!.copyWith(
        fontWeight: FontWeight.w600,
        color: _cs.primary,
        height: 1.15,
      );

  TextStyle get dismissal => _theme.textTheme.bodySmall!.copyWith(
        color: _cs.onSurfaceVariant,
        height: 1.25,
      );

  TextStyle get statValue => _theme.textTheme.bodyMedium!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.25,
      );

  TextStyle get statValueBold => statValue.copyWith(fontWeight: FontWeight.w700);

  TextStyle get bodyPrimary => _theme.textTheme.bodyMedium!.copyWith(
        color: _cs.onSurface,
      );

  TextStyle get bodyMuted => _theme.textTheme.labelSmall!.copyWith(
        color: _cs.onSurfaceVariant,
      );
}

class _SectionHeaderBar extends StatelessWidget {
  const _SectionHeaderBar({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final styles = _ScorecardStyles(context);
    return Container(
      color: styles.sectionHeaderBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm + 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: styles.sectionLabel),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _StatHeaderRow extends StatelessWidget {
  const _StatHeaderRow({required this.columns});

  final List<Widget> columns;

  @override
  Widget build(BuildContext context) {
    final style = _ScorecardStyles(context).statHeader;
    return Row(
      children: columns
          .map(
            (w) => DefaultTextStyle(
              style: style,
              textAlign: TextAlign.end,
              child: w,
            ),
          )
          .toList(),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: _subtleDividerColor(Theme.of(context).colorScheme),
    );
  }
}

/// Single highlighted data row (batters, bowlers, fall of wickets, extras).
class _DataRow extends StatelessWidget {
  const _DataRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bg = _ScorecardStyles(context).dataRowBg;
    return Column(
      children: [
        ColoredBox(
          color: bg,
          child: Padding(
            padding: _kRowPadding,
            child: child,
          ),
        ),
        const _RowDivider(),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.width,
    this.emphasize = false,
  });

  final String value;
  final double width;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final styles = _ScorecardStyles(context);
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.end,
        style: emphasize ? styles.statValueBold : styles.statValue,
      ),
    );
  }
}

class _BattingSection extends StatelessWidget {
  const _BattingSection({
    required this.innings,
    required this.wicketByBatsman,
    required this.playerNames,
    this.strikerId,
    this.nonStrikerId,
    this.batterMinutes = const {},
  });

  final InningsModel innings;
  final Map<String, BallEventModel> wicketByBatsman;
  final Map<String, String> playerNames;
  final String? strikerId;
  final String? nonStrikerId;
  final Map<String, int> batterMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final batsmen = innings.batsmen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderBar(
          label: 'Batters',
          trailing: _StatHeaderRow(
            columns: [
              SizedBox(width: _kColR, child: const Text('R')),
              SizedBox(width: _kColB, child: const Text('B')),
              SizedBox(width: _kCol4s, child: const Text('4s')),
              SizedBox(width: _kCol6s, child: const Text('6s')),
              SizedBox(width: _kColSr, child: const Text('SR')),
              SizedBox(width: _kColMin, child: const Text('Min')),
            ],
          ),
        ),
        if (batsmen.isEmpty)
          Padding(
            padding: _kRowPadding,
            child: Text(
              'No batting data yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...batsmen.map((b) {
            final onCrease =
                b.playerId == strikerId || b.playerId == nonStrikerId;
            return _BattingRow(
              batsman: b,
              onCrease: onCrease,
              wicketEvent: wicketByBatsman[b.playerId],
              playerNames: playerNames,
              minutes: batterMinutes[b.playerId],
            );
          }),
      ],
    );
  }
}

class _BattingRow extends StatelessWidget {
  const _BattingRow({
    required this.batsman,
    required this.onCrease,
    this.wicketEvent,
    this.playerNames = const {},
    this.minutes,
  });

  final BatsmanInningsModel batsman;
  final bool onCrease;
  final BallEventModel? wicketEvent;
  final Map<String, String> playerNames;
  final int? minutes;

  @override
  Widget build(BuildContext context) {
    final styles = _ScorecardStyles(context);
    final name = batsman.playerName.isNotEmpty
        ? batsman.playerName
        : batsman.playerId;
    final dismissal = ScorecardDisplayService.batsmanDismissalText(
      batsman,
      onCrease: onCrease,
      wicketEvent: wicketEvent,
      playerNames: playerNames,
    );
    final sr = CricketMath.strikeRate(batsman.runs, batsman.balls);

    return _DataRow(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.playerName,
                ),
                if (dismissal.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    dismissal,
                    maxLines: 2,
                    softWrap: true,
                    style: styles.dismissal,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: _kStatsBlockWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _StatCell(
                  value: '${batsman.runs}',
                  width: _kColR,
                  emphasize: true,
                ),
                _StatCell(value: '${batsman.balls}', width: _kColB),
                _StatCell(value: '${batsman.fours}', width: _kCol4s),
                _StatCell(value: '${batsman.sixes}', width: _kCol6s),
                _StatCell(value: sr.toStringAsFixed(1), width: _kColSr),
                _StatCell(
                  value: minutes != null ? '$minutes' : '-',
                  width: _kColMin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtrasRow extends StatelessWidget {
  const _ExtrasRow({
    required this.extras,
    required this.extrasDetail,
  });

  final InningsExtrasBreakdown extras;
  final String extrasDetail;

  @override
  Widget build(BuildContext context) {
    final styles = _ScorecardStyles(context);

    final rightLabel = extrasDetail.isEmpty
        ? '${extras.total}'
        : '${extras.total} $extrasDetail';

    return _DataRow(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Extras',
            style: styles.bodyPrimary.copyWith(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: extrasDetail.isEmpty
                ? Text(
                    rightLabel,
                    textAlign: TextAlign.end,
                    style: styles.statValueBold,
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${extras.total}',
                          style: styles.statValueBold,
                        ),
                        TextSpan(
                          text: ' $extrasDetail',
                          style: styles.bodyMuted,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.end,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.totalLine,
    required this.crr,
  });

  final String totalLine;
  final double crr;

  @override
  Widget build(BuildContext context) {
    final styles = _ScorecardStyles(context);

    return Column(
      children: [
        ColoredBox(
          color: styles.summaryRowBg,
          child: Padding(
            padding: _kRowPadding,
            child: Row(
              children: [
                Text(
                  'Total',
                  style: styles.statValueBold,
                ),
                const Spacer(),
                Text(
                  totalLine,
                  style: styles.statValueBold,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Text(
                  'CRR ${crr.toStringAsFixed(2)}',
                  style: styles.bodyMuted.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        const _RowDivider(),
      ],
    );
  }
}

class _ToBatSection extends StatelessWidget {
  const _ToBatSection({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To bat:',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            names.join(', '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _BowlingSection extends StatelessWidget {
  const _BowlingSection({
    required this.innings,
    required this.rules,
    this.bowlerMaidens = const {},
  });

  final InningsModel innings;
  final MatchRulesModel rules;
  final Map<String, int> bowlerMaidens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bowlers = innings.bowlers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderBar(
          label: 'Bowlers',
          trailing: _StatHeaderRow(
            columns: [
              SizedBox(width: _kColO, child: const Text('O')),
              SizedBox(width: _kColM, child: const Text('M')),
              SizedBox(width: _kColBowR, child: const Text('R')),
              SizedBox(width: _kColW, child: const Text('W')),
              SizedBox(width: _kColEco, child: const Text('Eco')),
            ],
          ),
        ),
        if (bowlers.isEmpty)
          Padding(
            padding: _kRowPadding,
            child: Text(
              'No bowling data yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...bowlers.map(
            (b) => _BowlingRow(
              bowler: b,
              rules: rules,
              maidens: bowlerMaidens[b.playerId] ?? 0,
            ),
          ),
      ],
    );
  }
}

class _BowlingRow extends StatelessWidget {
  const _BowlingRow({
    required this.bowler,
    required this.rules,
    this.maidens = 0,
  });

  final BowlerInningsModel bowler;
  final MatchRulesModel rules;
  final int maidens;

  @override
  Widget build(BuildContext context) {
    final styles = _ScorecardStyles(context);
    final name =
        bowler.playerName.isNotEmpty ? bowler.playerName : bowler.playerId;
    final overs =
        CricketMath.formatOvers(bowler.oversBowledBalls, rules.ballsPerOver);
    final eco = CricketMath.economyRate(
      bowler.runsConceded,
      bowler.oversBowledBalls,
      rules.ballsPerOver,
    );

    return _DataRow(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.playerName,
            ),
          ),
          SizedBox(
            width: _kBowlingStatsWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _StatCell(value: overs, width: _kColO),
                _StatCell(value: '$maidens', width: _kColM),
                _StatCell(
                  value: '${bowler.runsConceded}',
                  width: _kColBowR,
                ),
                _StatCell(
                  value: '${bowler.wickets}',
                  width: _kColW,
                  emphasize: bowler.wickets > 0,
                ),
                _StatCell(value: eco.toStringAsFixed(2), width: _kColEco),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FallOfWicketsSection extends StatelessWidget {
  const _FallOfWicketsSection({
    required this.entries,
    required this.ballsPerOver,
  });

  final List<FallOfWicketRecord> entries;
  final int ballsPerOver;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final styles = _ScorecardStyles(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderBar(
          label: 'Fall of wickets',
          trailing: SizedBox(
            width: _kFowScoreCol,
            child: Text(
              'Score (Over)',
              textAlign: TextAlign.end,
              style: styles.statHeader,
            ),
          ),
        ),
        ...entries.map(
          (f) => _FallOfWicketRow(entry: f, ballsPerOver: ballsPerOver),
        ),
      ],
    );
  }
}

class _FallOfWicketRow extends StatelessWidget {
  const _FallOfWicketRow({
    required this.entry,
    required this.ballsPerOver,
  });

  final FallOfWicketRecord entry;
  final int ballsPerOver;

  @override
  Widget build(BuildContext context) {
    final styles = _ScorecardStyles(context);
    final name = entry.batsmanName.isNotEmpty
        ? entry.batsmanName
        : entry.batsmanId;
    final over = CricketMath.formatOvers(entry.legalBalls, ballsPerOver);

    return _DataRow(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.wicketNumber}',
              style: styles.bodyMuted.copyWith(
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.playerName.copyWith(
                fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
              ),
            ),
          ),
          SizedBox(
            width: _kFowScoreCol,
            child: Text(
              '${entry.teamScore} ($over Ov)',
              textAlign: TextAlign.end,
              style: styles.bodyMuted.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
