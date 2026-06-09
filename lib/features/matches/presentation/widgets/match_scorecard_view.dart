import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../core/utils/match_score_display.dart';
import '../../../../data/models/ball_event_model.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_rules_model.dart';
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
      padding: EdgeInsets.only(
        top: AppDimens.spaceSm,
        bottom: widget.bottomPadding,
      ),
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

    final headerBg = isExpanded
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: Material(
        color: colorScheme.surface,
        borderRadius: AppDimens.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onHeaderTap,
              child: Container(
                color: headerBg,
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
                        ),
                      ),
                    ),
                    Text(
                      scoreLine,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceXs),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: colorScheme.onSurfaceVariant,
                      size: AppDimens.iconMd,
                    ),
                  ],
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
    );
  }
}

/// Horizontal scroll on narrow screens to avoid column clipping.
class _ScorecardTableScope extends StatelessWidget {
  const _ScorecardTableScope({required this.child});

  final Widget child;

  static const double _minTableWidth = 340;

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
    final extras = ScorecardDisplayService.extrasBreakdown(
      innings: innings,
      events: events,
      rules: rules,
    );
    final extrasDetail = ScorecardDisplayService.extrasDetailLabel(extras);
    final toBat = ScorecardDisplayService.toBatNames(match, innings);
    final crr = MatchScoreDisplay.runRateFor(innings, rules);
    final overs =
        CricketMath.formatOvers(innings.legalBalls, rules.ballsPerOver);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BattingSection(
          innings: innings,
          strikerId: innings.strikerId,
          nonStrikerId: innings.nonStrikerId,
        ),
        _ExtrasRow(extras: extras, extrasDetail: extrasDetail),
        _TotalRow(
          totalLine:
              '${innings.totalRuns}/${innings.totalWickets} ($overs Ov)',
          crr: crr,
        ),
        if (toBat.isNotEmpty) _ToBatSection(names: toBat),
        const SizedBox(height: AppDimens.spaceSm),
        _BowlingSection(innings: innings, rules: rules),
        _FallOfWicketsSection(
          entries: innings.fallOfWickets,
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

const EdgeInsets _kRowPadding = EdgeInsets.symmetric(
  horizontal: AppDimens.spaceMd,
  vertical: 10,
);

class _SectionHeaderBar extends StatelessWidget {
  const _SectionHeaderBar({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm + 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.2,
    );
    return Row(
      children: columns
          .map(
            (w) => DefaultTextStyle(
              style: style ?? const TextStyle(),
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
      color: Theme.of(context).dividerColor,
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
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.end,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _BattingSection extends StatelessWidget {
  const _BattingSection({
    required this.innings,
    this.strikerId,
    this.nonStrikerId,
  });

  final InningsModel innings;
  final String? strikerId;
  final String? nonStrikerId;

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
            return _BattingRow(batsman: b, onCrease: onCrease);
          }),
      ],
    );
  }
}

class _BattingRow extends StatelessWidget {
  const _BattingRow({
    required this.batsman,
    required this.onCrease,
  });

  final BatsmanInningsModel batsman;
  final bool onCrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = batsman.playerName.isNotEmpty
        ? batsman.playerName
        : batsman.playerId;
    final dismissal = ScorecardDisplayService.batsmanDismissalText(
      batsman,
      onCrease: onCrease,
    );
    final sr = CricketMath.strikeRate(batsman.runs, batsman.balls);

    return Column(
      children: [
        Padding(
          padding: _kRowPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    if (dismissal.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        dismissal,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StatCell(
                value: '${batsman.runs}',
                width: _kColR,
                emphasize: true,
              ),
              _StatCell(value: '${batsman.balls}', width: _kColB),
              _StatCell(value: '${batsman.fours}', width: _kCol4s),
              _StatCell(value: '${batsman.sixes}', width: _kCol6s),
              _StatCell(value: sr.toStringAsFixed(1), width: _kColSr),
              _StatCell(value: '-', width: _kColMin),
            ],
          ),
        ),
        const _RowDivider(),
      ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: _kRowPadding,
          child: Row(
            children: [
              Text(
                'Extras',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${extras.total}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (extrasDetail.isNotEmpty) ...[
                const SizedBox(width: AppDimens.spaceSm),
                Flexible(
                  child: Text(
                    extrasDetail,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const _RowDivider(),
      ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: _kRowPadding,
          child: Row(
            children: [
              Text(
                'Total',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                totalLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Text(
                'CRR ${crr.toStringAsFixed(2)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
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
        AppDimens.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To bat:',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 96),
            child: SingleChildScrollView(
              child: Text(
                names.join(', '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
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
  });

  final InningsModel innings;
  final MatchRulesModel rules;

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
          ...bowlers.map((b) => _BowlingRow(bowler: b, rules: rules)),
      ],
    );
  }
}

class _BowlingRow extends StatelessWidget {
  const _BowlingRow({
    required this.bowler,
    required this.rules,
  });

  final BowlerInningsModel bowler;
  final MatchRulesModel rules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name =
        bowler.playerName.isNotEmpty ? bowler.playerName : bowler.playerId;
    final overs =
        CricketMath.formatOvers(bowler.oversBowledBalls, rules.ballsPerOver);
    final eco = CricketMath.economyRate(
      bowler.runsConceded,
      bowler.oversBowledBalls,
      rules.ballsPerOver,
    );

    return Column(
      children: [
        Padding(
          padding: _kRowPadding,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    height: 1.2,
                  ),
                ),
              ),
              _StatCell(value: overs, width: _kColO),
              _StatCell(value: '0', width: _kColM),
              _StatCell(value: '${bowler.runsConceded}', width: _kColBowR),
              _StatCell(
                value: '${bowler.wickets}',
                width: _kColW,
                emphasize: bowler.wickets > 0,
              ),
              _StatCell(value: eco.toStringAsFixed(2), width: _kColEco),
            ],
          ),
        ),
        const _RowDivider(),
      ],
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderBar(
          label: 'Fall of wickets',
          trailing: Text(
            'Score (Over)',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = entry.batsmanName.isNotEmpty
        ? entry.batsmanName
        : entry.batsmanId;
    final over = CricketMath.formatOvers(entry.legalBalls, ballsPerOver);

    return Column(
      children: [
        Padding(
          padding: _kRowPadding,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${entry.wicketNumber}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${entry.teamScore} ($over Ov)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const _RowDivider(),
      ],
    );
  }
}
