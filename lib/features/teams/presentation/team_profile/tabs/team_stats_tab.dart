import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../domain/services/team_profile/team_profile_models.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/team_players_provider.dart';
import '../../../../../shared/providers/team_profile_provider.dart';
import '../../../../../shared/widgets/stat_grid.dart';
import '../widgets/team_profile_empty_state.dart';

class TeamStatsTab extends ConsumerWidget {
  const TeamStatsTab({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teamProfileFilteredStatsProvider(teamId));

    return statsAsync.when(
      loading: () => const TeamProfileSkeleton(),
      error: (e, _) => TeamProfileEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load stats',
        subtitle: '$e',
      ),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(matchesProvider);
            ref.invalidate(teamByIdProvider(teamId));
            ref.invalidate(teamPlayersProvider(teamId));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppDimens.listPadding,
            children: [
              Text(
                'Team record',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              StatGrid(cells: _recordCells(stats)),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                'Scoring',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              StatGrid(cells: _scoringCells(stats)),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                'Form & venues',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              StatGrid(cells: _formCells(stats)),
            ],
          ),
        );
      },
    );
  }

  List<StatCellData> _recordCells(TeamProfileStats s) => [
        StatCellData(value: '${s.matches}', label: 'Matches'),
        StatCellData(value: '${s.wins}', label: 'Wins'),
        StatCellData(value: '${s.losses}', label: 'Losses'),
        StatCellData(value: '${s.ties}', label: 'Ties'),
        StatCellData(
          value: s.matches == 0 ? '—' : s.winPct.toStringAsFixed(1),
          label: 'Win %',
        ),
        StatCellData(
          value: s.currentStreak == 0
              ? '—'
              : s.currentStreak > 0
                  ? 'W${s.currentStreak}'
                  : 'L${-s.currentStreak}',
          label: 'Current Streak',
        ),
        StatCellData(value: '${s.longestWinStreak}', label: 'Longest Win Streak'),
        StatCellData(value: '${s.tournamentWins}', label: 'Tournament Wins'),
      ];

  List<StatCellData> _scoringCells(TeamProfileStats s) => [
        StatCellData(
          value: !s.hasInningsScores
              ? '—'
              : s.averageScore.toStringAsFixed(1),
          label: 'Average Score',
        ),
        StatCellData(
          value: !s.hasInningsScores ? '—' : '${s.highestScore}',
          label: 'Highest Score',
        ),
        StatCellData(
          value: !s.hasInningsScores ? '—' : '${s.lowestScore}',
          label: 'Lowest Score',
        ),
        StatCellData(
          value: s.highestSuccessfulChase == 0
              ? '—'
              : '${s.highestSuccessfulChase}',
          label: 'Highest Chase',
        ),
        StatCellData(
          value: s.lowestSuccessfulDefence == 0
              ? '—'
              : '${s.lowestSuccessfulDefence}',
          label: 'Lowest Defence',
        ),
        StatCellData(
          value: s.averageRuns == 0 ? '—' : s.averageRuns.toStringAsFixed(1),
          label: 'Avg Runs',
        ),
        StatCellData(
          value:
              s.averageWickets == 0 ? '—' : s.averageWickets.toStringAsFixed(1),
          label: 'Avg Wickets',
        ),
        StatCellData(value: '${s.boundaries}', label: 'Boundaries'),
        StatCellData(value: '${s.sixes}', label: 'Sixes'),
        StatCellData(
          value: s.runRate == 0 ? '—' : s.runRate.toStringAsFixed(2),
          label: 'Run Rate',
        ),
      ];

  List<StatCellData> _formCells(TeamProfileStats s) => [
        StatCellData(value: '${s.homeWins}', label: 'Home Wins'),
        StatCellData(value: '${s.awayWins}', label: 'Away Wins'),
      ];
}
