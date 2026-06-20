import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/match_summary_models.dart';
import 'insights_chart_widgets.dart';

class InsightsTeamComparisonSection extends StatelessWidget {
  const InsightsTeamComparisonSection({
    super.key,
    required this.comparison,
    required this.cf,
  });

  final TeamComparisonSummary comparison;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (comparison.metrics.isEmpty) {
      return const InsightsEmptyHint(message: 'Team comparison not available yet');
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                comparison.teamAName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cf.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                comparison.teamBName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cf.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        ...comparison.metrics.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ComparisonRow(metric: m, cf: cf),
          ),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({required this.metric, required this.cf});

  final TeamComparisonMetric metric;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final a = metric.teamANumeric;
    final b = metric.teamBNumeric;
    final total = (a ?? 0) + (b ?? 0);
    final aFlex = total > 0 && a != null
        ? (a / total * 100).round().clamp(1, 99)
        : 50;
    final bFlex = 100 - aFlex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: cf.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: aFlex,
              child: Text(
                metric.teamAValue,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cf.accent,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              flex: bFlex,
              child: Text(
                metric.teamBValue,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: CfColors.primaryBlue,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: aFlex,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: cf.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: bFlex,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: CfColors.primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
