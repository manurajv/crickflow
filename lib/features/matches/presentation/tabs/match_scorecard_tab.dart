import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';
import '../widgets/match_scorecard_view.dart';

class MatchScorecardTab extends ConsumerWidget {
  const MatchScorecardTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) return const Center(child: Text('Not found'));
        return MatchScorecardView(match: match);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}
