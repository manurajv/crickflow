import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';

import '../../../../core/theme/cf_colors.dart';

import '../../../../domain/scoring/match_lifecycle.dart';

import '../../../../shared/providers/match_live_provider.dart';

import '../../../../shared/providers/providers.dart';

import '../widgets/live/match_live_sections.dart';



/// Real-time match experience while scoring is in progress.

class MatchLiveTab extends ConsumerStatefulWidget {

  const MatchLiveTab({super.key, required this.matchId});



  final String matchId;



  @override

  ConsumerState<MatchLiveTab> createState() => _MatchLiveTabState();

}



class _MatchLiveTabState extends ConsumerState<MatchLiveTab>

    with AutomaticKeepAliveClientMixin {

  @override

  bool get wantKeepAlive => true;



  @override

  Widget build(BuildContext context) {

    super.build(context);



    final matchAsync = ref.watch(matchProvider(widget.matchId));

    final live = ref.watch(matchLiveProvider(widget.matchId));



    return matchAsync.when(

      data: (match) {

        if (match == null) {

          return const Center(child: Text('Match not found'));

        }



        final isLive = MatchLifecycle.isActivelyLive(match);

        if (!isLive) {

          return Center(

            child: Text(

              'Live updates appear once the match starts.',

              style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                    color: context.cf.textSecondary,

                  ),

            ),

          );

        }



        if (!live.hasData) {

          return Center(

            child: Text(

              live.isInningsBreak

                  ? 'Innings break — waiting for the next innings.'

                  : 'Waiting for the first ball…',

              style: Theme.of(context).textTheme.bodyMedium?.copyWith(

                    color: context.cf.textSecondary,

                  ),

            ),

          );

        }



        return ListView(

          padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),

          children: [

            LiveScoreHeader(

              snapshot: live,

              powerplayLabel: live.powerplayLabel,

            ),

            LivePlayersStatsCard(

              snapshot: live,

              onMore: () => context.go('/match/${widget.matchId}?tab=scorecard'),

            ),

            if (live.insightBanner != null)

              LiveInsightBanner(text: live.insightBanner!),

            if (live.targetRevision != null)

              LiveTargetRevisionCard(info: live.targetRevision!),

            LiveMilestonesSection(milestones: live.milestones),

            LiveCommentarySection(

              overSummary: live.overSummary,

              recentBalls: live.recentCommentary,

              contextLine: live.contextLine,

            ),

          ],

        );

      },

      loading: () => const Center(child: CircularProgressIndicator()),

      error: (e, _) => Center(child: Text('Error: $e')),

    );

  }

}


