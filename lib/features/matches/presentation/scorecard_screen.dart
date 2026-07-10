import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:share_plus/share_plus.dart';



import '../../../core/utils/deep_link_utils.dart';

import '../../../core/utils/overs_formatter.dart';

import '../../../data/models/match_model.dart';

import '../../../data/models/match_revision_model.dart';

import '../../../domain/display/match_revision_display.dart';

import '../../../domain/scoring/innings_completion_policy.dart';

import '../../../domain/streaming/match_stream_playback.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/match_follow_button.dart';
import '../../../shared/widgets/match_stream_watch_section.dart';
import '../../../shared/widgets/stream_live_toggle_action.dart';
import 'widgets/match_scorecard_view.dart';



class ScorecardScreen extends ConsumerStatefulWidget {

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

  @override
  ConsumerState<ScorecardScreen> createState() => _ScorecardScreenState();
}

class _ScorecardScreenState extends ConsumerState<ScorecardScreen> {
  bool? _streamVisibleOverride;

  String get matchId => widget.matchId;
  bool get exitToHomeOnBack => widget.exitToHomeOnBack;

  bool _isStreamVisible(MatchModel match) {
    if (_streamVisibleOverride != null) return _streamVisibleOverride!;
    return MatchStreamPlayback.shouldShowStreamByDefault(match);
  }

  void _exit(BuildContext context) {

    if (exitToHomeOnBack) {

      context.go('/home');

    } else {

      context.pop();

    }

  }



  @override

  Widget build(BuildContext context) {
    final ref = this.ref;

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
            MatchFollowButton(matchId: matchId, compact: true),
            matchAsync.when(
              data: (match) {
                if (match == null ||
                    !MatchStreamPlayback.hasWatchablePlayback(match)) {
                  return const SizedBox.shrink();
                }
                return StreamLiveToggleAction(
                  visible: _isStreamVisible(match),
                  onToggle: () => setState(
                    () => _streamVisibleOverride = !_isStreamVisible(match),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            IconButton(

              icon: const Icon(Icons.share),

              onPressed: () async {

                final match = matchAsync.valueOrNull;

                if (match == null) return;

                final revisions = await ref

                    .read(matchTargetRevisionRepositoryProvider)

                    .fetchMatchRevisions(matchId);

                if (context.mounted) {

                  _shareScorecard(match, revisions);

                }

              },

            ),

          ],

        ),

        body: matchAsync.when(

          data: (match) {

            if (match == null) return const Center(child: Text('Not found'));

            final showStream = _isStreamVisible(match);
            final hasStream = MatchStreamPlayback.hasWatchablePlayback(match);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasStream && showStream)
                  MatchStreamWatchSection(
                    match: match,
                    edgeToEdge: true,
                  ),
                Expanded(
                  child: MatchScorecardView(match: match),
                ),
              ],
            );

          },

          loading: () => const Center(child: CircularProgressIndicator()),

          error: (e, _) => Center(child: Text('$e')),

        ),

      ),

    );

  }



  void _shareScorecard(MatchModel match, List<MatchRevisionModel> revisions) {

    final buffer = StringBuffer();

    buffer.writeln('${match.title} — CrickFlow');

    buffer.writeln('${match.teamAName} vs ${match.teamBName}');

    if (match.venue.isNotEmpty) buffer.writeln('Venue: ${match.venue}');

    buffer.writeln();



    for (final inn in match.innings) {

      final rules = InningsCompletionPolicy.effectiveRules(match, inn);

      final overs = OversFormatter.formatOvers(

        inn.legalBalls,

        rules.ballsPerOver,

      );

      buffer.writeln(

        'Innings ${inn.inningsNumber}: '

        '${InningsCompletionPolicy.scoreLineWithReason(match, inn, overs: overs)}',

      );

    }



    final revisionExport = MatchRevisionDisplay.buildExportSection(

      match,

      revisions,

    );

    if (revisionExport.isNotEmpty) {

      buffer.writeln();

      buffer.writeln(revisionExport);

    }



    if (match.resultSummary.isNotEmpty) {

      buffer.writeln();

      buffer.writeln('Match Result');

      final result = MatchRevisionDisplay.completedResultWithDlsNote(

        match,

        match.resultSummary,

      );

      buffer.writeln(result ?? match.resultSummary);

    }



    buffer.writeln();

    buffer.writeln('Live web: ${DeepLinkUtils.publicLiveScorecardUri(match.id)}');

    buffer.writeln('Open in app: ${DeepLinkUtils.scorecardUri(match.id)}');



    Share.share(buffer.toString());

  }

}


