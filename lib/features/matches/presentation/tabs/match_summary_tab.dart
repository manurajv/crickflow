import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/match_permissions.dart';
import '../../../../core/utils/match_score_display.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../domain/scoring/innings_completion_policy.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/multi_camera_watch_section.dart';
import '../../../../shared/widgets/scoreboard_card.dart';
import '../match_center_screen.dart' show openFantasyForMatch;
import '../../../../shared/widgets/match_follow_button.dart';
import '../widgets/match_dls_summary_card.dart';
import '../widgets/match_revision_info_panel.dart';
import '../widgets/match_break_history_section.dart';

/// Summary tab — scoreboard, stream, and match actions.
class MatchSummaryTab extends ConsumerWidget {
  const MatchSummaryTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));
    final repo = ref.watch(matchRepositoryProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final uid = ref.watch(authStateProvider).value?.uid;

    return matchAsync.when(
      data: (match) {
        if (match == null) {
          return const Center(child: Text('Match not found'));
        }
        final cf = context.cf;
        final isLive = match.status == MatchStatus.live;
        final isBreak = match.status == MatchStatus.inningsBreak;
        final isCompleted = match.status == MatchStatus.completed;
        final multiInnings = match.rules.maxInnings > 1;
        final canNext = multiInnings && repo.canStartNextInnings(match);
        final canManage = canManageMatch(
          match: match,
          userId: uid,
          role: profile?.role ?? UserRole.organizer,
        );
        final resultLine = MatchScoreDisplay.completedResultLine(match);
        final heroLine = isCompleted &&
                match.resultSummary.isNotEmpty &&
                match.resultSummary != resultLine
            ? match.resultSummary
            : null;

        final revisionsAsync = ref.watch(matchRevisionsProvider(matchId));
        final revisions = revisionsAsync.valueOrNull ?? const [];

        return ListView(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceSm,
                AppDimens.spaceMd,
                0,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: MatchFollowButton(matchId: matchId),
              ),
            ),
            ScoreboardCard(
              match: match,
              innings: match.currentInnings,
              isLive: isLive || isBreak,
            ),
            MatchDlsSummaryCard(match: match),
            MatchRevisionInfoPanel(
              match: match,
              revisions: revisions,
              showTargetInfo: false,
            ),
            MatchBreakHistorySection(match: match),
            if (isCompleted &&
                match.targetState.dlsApplied &&
                resultLine != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                child: Text(
                  'Result generated after DLS revision.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            if (heroLine != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                  vertical: AppDimens.spaceSm,
                ),
                child: Text(
                  heroLine,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (match.stream.status == StreamStatus.live ||
                match.stream.status == StreamStatus.connecting) ...[
              MultiCameraWatchSection(
                primaryUrl: match.stream.youtubeWatchUrl,
                secondaryUrl: match.stream.secondaryYoutubeWatchUrl,
                primaryLabel: match.stream.cameraALabel,
                secondaryLabel: match.stream.cameraBLabel,
              ),
              if (match.stream.webrtcEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                  ),
                  child: CfButton(
                    label: 'Low latency (beta)',
                    icon: Icons.speed,
                    isOutlined: true,
                    onPressed: () => context.push('/match/$matchId/webrtc'),
                  ),
                ),
            ],
            if (match.location.displayLabel.isNotEmpty)
              ListTile(
                leading: Icon(Icons.location_on, color: cf.info),
                title: Text(match.location.displayLabel),
                subtitle: Text(match.venue),
              ),
            if (!canManage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.visibility, color: cf.info),
                    title: const Text('Spectator view'),
                    subtitle: const Text(
                      'Use tabs for scorecard and highlights. Member mode in Profile to score.',
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: Wrap(
                spacing: AppDimens.spaceSm,
                runSpacing: AppDimens.spaceSm,
                children: [
                  if (canManage &&
                      !isCompleted &&
                      match.status != MatchStatus.live &&
                      match.status != MatchStatus.completed &&
                      match.status != MatchStatus.inningsBreak)
                    CfButton(
                      label: match.status == MatchStatus.tossCompleted
                          ? 'Set lineup'
                          : 'Start Scoring',
                      icon: Icons.play_arrow,
                      onPressed: () => _startMatch(context, ref, match),
                    ),
                  if (canManage && isLive && !isCompleted)
                    CfButton(
                      label: multiInnings ? 'End Innings' : 'End Match',
                      icon: Icons.stop_circle_outlined,
                      isOutlined: true,
                      onPressed: () => _endInnings(context, ref, match, multiInnings),
                    ),
                  if (canManage && isBreak && canNext && !isCompleted)
                    CfButton(
                      label: 'Start 2nd Innings',
                      icon: Icons.skip_next,
                      isGold: true,
                      onPressed: () => _startNextInnings(context, ref),
                    ),
                  if (canManage &&
                      !isCompleted &&
                      (isLive ||
                          isBreak ||
                          match.status == MatchStatus.scheduled))
                    CfButton(
                      label: 'Live Score',
                      icon: Icons.scoreboard,
                      isGold: !isBreak,
                      onPressed: () => context.push('/match/$matchId/score'),
                    ),
                  if (canManage && !isCompleted)
                    CfButton(
                      label: 'Go Live',
                      icon: Icons.videocam,
                      isOutlined: true,
                      onPressed: () => context.push('/match/$matchId/stream'),
                    ),
                  if (canManage && (isLive || isBreak) && !isCompleted)
                    CfButton(
                      label: 'Complete Match',
                      icon: Icons.flag,
                      isOutlined: true,
                      onPressed: () => _completeMatch(context, ref),
                    ),
                  CfButton(
                    label: 'Fantasy',
                    icon: Icons.sports_esports,
                    isOutlined: true,
                    onPressed: () =>
                        openFantasyForMatch(context, ref, match, canManage),
                  ),
                ],
              ),
            ),
            if (match.innings.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceLg,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: Text('Innings', style: Theme.of(context).textTheme.titleLarge),
              ),
              ...match.innings.map(
                (inn) {
                  final reason = inn.status == InningsStatus.completed
                      ? InningsCompletionPolicy.endReasonLabel(match, inn)
                      : '';
                  final score = reason.isNotEmpty
                      ? '${inn.totalRuns}/${inn.totalWickets} · $reason'
                      : '${inn.totalRuns}/${inn.totalWickets}';
                  return ListTile(
                    title: Text(
                      'Innings ${inn.inningsNumber} — ${inn.status.name}',
                    ),
                    trailing: Text(score),
                  );
                },
              ),
            ],
            if (match.matchHero != null)
              Card(
                margin: const EdgeInsets.all(AppDimens.spaceMd),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cf.accent,
                    child: Icon(Icons.star, color: cf.onAccent),
                  ),
                  title: Text('Match Hero: ${match.matchHero!.playerName}'),
                  subtitle: Text(match.matchHero!.reason),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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

  Future<void> _endInnings(
    BuildContext context,
    WidgetRef ref,
    MatchModel match,
    bool multiInnings,
  ) async {
    if (!multiInnings) {
      await _completeMatch(context, ref);
      return;
    }
    await ref.read(matchRepositoryProvider).endCurrentInnings(matchId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Innings ended')),
      );
    }
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

  Future<void> _completeMatch(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete match?'),
        content: const Text('Stats will be finalized and badges assigned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final completed =
        await ref.read(matchRepositoryProvider).completeMatch(matchId);
    if (completed != null) {
      await ref
          .read(tournamentRepositoryProvider)
          .advanceKnockoutFromMatch(completed);
    }
    if (context.mounted) {
      context.go('/match/$matchId');
    }
  }
}
