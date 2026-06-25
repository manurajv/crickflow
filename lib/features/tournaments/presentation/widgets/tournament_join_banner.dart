import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/team_leadership_utils.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_team_request_provider.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../teams/presentation/widgets/team_list_tile.dart';
import '../utils/tournament_join_utils.dart';

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

    final requests =
        ref.watch(tournamentTeamRequestsProvider(tournament.id)).valueOrNull ??
            [];
    final requestByTeamId = TournamentJoinUtils.requestMap(requests);
    final joinedTeams =
        TournamentJoinUtils.joinedTeams(tournament, leadershipTeams);
    final pendingTeams = TournamentJoinUtils.pendingTeams(
      tournament: tournament,
      leadershipTeams: leadershipTeams,
      requestByTeamId: requestByTeamId,
    );
    final actionableTeams = TournamentJoinUtils.actionableJoinTeams(
      tournament: tournament,
      leadershipTeams: leadershipTeams,
      requestByTeamId: requestByTeamId,
    );

    final hasJoined = joinedTeams.isNotEmpty;
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
              hasJoined
                  ? joinedTeams.length == 1
                      ? 'Your team in this tournament'
                      : 'Your teams in this tournament'
                  : 'Join this tournament',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            if (hasJoined) ...[
              ...joinedTeams.map(
                (team) => _JoinedTeamRow(team: team, cf: cf),
              ),
              if (pendingTeams.isNotEmpty) const SizedBox(height: AppDimens.spaceSm),
            ],
            if (pendingTeams.isNotEmpty) ...[
              ...pendingTeams.map(
                (team) => _PendingTeamRow(team: team, cf: cf),
              ),
            ],
            if (!hasJoined && pendingTeams.isEmpty)
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
            if (actionableTeams.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceMd),
              CfButton(
                label: hasJoined ? 'Join another team' : 'Join tournament',
                isGold: true,
                compact: true,
                onPressed: () =>
                    context.push('/tournaments/${tournament.id}/join'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JoinedTeamRow extends StatelessWidget {
  const _JoinedTeamRow({required this.team, required this.cf});

  final TeamModel team;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceSm),
      child: Row(
        children: [
          TeamLogoAvatar(team: team, size: 36),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              team.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cf.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cf.success.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Joined',
              style: TextStyle(
                color: cf.success,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingTeamRow extends StatelessWidget {
  const _PendingTeamRow({required this.team, required this.cf});

  final TeamModel team;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceSm),
      child: Row(
        children: [
          TeamLogoAvatar(team: team, size: 36),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'Pending approval',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
