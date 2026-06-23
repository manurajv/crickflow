import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/team_leadership_utils.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';

/// Shown on the tournament dashboard when the viewer can request to join with a team.
class TournamentJoinBanner extends ConsumerWidget {
  const TournamentJoinBanner({
    super.key,
    required this.tournament,
    required this.role,
  });

  final TournamentModel tournament;
  final TournamentRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final canManage = role == TournamentRole.owner ||
        role == TournamentRole.admin ||
        tournament.effectiveOrganizerId == uid;
    if (canManage) return const SizedBox.shrink();

    final teams = ref.watch(allTeamsProvider).valueOrNull;
    if (teams == null) return const SizedBox.shrink();

    final player = ref.watch(myPlayerProvider).valueOrNull;
    final leadershipTeams = TeamLeadershipUtils.leadershipTeams(
      teams: teams,
      uid: uid,
      player: player,
    );

    if (leadershipTeams.isEmpty) return const SizedBox.shrink();

    final cf = context.cf;
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      color: cf.accent.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cf.accent.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join this tournament',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              leadershipTeams.length == 1
                  ? 'Request entry for ${leadershipTeams.first.name}. '
                      'The organizer must approve your team.'
                  : 'You manage ${leadershipTeams.length} teams. '
                      'Choose which team should join this tournament.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            CfButton(
              label: 'Join tournament',
              isGold: true,
              compact: true,
              onPressed: () =>
                  context.push('/tournaments/${tournament.id}/join'),
            ),
          ],
        ),
      ),
    );
  }
}
