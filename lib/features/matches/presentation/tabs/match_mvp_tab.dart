import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../domain/services/match_insights_service.dart';
import '../../../../shared/providers/match_insights_provider.dart';

/// Match MVP rankings from ball-by-ball fantasy-style points.
class MatchMvpTab extends ConsumerWidget {
  const MatchMvpTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(matchInsightsProvider(matchId));
    final rankings = insights.mvpRankings;

    return ListView(
      padding: AppDimens.listPadding,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'MVP points',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/fantasy'),
              child: const Text('Fantasy leagues'),
            ),
          ],
        ),
        Text(
          'Live points from this match (runs, wickets, boundaries). Captain multipliers apply in fantasy squads.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (rankings.isEmpty)
          Padding(
            padding: AppDimens.listPadding,
            child: Text(
              'Score balls to build the MVP board.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...List.generate(rankings.length, (i) {
            final p = rankings[i];
            return _MvpRow(rank: i + 1, performer: p);
          }),
      ],
    );
  }
}

class _MvpRow extends StatelessWidget {
  const _MvpRow({required this.rank, required this.performer});

  final int rank;
  final PerformerInsight performer;

  @override
  Widget build(BuildContext context) {
    final isTop = rank <= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceXs),
      color: isTop ? AppColors.primaryBlue.withValues(alpha: 0.12) : null,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: isTop ? AppColors.gold : AppColors.surfaceElevated,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isTop ? Colors.black : AppColors.textPrimary,
            ),
          ),
        ),
        title: Text(performer.playerName),
        subtitle: Text(performer.statLine),
        trailing: Text(
          performer.impactScore.toStringAsFixed(1),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
