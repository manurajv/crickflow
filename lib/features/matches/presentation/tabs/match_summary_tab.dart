import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/providers/tournament_match_scoring_providers.dart';
import '../../../../core/utils/match_card_navigation.dart';
import '../../../../data/models/match_model.dart';
import '../../../../domain/services/match_summary_models.dart';
import '../../../../shared/providers/match_summary_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/multi_camera_watch_section.dart';
import '../widgets/match_break_history_section.dart';
import '../widgets/summary/match_summary_sections.dart';

/// Broadcast-style match summary — result, insights, heroes, and quick actions.
class MatchSummaryTab extends ConsumerWidget {
  const MatchSummaryTab({
    super.key,
    required this.matchId,
    this.onNavigateTab,
  });

  final String matchId;
  final void Function(String tabName)? onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));
    final summary = ref.watch(matchSummaryProvider(matchId));
    final ballEventsAsync = ref.watch(ballEventsProvider(matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return const Center(child: Text('Match not found'));
        }

        if (!summary.hasData && !summary.isLive) {
          return _PreMatchBody(matchId: matchId, match: match);
        }

        final awaitingBallData = match.status == MatchStatus.completed &&
            ballEventsAsync.isLoading &&
            summary.heroes.isEmpty &&
            summary.insight == null;

        return _SummaryBody(
          matchId: matchId,
          match: match,
          summary: summary,
          awaitingBallData: awaitingBallData,
          onNavigateTab: onNavigateTab,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _SummaryBody extends ConsumerWidget {
  const _SummaryBody({
    required this.matchId,
    required this.match,
    required this.summary,
    this.awaitingBallData = false,
    this.onNavigateTab,
  });

  final String matchId;
  final MatchModel match;
  final MatchSummarySnapshot summary;
  final bool awaitingBallData;
  final void Function(String tabName)? onNavigateTab;

  void _goTab(BuildContext context, String tab) {
    context.go('/match/$matchId?tab=$tab');
  }

  void _tabOrGo(BuildContext context, String tabName) {
    if (onNavigateTab != null) {
      onNavigateTab!(tabName);
    } else {
      _goTab(context, tabName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final repo = ref.watch(matchRepositoryProvider);
    final access = ref.watch(
      tournamentMatchScoringAccessProvider((matchId: matchId, userId: uid)),
    );
    final isLive = match.status == MatchStatus.live;
    final isBreak = match.status == MatchStatus.inningsBreak;
    final isCompleted = match.status == MatchStatus.completed;
    final multiInnings = match.rules.maxInnings > 1;
    final canNext = multiInnings && repo.canStartNextInnings(match);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
      children: [
        if (summary.result != null)
          SummaryResultCard(
            match: match,
            result: summary.result!,
            isLive: summary.isLive,
          ),
        if (awaitingBallData)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.spaceLg),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (summary.insight != null)
            SummaryInsightCard(insight: summary.insight!),
          SummaryHeroesSection(heroes: summary.heroes),
          SummaryStarPerformersSection(
            batters: summary.starBatters,
            bowlers: summary.starBowlers,
            fielders: summary.starFielders,
            allRounders: summary.starAllRounders,
          ),
          SummaryAwardsSection(awards: summary.awards),
        ],
        SummaryQuickActions(
          matchId: matchId,
          matchTitle: match.title,
          onTab: (tabName) => _tabOrGo(context, tabName),
        ),
        MatchBreakHistorySection(match: match),
        if (match.stream.status == StreamStatus.live ||
            match.stream.status == StreamStatus.connecting)
          MultiCameraWatchSection(
            primaryUrl: match.stream.youtubeWatchUrl,
            secondaryUrl: match.stream.secondaryYoutubeWatchUrl,
            primaryLabel: match.stream.cameraALabel,
            secondaryLabel: match.stream.cameraBLabel,
          ),
        SummaryManageActions(
          canStartSetup: access.canStartSetup,
          canManageLive: access.canScoreLive,
          isCompleted: isCompleted,
          isLive: isLive,
          isBreak: isBreak,
          canNext: canNext,
          onStart: () => _startMatch(context, ref, match, access.forceSetupStep),
          onNextInnings: () => _startNextInnings(context, ref),
        ),
      ],
    );
  }

  Future<void> _startMatch(
    BuildContext context,
    WidgetRef ref,
    MatchModel match,
    bool forceSetupStep,
  ) async {
    await openMatchScoring(
      context,
      ref: ref,
      match: match,
      forceSetupStep: forceSetupStep,
    );
  }

  Future<void> _startNextInnings(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(matchRepositoryProvider).startNextInnings(matchId);
      if (context.mounted) {
        context.push('/match/$matchId/start-innings');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _PreMatchBody extends ConsumerWidget {
  const _PreMatchBody({
    required this.matchId,
    required this.match,
  });

  final String matchId;
  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(matchSummaryProvider(matchId));
    final cf = context.cf;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
      children: [
        if (summary.result != null)
          SummaryResultCard(
            match: match,
            result: summary.result!,
            isLive: false,
          ),
        Padding(
          padding: AppDimens.listPadding,
          child: Text(
            'Summary fills in once scoring starts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cf.textSecondary),
          ),
        ),
        SummaryQuickActions(
          matchId: matchId,
          matchTitle: match.title,
          onTab: (tabName) => context.go('/match/$matchId?tab=$tabName'),
        ),
      ],
    );
  }
}
