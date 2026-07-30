import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/admin_colors.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../models/analytics_models.dart';

class AnalyticsLineChartCard extends StatelessWidget {
  const AnalyticsLineChartCard({
    super.key,
    required this.title,
    required this.points,
    this.height = 240,
    this.color,
  });

  final String title;
  final List<AnalyticsSeriesPoint> points;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final lineColor = color ?? AdminColors.primaryBlue;

    return CfCard(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: points.isEmpty
                  ? Center(
                      child: Text(
                        'No series data in sample window',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: colors.border,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, meta) => Text(
                                v.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: (points.length / 4)
                                  .clamp(1, points.length)
                                  .toDouble(),
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    points[i].label,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < points.length; i++)
                                FlSpot(i.toDouble(), points[i].value),
                            ],
                            isCurved: true,
                            color: lineColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: lineColor.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalyticsBarChartCard extends StatelessWidget {
  const AnalyticsBarChartCard({
    super.key,
    required this.title,
    required this.values,
    this.height = 240,
  });

  final String title;
  final List<AnalyticsNamedValue> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final items = values.take(8).toList();

    return CfCard(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No breakdown data',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: colors.border,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, meta) => Text(
                                v.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= items.length) {
                                  return const SizedBox.shrink();
                                }
                                final label = items[i].name;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    label.length > 8
                                        ? '${label.substring(0, 8)}…'
                                        : label,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < items.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: items[i].value.toDouble(),
                                  color: AdminColors.primaryBlue,
                                  width: 14,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnalyticsNamedListCard extends StatelessWidget {
  const AnalyticsNamedListCard({
    super.key,
    required this.title,
    required this.values,
    this.valueSuffix = '',
  });

  final String title;
  final List<AnalyticsNamedValue> values;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (values.isEmpty)
            Text('No data', style: TextStyle(color: colors.textMuted))
          else
            for (final v in values.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (v.subtitle != null)
                            Text(
                              v.subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${v.value}$valueSuffix',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
