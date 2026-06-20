import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/match_analytics_models.dart';
import '../../../../../shared/widgets/stat_grid.dart';
import 'insights_chart_widgets.dart';

class InsightsTestSessionSection extends StatelessWidget {
  const InsightsTestSessionSection({
    super.key,
    required this.sessions,
    required this.cf,
  });

  final List<TestSessionBlock> sessions;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const InsightsEmptyHint(
        message: 'Session analysis appears once overs are bowled.',
      );
    }

    return Column(
      children: sessions.map((s) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: AppDimens.cardPadding,
          decoration: cfCardDecoration(context),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                    ),
                    Text(
                      s.inningsLabel,
                      style: TextStyle(fontSize: 11, color: cf.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                '${s.runs}/${s.wickets}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cf.scoreEmphasis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'RR ${s.runRate.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: cf.textSecondary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class InsightsTestNewBallSection extends StatelessWidget {
  const InsightsTestNewBallSection({
    super.key,
    required this.stats,
    required this.cf,
  });

  final List<TestNewBallStats> stats;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const InsightsEmptyHint(
        message: 'New ball analysis appears after the opening overs.',
      );
    }

    return Column(
      children: stats.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: StatGrid(
            cells: [
              StatCellData(
                value: '${s.runs}/${s.wickets}',
                label: '${s.inningsLabel} · ${s.label}',
              ),
              StatCellData(
                value: s.runRate.toStringAsFixed(2),
                label: 'Run Rate',
              ),
              StatCellData(value: '${s.boundaries}', label: 'Boundaries'),
              StatCellData(
                value: '${s.dotBallPercent.toStringAsFixed(0)}%',
                label: 'Dot %',
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class InsightsTestBattingControlSection extends StatelessWidget {
  const InsightsTestBattingControlSection({
    super.key,
    required this.metrics,
    required this.cf,
  });

  final TestBattingControlMetrics metrics;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatGrid(
          cells: [
            StatCellData(
              value: metrics.controlLabel,
              label: 'Batting Style',
            ),
            StatCellData(
              value: metrics.strikeRate.toStringAsFixed(0),
              label: 'Strike Rate',
            ),
            StatCellData(
              value: '${metrics.dotBallPercent.toStringAsFixed(0)}%',
              label: 'Dot Ball %',
            ),
            StatCellData(
              value: '${metrics.boundaryPercent.toStringAsFixed(0)}%',
              label: 'Boundary Ball %',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        Text(
          'Scoring shots on ${metrics.scoringShotPercent.toStringAsFixed(0)}% of legal deliveries.',
          style: TextStyle(fontSize: 11, color: cf.textSecondary),
        ),
      ],
    );
  }
}

class InsightsTestBowlingPressureSection extends StatelessWidget {
  const InsightsTestBowlingPressureSection({
    super.key,
    required this.metrics,
    required this.cf,
  });

  final TestBowlingPressureMetrics metrics;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatGrid(
          cells: [
            StatCellData(
              value: metrics.pressureLabel,
              label: 'Bowling Pressure',
            ),
            StatCellData(
              value: '${metrics.dotBallPercent.toStringAsFixed(0)}%',
              label: 'Dot Ball %',
            ),
            StatCellData(
              value: metrics.economyRate.toStringAsFixed(2),
              label: 'Economy',
            ),
            StatCellData(value: '${metrics.wickets}', label: 'Wickets'),
          ],
        ),
        if (metrics.topBowlerLabel != '—') ...[
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Most dots: ${metrics.topBowlerLabel}',
            style: TextStyle(fontSize: 11, color: cf.textSecondary),
          ),
        ],
      ],
    );
  }
}
