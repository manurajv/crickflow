import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/match_permissions.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/multi_camera_watch_section.dart';
import '../../../../shared/widgets/scoreboard_card.dart';
import '../match_center_screen.dart' show openFantasyForMatch;

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
        final isLive = match.status == MatchStatus.live;
        final isBreak = match.status == MatchStatus.inningsBreak;
        final multiInnings = match.rules.maxInnings > 1;
        final canNext = multiInnings && repo.canStartNextInnings(match);
        final target = match.innings.length >= 2
            ? repo.firstInningsTarget(match)
            : null;
        final canManage = canManageMatch(
          match: match,
          userId: uid,
          role: profile?.role ?? UserRole.organizer,
        );

        return ListView(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceXl),
          children: [
            ScoreboardCard(
              match: match,
              innings: match.currentInnings,
              isLive: isLive,
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
            if (target != null && match.currentInningsIndex >= 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                child: Text(
                  'Target: ${target.target} (${target.runs}/${target.wickets} in 1st inn.)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
              ),
            if (match.location.displayLabel.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.location_on, color: AppColors.gold),
                title: Text(match.location.displayLabel),
                subtitle: Text(match.venue),
              ),
            if (!canManage)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.visibility, color: AppColors.gold),
                    title: Text('Spectator view'),
                    subtitle: Text(
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
                      match.status != MatchStatus.live &&
                      match.status != MatchStatus.completed &&
                      match.status != MatchStatus.inningsBreak)
                    CfButton(
                      label: 'Start Scoring',
                      icon: Icons.play_arrow,
                      onPressed: () => _startMatch(context, ref, match),
                    ),
                  if (canManage && isLive)
                    CfButton(
                      label: multiInnings ? 'End Innings' : 'End Match',
                      icon: Icons.stop_circle_outlined,
                      isOutlined: true,
                      onPressed: () => _endInnings(context, ref, match, multiInnings),
                    ),
                  if (canManage && isBreak && canNext)
                    CfButton(
                      label: 'Start 2nd Innings',
                      icon: Icons.skip_next,
                      isGold: true,
                      onPressed: () => _startNextInnings(context, ref),
                    ),
                  if (canManage &&
                      (isLive ||
                          isBreak ||
                          match.status == MatchStatus.scheduled))
                    CfButton(
                      label: 'Live Score',
                      icon: Icons.scoreboard,
                      isGold: !isBreak,
                      onPressed: () => context.push('/match/$matchId/score'),
                    ),
                  CfButton(
                    label: 'Go Live',
                    icon: Icons.videocam,
                    isOutlined: true,
                    onPressed: canManage
                        ? () => context.push('/match/$matchId/stream')
                        : null,
                  ),
                  if (canManage && (isLive || isBreak))
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
                (inn) => ListTile(
                  title: Text('Innings ${inn.inningsNumber} — ${inn.status.name}'),
                  trailing: Text('${inn.totalRuns}/${inn.totalWickets}'),
                ),
              ),
            ],
            if (match.matchHero != null)
              Card(
                margin: const EdgeInsets.all(AppDimens.spaceMd),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.gold,
                    child: Icon(Icons.star, color: Colors.black),
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
        context.push('/match/$matchId/score');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match completed')),
      );
    }
  }
}
