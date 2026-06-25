import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/tournament_model.dart';
import '../overview/tournament_overview_widgets.dart';

class PointsTableColumnDef {
  const PointsTableColumnDef({
    required this.shortLabel,
    required this.longLabel,
    required this.description,
    this.emphasize = false,
    this.numeric = true,
  });

  final String shortLabel;
  final String longLabel;
  final String description;
  final bool emphasize;
  final bool numeric;

  String label({required bool useLongLabels}) =>
      useLongLabels ? longLabel : shortLabel;
}

abstract final class PointsTableColumns {
  static const rank = PointsTableColumnDef(
    shortLabel: '#',
    longLabel: 'Rank',
    description: 'Position in the standings table.',
    numeric: true,
  );

  static const team = PointsTableColumnDef(
    shortLabel: 'Team',
    longLabel: 'Team',
    description: 'Team name.',
    numeric: false,
  );

  static const played = PointsTableColumnDef(
    shortLabel: 'P',
    longLabel: 'Played',
    description: 'Number of matches completed.',
  );

  static const won = PointsTableColumnDef(
    shortLabel: 'W',
    longLabel: 'Won',
    description: 'Matches won.',
  );

  static const lost = PointsTableColumnDef(
    shortLabel: 'L',
    longLabel: 'Lost',
    description: 'Matches lost.',
  );

  static const tied = PointsTableColumnDef(
    shortLabel: 'T',
    longLabel: 'Tied',
    description: 'Matches tied.',
  );

  static const noResult = PointsTableColumnDef(
    shortLabel: 'NR',
    longLabel: 'No result',
    description: 'Matches abandoned or with no result.',
  );

  static const points = PointsTableColumnDef(
    shortLabel: 'Pts',
    longLabel: 'Points',
    description: 'Total league points (wins, ties, no-results, bonus/penalty).',
    emphasize: true,
  );

  static const nrr = PointsTableColumnDef(
    shortLabel: 'NRR',
    longLabel: 'Net run rate',
    description:
        'Runs scored per over minus runs conceded per over — used to break ties.',
    emphasize: true,
  );

  static const runsFor = PointsTableColumnDef(
    shortLabel: 'RF',
    longLabel: 'Runs for',
    description: 'Total runs scored across all innings.',
  );

  static const oversFaced = PointsTableColumnDef(
    shortLabel: 'OF',
    longLabel: 'Overs faced',
    description: 'Total overs batted (used for run-rate calculations).',
  );

  static const runsAgainst = PointsTableColumnDef(
    shortLabel: 'RA',
    longLabel: 'Runs against',
    description: 'Total runs conceded while bowling.',
  );

  static const oversBowled = PointsTableColumnDef(
    shortLabel: 'OB',
    longLabel: 'Overs bowled',
    description: 'Total overs bowled (used for run-rate calculations).',
  );

  static const bonusPoints = PointsTableColumnDef(
    shortLabel: 'BP',
    longLabel: 'Bonus pts',
    description: 'Extra points awarded by tournament rules.',
  );

  static const penaltyPoints = PointsTableColumnDef(
    shortLabel: 'PP',
    longLabel: 'Penalty pts',
    description: 'Points deducted for rule breaches or walkovers.',
  );

  static List<PointsTableColumnDef> glossary = [
    rank,
    team,
    played,
    won,
    lost,
    tied,
    noResult,
    points,
    nrr,
    runsFor,
    oversFaced,
    runsAgainst,
    oversBowled,
    bonusPoints,
    penaltyPoints,
  ];
}

/// Standings table with optional full column names and a column guide.
class TournamentPointsTableView extends StatefulWidget {
  const TournamentPointsTableView({
    super.key,
    required this.title,
    required this.entries,
    this.trailing,
  });

  final String title;
  final List<PointsTableEntry> entries;
  final Widget? trailing;

  @override
  State<TournamentPointsTableView> createState() =>
      _TournamentPointsTableViewState();
}

class _TournamentPointsTableViewState extends State<TournamentPointsTableView> {
  var _useLongLabels = false;

  bool get _showBonusPenalty => widget.entries.any(
        (e) => e.bonusPoints != 0 || e.penaltyPoints != 0,
      );

