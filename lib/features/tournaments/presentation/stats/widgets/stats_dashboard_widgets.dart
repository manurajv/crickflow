import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/cricket_math.dart';
import '../../../../../domain/services/tournament/tournament_analytics_models.dart';
import '../../../../../domain/services/tournament/tournament_leaderboard_models.dart';

class StatsMetricGrid extends StatelessWidget {
  const StatsMetricGrid({
    super.key,
    required this.metrics,
    this.crossAxisCount = 2,
    this.maxItems,
  });

  final List<StatsMetric> metrics;
  final int crossAxisCount;
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final items = maxItems != null ? metrics.take(maxItems!).toList() : metrics;
    if (items.isEmpty) {
      return Text(
        'No data yet',
        style: TextStyle(color: cf.textMuted),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 480
                ? crossAxisCount
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _MetricTile(metric: items[i], cf: cf),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.cf});

  final StatsMetric metric;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            metric.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cf.textPrimary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cf.textMuted,
                ),
          ),
          if (metric.subtitle != null && metric.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              metric.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cf.textSecondary,
                    fontSize: 10,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatsLeaderboardPreview extends StatelessWidget {
  const StatsLeaderboardPreview({
    super.key,
    required this.entries,
    this.onPlayerTap,
  });

  final List<TournamentLeaderboardEntry> entries;
  final void Function(TournamentLeaderboardEntry entry)? onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (entries.isEmpty) {
      return Text('No entries yet', style: TextStyle(color: cf.textMuted));
    }

    return Column(
      children: [
        for (final e in entries)
          InkWell(
            onTap: onPlayerTap != null && e.playerId != null
                ? () => onPlayerTap!(e)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${e.rank}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: e.rank <= 3 ? cf.accent : cf.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cf.textPrimary,
                          ),
                        ),
                        if (e.subtitle.isNotEmpty)
                          Text(
                            e.subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: cf.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    e.valueLabel.isNotEmpty ? e.valueLabel : '${e.value}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cf.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class StatsSectionCard extends StatelessWidget {
  const StatsSectionCard({
    super.key,
    required this.sectionId,
    required this.section,
    required this.onViewAll,
    this.onPlayerTap,
    this.trailing,
  });

  final TournamentStatsSectionId sectionId;
  final TournamentSectionSnapshot section;
  final VoidCallback onViewAll;
  final void Function(String playerId)? onPlayerTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final icon = _iconFor(sectionId);
    final hasContent = section.hasContent;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      elevation: 0,
      color: cf.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cf.border),
      ),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cf.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cf.accent, size: 20),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Text(
                    sectionId.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            if (!hasContent)
              Text(
                'No data for this scope yet',
                style: TextStyle(color: cf.textMuted, fontSize: 13),
              )
            else ...[
              if (section.metrics.isNotEmpty)
                StatsMetricGrid(
                  metrics: section.metrics,
                  maxItems: 4,
                ),
              if (section.leaderboardPreview.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceSm),
                StatsLeaderboardPreview(
                  entries: section.leaderboardPreview,
                  onPlayerTap: onPlayerTap == null
                      ? null
                      : (e) {
                          final playerId = e.playerId;
                          if (playerId != null && playerId.isNotEmpty) {
                            onPlayerTap!(playerId);
                          }
                        },
                ),
              ],
              if (section.chartPreview != null) ...[
                const SizedBox(height: AppDimens.spaceSm),
                StatsMiniChart(series: section.chartPreview!),
              ],
            ],
            if (hasContent) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onViewAll,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View all'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(TournamentStatsSectionId id) => switch (id) {
        TournamentStatsSectionId.summary => Icons.dashboard_outlined,
        TournamentStatsSectionId.matchSummary => Icons.sports_cricket,
        TournamentStatsSectionId.batting => Icons.sports_baseball_outlined,
        TournamentStatsSectionId.bowling => Icons.track_changes,
        TournamentStatsSectionId.fielding => Icons.front_hand_outlined,
        TournamentStatsSectionId.team => Icons.groups_outlined,
        TournamentStatsSectionId.boundaries => Icons.looks_4_outlined,
        TournamentStatsSectionId.partnerships => Icons.handshake_outlined,
        TournamentStatsSectionId.extras => Icons.add_circle_outline,
        TournamentStatsSectionId.bowlingTypes => Icons.pie_chart_outline,
        TournamentStatsSectionId.toss => Icons.casino_outlined,
        TournamentStatsSectionId.venue => Icons.place_outlined,
        TournamentStatsSectionId.matchProgress => Icons.timeline_outlined,
        TournamentStatsSectionId.awards => Icons.emoji_events_outlined,
        TournamentStatsSectionId.charts => Icons.bar_chart,
      };
}

