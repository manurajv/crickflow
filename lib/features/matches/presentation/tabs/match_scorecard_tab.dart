import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../shared/providers/match_summary_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../widgets/match_scorecard_view.dart';
import '../widgets/summary/match_summary_sections.dart';

class MatchScorecardTab extends ConsumerWidget {
  const MatchScorecardTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));
    final summary = ref.watch(matchSummaryProvider(matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) return const Center(child: Text('Not found'));

        final showInsight = match.status == MatchStatus.completed &&
            summary.insight != null;

        if (!showInsight) {
          return MatchScorecardView(match: match);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SummaryInsightCard(insight: summary.insight!),
            Expanded(
              child: MatchScorecardView(match: match),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}