  List<PointsTableColumnDef> get _statColumns => [
        PointsTableColumns.played,
        PointsTableColumns.won,
        PointsTableColumns.lost,
        PointsTableColumns.tied,
        PointsTableColumns.noResult,
        PointsTableColumns.points,
        PointsTableColumns.nrr,
        PointsTableColumns.runsFor,
        PointsTableColumns.oversFaced,
        PointsTableColumns.runsAgainst,
        PointsTableColumns.oversBowled,
        if (_showBonusPenalty) ...[
          PointsTableColumns.bonusPoints,
          PointsTableColumns.penaltyPoints,
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    if (widget.entries.isEmpty) {
      return const TournamentOverviewEmptyInline(
        message: 'Points table will populate after matches are played.',
      );
    }

    return TournamentOverviewSectionCard(
      title: widget.title,
      trailing: widget.trailing,
      action: _TableToolbar(
        cf: cf,
        useLongLabels: _useLongLabels,
        onToggleLongLabels: (v) => setState(() => _useLongLabels = v),
        onOpenGuide: () => _showColumnGuide(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: cf.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _tableWidth(_useLongLabels, _statColumns),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PointsTableHeaderRow(
                    cf: cf,
                    useLongLabels: _useLongLabels,
                    statColumns: _statColumns,
                  ),
                  for (var i = 0; i < widget.entries.length; i++)
                    _PointsTableDataRow(
                      cf: cf,
                      entry: widget.entries[i],
                      index: i,
                      statColumns: _statColumns,
                      useLongLabels: _useLongLabels,
                      isLast: i == widget.entries.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _tableWidth(
    bool useLongLabels,
    List<PointsTableColumnDef> statColumns,
  ) {
    const rankWidth = 36.0;
    const rowPadding = 16.0;
    final teamWidth = _columnWidth(PointsTableColumns.team, useLongLabels);
    final statsWidth = statColumns.fold<double>(
      0,
      (sum, col) => sum + _columnWidth(col, useLongLabels),
    );
    return rowPadding + rankWidth + teamWidth + statsWidth;
  }

  void _showColumnGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final cf = ctx.cf;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppDimens.spaceMd,
                right: AppDimens.spaceMd,
                top: AppDimens.spaceMd,
                bottom: MediaQuery.paddingOf(ctx).bottom + AppDimens.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                      decoration: BoxDecoration(
                        color: cf.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    'Points table guide',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  Text(
                    'Short codes used in the table and what they mean.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: cf.textSecondary,
                        ),
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: PointsTableColumns.glossary.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cf.border.withValues(alpha: 0.6),
                      ),
                      itemBuilder: (_, i) {
                        final col = PointsTableColumns.glossary[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  col.shortLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: cf.accent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      col.longLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      col.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cf.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TableToolbar extends StatelessWidget {
  const _TableToolbar({
    required this.cf,
    required this.useLongLabels,
    required this.onToggleLongLabels,
    required this.onOpenGuide,
  });

  final CfColors cf;
  final bool useLongLabels;
  final ValueChanged<bool> onToggleLongLabels;
  final VoidCallback onOpenGuide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton.icon(
          onPressed: onOpenGuide,
          icon: Icon(Icons.info_outline, size: 18, color: cf.accent),
          label: Text(
            'Column guide',
            style: TextStyle(color: cf.accent, fontSize: 13),
          ),
        ),
        const Spacer(),
        Text(
          'Full names',
          style: TextStyle(fontSize: 12, color: cf.textSecondary),
        ),
        const SizedBox(width: 6),
        Switch.adaptive(
          value: useLongLabels,
          onChanged: onToggleLongLabels,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _PointsTableHeaderRow extends StatelessWidget {
  const _PointsTableHeaderRow({
    required this.cf,
    required this.useLongLabels,
    required this.statColumns,
  });

  final CfColors cf;
  final bool useLongLabels;
  final List<PointsTableColumnDef> statColumns;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cf.sectionBackground,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          _HeaderCell(
            label: PointsTableColumns.rank.label(useLongLabels: useLongLabels),
            width: 36,
            align: TextAlign.center,
            cf: cf,
            emphasize: false,
          ),
          _HeaderCell(
            label: PointsTableColumns.team.label(useLongLabels: useLongLabels),
            width: useLongLabels ? 120 : 100,
            align: TextAlign.start,
            cf: cf,
            emphasize: false,
          ),
          ...statColumns.map(
            (col) => _HeaderCell(
              label: col.label(useLongLabels: useLongLabels),
              width: _columnWidth(col, useLongLabels),
              align: TextAlign.center,
              cf: cf,
              emphasize: col.emphasize,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsTableDataRow extends StatelessWidget {
  const _PointsTableDataRow({
    required this.cf,
    required this.entry,
    required this.index,
    required this.statColumns,
    required this.useLongLabels,
    required this.isLast,
  });

  final CfColors cf;
  final PointsTableEntry entry;
  final int index;
  final List<PointsTableColumnDef> statColumns;
  final bool useLongLabels;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final rank = entry.position > 0 ? entry.position : index + 1;
    final isTopThree = rank <= 3;

    return Container(
      decoration: BoxDecoration(
        color: index.isOdd ? cf.sectionBackground.withValues(alpha: 0.35) : null,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: cf.border.withValues(alpha: 0.5)),
              ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Center(
              child: _RankBadge(rank: rank, isTopThree: isTopThree, cf: cf),
            ),
          ),
          SizedBox(
            width: _columnWidth(PointsTableColumns.team, useLongLabels),
            child: Text(
              entry.teamName.isNotEmpty ? entry.teamName : entry.teamId,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isTopThree ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
                color: cf.textPrimary,
              ),
            ),
          ),
          ...statColumns.map((col) {
            final value = _cellValue(entry, col);
            final emphasize = col.emphasize;
            return _DataCell(
              value: value,
              width: _columnWidth(col, useLongLabels),
              cf: cf,
              emphasize: emphasize,
              nrrStyle: col == PointsTableColumns.nrr,
              entry: entry,
            );
          }),
        ],
      ),
    );
  }

  String _cellValue(PointsTableEntry entry, PointsTableColumnDef col) {
    if (col == PointsTableColumns.played) return '${entry.played}';
    if (col == PointsTableColumns.won) return '${entry.won}';
    if (col == PointsTableColumns.lost) return '${entry.lost}';
    if (col == PointsTableColumns.tied) return '${entry.tied}';
    if (col == PointsTableColumns.noResult) return '${entry.noResult}';
    if (col == PointsTableColumns.points) return '${entry.points}';
    if (col == PointsTableColumns.nrr) {
      final nrr = entry.netRunRate;
      final sign = nrr > 0 ? '+' : '';
      return '$sign${nrr.toStringAsFixed(3)}';
    }
    if (col == PointsTableColumns.runsFor) return '${entry.runsFor}';
    if (col == PointsTableColumns.oversFaced) {
      return entry.oversFaced.toStringAsFixed(1);
    }
    if (col == PointsTableColumns.runsAgainst) return '${entry.runsAgainst}';
    if (col == PointsTableColumns.oversBowled) {
      return entry.oversBowled.toStringAsFixed(1);
    }
    if (col == PointsTableColumns.bonusPoints) return '${entry.bonusPoints}';
    if (col == PointsTableColumns.penaltyPoints) {
      return '${entry.penaltyPoints}';
    }
    return '';
  }
}

double _columnWidth(PointsTableColumnDef col, bool useLongLabels) {
  if (!col.numeric && col != PointsTableColumns.team) return 72;
  if (col == PointsTableColumns.team) return useLongLabels ? 120 : 100;
  if (useLongLabels) {
    return switch (col.longLabel) {
      'Net run rate' => 96,
      'No result' => 76,
      'Overs faced' || 'Overs bowled' => 84,
      'Runs against' || 'Runs for' => 76,
      'Bonus pts' || 'Penalty pts' => 80,
      _ => 64,
    };
  }
  return switch (col.shortLabel) {
    'NRR' => 56,
    'NR' => 40,
    'Pts' => 44,
    _ => 36,
  };
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.width,
    required this.align,
    required this.cf,
    required this.emphasize,
  });

  final String label;
  final double width;
  final TextAlign align;
  final CfColors cf;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: emphasize ? 12 : 11,
          fontWeight: FontWeight.w700,
          color: emphasize ? cf.accent : cf.textSecondary,
          height: 1.2,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.value,
    required this.width,
    required this.cf,
    required this.emphasize,
    required this.nrrStyle,
    required this.entry,
  });

  final String value;
  final double width;
  final CfColors cf;
  final bool emphasize;
  final bool nrrStyle;
  final PointsTableEntry entry;

  @override
  Widget build(BuildContext context) {
    Color? color;
    if (nrrStyle) {
      if (entry.netRunRate > 0) {
        color = cf.success;
      } else if (entry.netRunRate < 0) {
        color = cf.error;
      }
    }

    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: emphasize ? 13 : 12,
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
          color: color ?? (emphasize ? cf.textPrimary : cf.textSecondary),
          fontFeatures: nrrStyle ? const [FontFeature.tabularFigures()] : null,
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
    required this.isTopThree,
    required this.cf,
  });

  final int rank;
  final bool isTopThree;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (!isTopThree) {
      return Text(
        '$rank',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cf.textMuted,
        ),
      );
    }

    final (color, icon) = switch (rank) {
      1 => (cf.accent, Icons.emoji_events_outlined),
      2 => (cf.textSecondary, Icons.military_tech_outlined),
      _ => (const Color(0xFFCD7F32), Icons.military_tech_outlined),
    };

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}
