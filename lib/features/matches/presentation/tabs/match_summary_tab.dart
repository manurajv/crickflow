import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/match_permissions.dart';
import '../../../../data/models/innings_model.dart';
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
  final void Function(int tabIndex)? onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));
    final summary = ref.watch(matchSummaryProvider(matchId));

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return const Center(child: Text('Match not found'));
        }

        if (!summary.hasData && !summary.isLive) {
          return _PreMatchBody(matchId: matchId, match: match);
        }

        return _SummaryBody(
          matchId: matchId,
          match: match,
          summary: summary,
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
    this.onNavigateTab,
  });

  final String matchId;
  final MatchModel match;
  final MatchSummarySnapshot summary;
  final void Function(int tabIndex)? onNavigateTab;

  void _goTab(BuildContext context, String tab) {
    context.go('/match/$matchId?tab=$tab');
  }

  void _tabOrGo(BuildContext context, int index, String tabName) {
    if (onNavigateTab != null) {
      onNavigateTab!(index);
    } else {
      _goTab(context, tabName);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final uid = ref.watch(authStateProvider).value?.uid;
    final repo = ref.watch(matchRepositoryProvider);
    final canManage = canManageMatch(
      match: match,
      userId: uid,
      role: profile?.role ?? UserRole.organizer,
    );
    final isLive = match.status == MatchStatus.live;
    final isBreak = match.status == MatchStatus.inningsBreak;
    final isCompleted = match.status == MatchStatus.completed;
    final multiInnings = match.rules.maxInnings > 1;
    final canNext = multiInnings && repo.canStartNextInnings(match);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
      children: [
        if (summary.insight != null)
          SummaryInsightCard(insight: summary.insight!),
        if (summary.result != null)
          SummaryResultCard(
            match: match,
            result: summary.result!,
            isLive: summary.isLive,
          ),
        SummaryHeroesSection(heroes: summary.heroes),
        SummaryStarPerformersSection(
          batters: summary.starBatters,
          bowlers: summary.starBowlers,
          fielders: summary.starFielders,
          allRounders: summary.starAllRounders,
        ),
        SummaryAwardsSection(awards: summary.awards),
        SummaryQuickActions(
          matchId: matchId,
          onTab: (index) => _tabOrGo(
            context,
            index,
            switch (index) {
              1 => 'scorecard',
              2 => 'comms',
              3 => 'insights',
              5 => 'mvp',
              _ => 'summary',
            },
          ),
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
          canManage: canManage,
          isCompleted: isCompleted,
          isLive: isLive,
          isBreak: isBreak,
          canNext: canNext,
          onStart: () => _startMatch(context, ref, match),
          onNextInnings: () => _startNextInnings(context, ref),
        ),
      ],
    );
  }

  Future<void> _startMatch(
    BuildContext context,
    WidgetRef ref,
    MatchModel match,
  ) async {
    if (match.status == MatchStatus.tossCompleted) {
      if (context.mounted) context.push('/match/$matchId/start-innings');
      return;
    }
    final uid = ref.read(authStateProvider).value?.uid;
    final firstInnings = InningsModel(
      inningsNumber: 1,
      battingTeamId: match.teamAId ?? 'team_a',
      bowlingTeamId: match.teamBId ?? 'team_b',
      status: InningsStatus.inProgress,
    );
    await ref.read(matchRepositoryProvider).startMatch(
          matchId,
          firstInnings,
          scorerId: uid,
        );
    if (context.mounted) context.push('/match/$matchId/score');
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
          onTab: (index) => context.go(
            '/match/$matchId?tab=${switch (index) {
              1 => 'scorecard',
              2 => 'comms',
              3 => 'insights',
              5 => 'mvp',
              _ => 'summary',
            }}',
          ),
        ),
      ],
    );
  }
}
