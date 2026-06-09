import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/deep_link_utils.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/providers/providers.dart';
import 'widgets/match_scorecard_view.dart';

class ScorecardScreen extends ConsumerWidget {
  const ScorecardScreen({
    super.key,
    required this.matchId,
    this.exitToHomeOnBack = false,
  });

  final String matchId;

  /// When true (post-match flow), back navigates to home instead of live scoring.
  final bool exitToHomeOnBack;

  static String routeForMatch(String matchId, {bool fromMatchComplete = false}) {
    if (fromMatchComplete) {
      return '/match/$matchId/scorecard?from=complete';
    }
    return '/match/$matchId/scorecard';
  }

  void _exit(BuildContext context) {
    if (exitToHomeOnBack) {
      context.go('/home');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));

    return PopScope(
      canPop: !exitToHomeOnBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && exitToHomeOnBack && context.mounted) {
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scorecard'),
          leading: exitToHomeOnBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Home',
                  onPressed: () => _exit(context),
                )
              : null,
          automaticallyImplyLeading: !exitToHomeOnBack,
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                matchAsync.whenData((match) {
                  if (match != null) _shareScorecard(match);
                });
              },
            ),
          ],
        ),
        body: matchAsync.when(
          data: (match) {
            if (match == null) return const Center(child: Text('Not found'));
            return MatchScorecardView(match: match);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }

  void _shareScorecard(MatchModel match) {
    final buffer = StringBuffer();
    buffer.writeln('${match.title} — CrickFlow');
    buffer.writeln('${match.teamAName} vs ${match.teamBName}');
    if (match.venue.isNotEmpty) buffer.writeln('Venue: ${match.venue}');
    buffer.writeln();

    for (final inn in match.innings) {
      buffer.writeln(
        'Innings ${inn.inningsNumber}: ${inn.totalRuns}/${inn.totalWickets}',
      );
    }

    if (match.resultSummary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(match.resultSummary);
    }

    buffer.writeln();
    buffer.writeln('Live web: ${DeepLinkUtils.publicLiveScorecardUri(match.id)}');
    buffer.writeln('Open in app: ${DeepLinkUtils.scorecardUri(match.id)}');

    Share.share(buffer.toString());
  }
}
