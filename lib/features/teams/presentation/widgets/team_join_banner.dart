import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/team_players_provider.dart';
import '../../../../shared/widgets/cf_button.dart';

/// Lets a logged-in player join this team from an invite deep link.
class TeamJoinBanner extends ConsumerWidget {
  const TeamJoinBanner({
    super.key,
    required this.team,
    required this.teamId,
    required this.squad,
  });

  final TeamModel team;
  final String teamId;
  final List<PlayerModel> squad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    if (uid == null) return const SizedBox.shrink();

    final alreadyOnSquad = squad.any((p) => p.id == uid || p.userId == uid) ||
        team.playerIds.contains(uid);
    if (alreadyOnSquad) return const SizedBox.shrink();

    final isViewer = profile?.role == UserRole.viewer;
    if (isViewer) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.primaryBlue.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join ${team.name}?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Link your player profile to this team roster.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            CfButton(
              label: 'Join team',
              icon: Icons.group_add,
              isGold: true,
              onPressed: () => _join(context, ref, uid, profile?.displayName ?? 'Player'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _join(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String displayName,
  ) async {
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      final player = await ref.read(playerRepositoryProvider).ensurePlayerProfileForUser(
            userId: uid,
            displayName: displayName,
            photoUrl: profile?.photoUrl,
            email: profile?.email,
          );
      await ref.read(playerRepositoryProvider).assignPlayerToTeam(
            playerId: player.id,
            teamId: teamId,
          );
      ref.invalidate(teamPlayersProvider(teamId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You joined ${team.name}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not join: $e')),
        );
      }
    }
  }
}
