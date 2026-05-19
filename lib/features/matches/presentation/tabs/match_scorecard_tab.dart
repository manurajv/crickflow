import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/cricket_math.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/scoreboard_card.dart';

class MatchScorecardTab extends ConsumerWidget {
  const MatchScorecardTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) return const Center(child: Text('Not found'));
        final rules = match.rules;

        return ListView(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
          children: [
            ScoreboardCard(match: match, innings: match.currentInnings),
            ...match.innings.map((inn) {
              return Card(
                child: Padding(
                  padding: AppDimens.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Innings ${inn.inningsNumber}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${inn.totalRuns}/${inn.totalWickets} (${CricketMath.formatOvers(inn.legalBalls, rules.ballsPerOver)} ov)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.gold,
                            ),
                      ),
                      const Divider(),
                      Text('Batting', style: Theme.of(context).textTheme.titleMedium),
                      ...inn.batsmen.map(
                        (b) => ListTile(
                          dense: true,
                          title: Text(
                            b.playerName.isNotEmpty ? b.playerName : b.playerId,
                          ),
                          trailing: Text('${b.runs} (${b.balls})'),
                        ),
                      ),
                      Text('Bowling', style: Theme.of(context).textTheme.titleMedium),
                      ...inn.bowlers.map(
                        (b) => ListTile(
                          dense: true,
                          title: Text(
                            b.playerName.isNotEmpty ? b.playerName : b.playerId,
                          ),
                          trailing: Text(
                            '${CricketMath.formatOvers(b.oversBowledBalls, rules.ballsPerOver)}-${b.runsConceded}-${b.wickets}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (match.resultSummary.isNotEmpty)
              Padding(
                padding: AppDimens.listPadding,
                child: Text(
                  match.resultSummary,
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}
