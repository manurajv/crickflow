import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/tournament/tournament_hero_ranking_engine.dart';
import '../../../../domain/services/tournament/tournament_analytics_models.dart';
import 'widgets/stats_dashboard_widgets.dart';

class TournamentPlayerStatsScreen extends StatelessWidget {
  const TournamentPlayerStatsScreen({
    super.key,
    required this.tournamentId,
    required this.detail,
  });

  final String tournamentId;
  final TournamentPlayerStatsDetail detail;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Scaffold(
      appBar: AppBar(
        title: Text(detail.playerName),
        actions: [
          IconButton(
            tooltip: 'Cricket profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/player/${detail.playerId}/cricket'),
          ),
        ],
      ),
      body: ListView(
        padding: AppDimens.screenPadding,
        children: [
          if (detail.teamName.isNotEmpty)
            Text(
              detail.teamName,
              style: TextStyle(color: cf.textSecondary),
            ),
          const SizedBox(height: AppDimens.spaceMd),
          _SectionTitle(title: 'Batting'),
          StatsMetricGrid(metrics: detail.battingMetrics),
          const SizedBox(height: AppDimens.spaceLg),
          _SectionTitle(title: 'Bowling'),
          StatsMetricGrid(metrics: detail.bowlingMetrics),
          const SizedBox(height: AppDimens.spaceLg),
          _SectionTitle(title: 'Fielding'),
          StatsMetricGrid(metrics: detail.fieldingMetrics),
          if (detail.runsChart.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceLg),
            _SectionTitle(title: 'Runs by match'),
            StatsMiniChart(
              series: StatsChartSeries(
                title: 'Innings runs',
                points: detail.runsChart,
              ),
            ),
          ],
          if (detail.wicketsChart.any((p) => p.value > 0)) ...[
            const SizedBox(height: AppDimens.spaceLg),
            _SectionTitle(title: 'Wickets by match'),
            StatsMiniChart(
              series: StatsChartSeries(
                title: 'Bowling wickets',
                points: detail.wicketsChart,
              ),
            ),
          ],
          if (detail.awards.isNotEmpty) ...[
            const SizedBox(height: AppDimens.spaceLg),
            _SectionTitle(title: 'Awards'),
            ...detail.awards.map(
              (a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.emoji_events, color: cf.accent),
                title: Text(a.award.title),
                trailing: Text(a.valueLabel),
              ),
            ),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          _SectionTitle(title: 'Match-by-match'),
          ...detail.matchLogs.map(
            (log) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cf.border),
              ),
              child: ListTile(
                title: Text(log.opponentLabel),
                subtitle: Text(
                  '${log.runs}${log.balls > 0 ? ' (${log.balls}b)' : ''}'
                  '${log.wickets > 0 ? ' · ${log.wickets} wkts' : ''}'
                  '${log.isNotOut ? ' · not out' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/match/${log.matchId}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