class StatsTossBreakdown extends StatelessWidget {
  const StatsTossBreakdown({super.key, required this.insights});

  final TournamentTossInsights insights;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (insights.matchesWithToss <= 0) {
      return Text('No toss data yet', style: TextStyle(color: cf.textMuted));
    }

    return Column(
      children: [
        _TossBreakdownCard(
          cf: cf,
          title: 'Toss winner won match',
          wins: insights.tossWinnerWins,
          total: insights.matchesWithToss,
          pct: insights.tossWinnerWinPct,
          color: cf.accent,
        ),
        const SizedBox(height: 10),
        _TossBreakdownCard(
          cf: cf,
          title: 'Bat first won',
          wins: insights.batFirstWins,
          total: insights.batFirstMatches,
          pct: insights.batFirstWinPct,
          color: CfColors.primaryBlue,
        ),
        const SizedBox(height: 10),
        _TossBreakdownCard(
          cf: cf,
          title: 'Chase won',
          wins: insights.chaseWins,
          total: insights.chaseMatches,
          pct: insights.chaseWinPct,
          color: cf.success,
        ),
      ],
    );
  }
}

class _TossBreakdownCard extends StatelessWidget {
  const _TossBreakdownCard({
    required this.cf,
    required this.title,
    required this.wins,
    required this.total,
    required this.pct,
    required this.color,
  });

  final CfColors cf;
  final String title;
  final int wins;
  final int total;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (wins / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: cf.textPrimary,
                  ),
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$wins of $total matches',
            style: TextStyle(fontSize: 11, color: cf.textSecondary),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: cf.border,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class StatsPartnershipPreview extends StatelessWidget {
  const StatsPartnershipPreview({
    super.key,
    required this.entries,
    this.compact = false,
  });

  final List<TournamentPartnershipEntry> entries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (entries.isEmpty) {
      return Text('No partnerships yet', style: TextStyle(color: cf.textMuted));
    }

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 10),
            child: StatsPartnershipCard(
              entry: entries[i],
              rank: i + 1,
              compact: compact,
            ),
          ),
      ],
    );
  }
}

class StatsPartnershipCard extends StatelessWidget {
  const StatsPartnershipCard({
    super.key,
    required this.entry,
    required this.rank,
    this.compact = false,
  });

  final TournamentPartnershipEntry entry;
  final int rank;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final sr = CricketMath.strikeRate(entry.runs, entry.balls);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? cf.accent.withValues(alpha: 0.15)
                      : cf.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: rank <= 3 ? cf.accent.withValues(alpha: 0.35) : cf.border,
                  ),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: rank <= 3 ? cf.accent : cf.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.runs} runs',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 18 : 20,
                        color: cf.textPrimary,
                      ),
                    ),
                    Text(
                      '${entry.balls} balls · SR ${sr.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 11, color: cf.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.matchLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cf.textSecondary,
            ),
          ),
          if (entry.teamLabel.isNotEmpty)
            Text(
              '${entry.teamLabel} · ${entry.inningsLabel}',
              style: TextStyle(fontSize: 10, color: cf.textMuted),
            ),
          const SizedBox(height: 10),
          _PartnershipBatterRow(
            cf: cf,
            name: entry.batterAName,
            runs: entry.batterARuns,
            balls: entry.batterABalls,
            share: entry.batterAShare,
            color: cf.accent,
          ),
          const SizedBox(height: 8),
          _PartnershipBatterRow(
            cf: cf,
            name: entry.batterBName,
            runs: entry.batterBRuns,
            balls: entry.batterBBalls,
            share: entry.batterBShare,
            color: CfColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}

class _PartnershipBatterRow extends StatelessWidget {
  const _PartnershipBatterRow({
    required this.cf,
    required this.name,
    required this.runs,
    required this.balls,
    required this.share,
    required this.color,
  });

  final CfColors cf;
  final String name;
  final int runs;
  final int balls;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name.isNotEmpty ? name : 'Batter',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: cf.textPrimary,
                ),
              ),
            ),
            Text(
              '$runs($balls)',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: share.clamp(0.05, 1.0),
            minHeight: 5,
            backgroundColor: cf.border,
            color: color,
          ),
        ),
      ],
    );
  }
}

class StatsMiniChart extends StatelessWidget {
  const StatsMiniChart({super.key, required this.series});

  final StatsChartSeries series;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (series.points.isEmpty) return const SizedBox.shrink();
    final max = series.points
        .fold<double>(0, (m, p) => p.value > m ? p.value : m)
        .clamp(1, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          series.title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cf.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final p in series.points.take(8))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: p.value / max,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cf.accent.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9, color: cf.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
