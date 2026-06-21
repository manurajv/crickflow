import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/providers/match_upcoming_provider.dart';
import '../../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/insights/insights_team_comparison_section.dart';

/// Detailed historical comparison between the two teams.
class TeamHeadToHeadScreen extends ConsumerWidget {
  const TeamHeadToHeadScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final upcomingAsync = ref.watch(matchUpcomingProvider(matchId));

    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('Team insights')),
      body: upcomingAsync.when(
        data: (snapshot) {
          final comparison = snapshot.headToHead.comparison;
          if (comparison == null || !snapshot.headToHead.hasHistory) {
            return Center(
              child: Text(
                'No previous meetings',
                style: TextStyle(color: cf.textSecondary),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            children: [
              Text(
                '${comparison.teamAName} vs ${comparison.teamBName}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Container(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                decoration: cfCardDecoration(context),
                child: InsightsTeamComparisonSection(
                  comparison: comparison,
                  cf: cf,
                ),
              ),
              if (snapshot.headToHead.recentMatches.isNotEmpty) ...[
                const SizedBox(height: AppDimens.spaceLg),
                Text(
                  'Recent matches',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cf.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                for (final recent in snapshot.headToHead.recentMatches)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(AppDimens.spaceMd),
                    decoration: cfCardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recent.dateLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: cf.textMuted,
                          ),
                        ),
                        Text(
                          recent.summary,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cf.textPrimary,
                          ),
                        ),
                        Text(
                          'Winner: ${recent.winnerName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: cf.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
