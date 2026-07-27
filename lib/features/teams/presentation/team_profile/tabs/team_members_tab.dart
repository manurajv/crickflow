import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/player_model.dart';
import '../../../../../data/models/team_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/team_players_provider.dart';
import '../../../../../shared/providers/team_profile_provider.dart';
import '../../../../profile/presentation/widgets/player_follow_button.dart';
import '../../utils/team_squad_utils.dart';
import '../widgets/team_profile_empty_state.dart';

class TeamMembersTab extends ConsumerWidget {
  const TeamMembersTab({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(teamProfileSnapshotProvider(teamId));
    final viewerId = ref.watch(authStateProvider).value?.uid;

    return snapAsync.when(
      loading: () => const TeamProfileSkeleton(),
      error: (e, _) => TeamProfileEmptyState(
        icon: Icons.error_outline,
        title: 'Unable to load members',
        subtitle: '$e',
      ),
      data: (snap) {
        final team = snap.team;
        final players = [...snap.players];
        _sortByRole(players, team);

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(teamPlayersProvider(teamId));
            ref.invalidate(teamByIdProvider(teamId));
          },
          child: players.isEmpty
              ? const TeamProfileEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No members yet',
                  subtitle: 'Invite players to build this squad.',
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppDimens.listPadding,
                  children: [
                    if (team.coachName != null &&
                        team.coachName!.trim().isNotEmpty)
                      _StaffCard(
                        title: team.coachName!.trim(),
                        role: 'Coach',
                      ),
                    for (final p in players)
                      _MemberCard(
                        player: p,
                        team: team,
                        viewerId: viewerId,
                      ),
                  ],
                ),
        );
      },
    );
  }

  void _sortByRole(List<PlayerModel> players, TeamModel team) {
    int roleRank(PlayerModel p) {
      if (TeamSquadUtils.isCaptain(p, team)) return 0;
      if (TeamSquadUtils.isViceCaptain(p, team)) return 1;
      if (TeamSquadUtils.isPlayerOwner(p, team)) return 2;
      return 3;
    }

    players.sort((a, b) {
      final r = roleRank(a).compareTo(roleRank(b));
      if (r != 0) return r;
      return TeamSquadUtils.squadFullName(a)
          .compareTo(TeamSquadUtils.squadFullName(b));
    });
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.title, required this.role});

  final String title;
  final String role;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cf.accent.withValues(alpha: 0.15),
            child: Icon(Icons.badge_outlined, color: cf.accent),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  role,
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

class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.player,
    required this.team,
    required this.viewerId,
  });

  final PlayerModel player;
  final TeamModel team;
  final String? viewerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final name = TeamSquadUtils.squadFullName(player);
    final isCaptain = TeamSquadUtils.isCaptain(player, team);
    final isVc = TeamSquadUtils.isViceCaptain(player, team);
    final roleLabel = [
      if (isCaptain) 'Captain',
      if (isVc) 'Vice Captain',
      if (player.role.isNotEmpty) player.role,
    ].join(' · ');

    final styles = [
      if (player.battingStyle.isNotEmpty) player.battingStyle,
      if (player.bowlingStyle.isNotEmpty) player.bowlingStyle,
    ].join(' · ');

    final canOpen = TeamSquadUtils.canOpenUserProfile(player);
    final profilePath = TeamSquadUtils.userProfilePath(player);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      decoration: cfCardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cf.border,
                  backgroundImage: player.photoUrl != null &&
                          player.photoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(player.photoUrl!)
                      : null,
                  child: player.photoUrl == null || player.photoUrl!.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      if (roleLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          roleLabel,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cf.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                      if (styles.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          styles,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cf.textSecondary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                if (viewerId != null &&
                    player.userId != null &&
                    player.userId!.isNotEmpty &&
                    viewerId != player.userId) ...[
                  Expanded(
                    child: _MemberFollowSlot(
                      userId: player.userId!,
                      viewerId: viewerId!,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: canOpen && profilePath != null
                        ? () => context.push(profilePath)
                        : null,
                    child: const Text('Open Profile'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberFollowSlot extends ConsumerWidget {
  const _MemberFollowSlot({
    required this.userId,
    required this.viewerId,
  });

  final String userId;
  final String viewerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileByIdProvider(userId));
    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const OutlinedButton(
            onPressed: null,
            child: Text('Follow'),
          );
        }
        return PlayerFollowButton(
          followedUser: user,
          followerUserId: viewerId,
          compact: true,
        );
      },
      loading: () => const OutlinedButton(
        onPressed: null,
        child: Text('Follow'),
      ),
      error: (_, _) => const OutlinedButton(
        onPressed: null,
        child: Text('Follow'),
      ),
    );
  }
}
