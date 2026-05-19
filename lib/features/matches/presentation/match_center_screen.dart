import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../data/models/innings_model.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/scoreboard_card.dart';

class MatchCenterScreen extends ConsumerWidget {
  const MatchCenterScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchProvider(matchId));
    final repo = ref.watch(matchRepositoryProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: () => context.push('/match/$matchId/scorecard'),
          ),
        ],
      ),
      body: matchAsync.when(
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
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ScoreboardCard(
                match: match,
                innings: match.currentInnings,
                isLive: isLive,
              ),
              if (target != null && match.currentInningsIndex >= 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Target: ${target.target} (${target.runs}/${target.wickets} in 1st inn.)',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
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
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: Icon(Icons.visibility, color: AppColors.gold),
                      title: Text('Spectator view'),
                      subtitle: Text(
                        'Scorecard and live overlay only. Sign in as Scorer/Organizer to manage.',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (!canManage)
                      CfButton(
                        label: 'View scorecard',
                        icon: Icons.table_chart,
                        isGold: true,
                        onPressed: () =>
                            context.push('/match/$matchId/scorecard'),
                      ),
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
                      label: 'Overlay',
                      icon: Icons.layers,
                      isOutlined: true,
                      onPressed: () => context.push('/match/$matchId/overlay'),
                    ),
                    if (canManage)
                      CfButton(
                        label: 'Go Live',
                        icon: Icons.videocam,
                        isOutlined: true,
                        onPressed: () => context.push('/match/$matchId/stream'),
                      ),
                    if (canManage && (isLive || isBreak))
                      CfButton(
                        label: 'Complete Match',
                        icon: Icons.flag,
                        isOutlined: true,
                        onPressed: () => _completeMatch(context, ref),
                      ),
                  ],
                ),
              ),
              if (match.innings.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Innings',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                ...match.innings.map(
                  (inn) => ListTile(
                    title: Text('Innings ${inn.inningsNumber} — ${inn.status.name}'),
                    trailing: Text('${inn.totalRuns}/${inn.totalWickets}'),
                  ),
                ),
              ],
              if (match.matchHero != null) ...[
                const SizedBox(height: 24),
                _heroCard(match.matchHero!.playerName, match.matchHero!.reason),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _startMatch(
    BuildContext context,
    WidgetRef ref,
    MatchModel match,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    final battingId = match.teamAId ?? 'team_a';
    final bowlingId = match.teamBId ?? 'team_b';
    final firstInnings = InningsModel(
      inningsNumber: 1,
      battingTeamId: battingId,
      bowlingTeamId: bowlingId,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('2nd innings started')),
        );
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

  Widget _heroCard(String name, String reason) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.gold,
          child: Icon(Icons.star, color: Colors.black),
        ),
        title: Text('Match Hero: $name'),
        subtitle: Text(reason),
      ),
    );
  }
}
