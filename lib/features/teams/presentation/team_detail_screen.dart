import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/cf_team_id_format.dart';
import '../../../core/utils/deep_link_utils.dart';
import '../../../data/models/player_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_players_provider.dart';
import '../../../shared/providers/team_join_request_provider.dart';
import 'utils/team_squad_utils.dart';
import 'widgets/team_detail_banner.dart';
import 'widgets/team_detail_bottom_bar.dart';
import 'widgets/team_join_action_button.dart';
import 'widgets/team_join_requests_panel.dart';
import 'widgets/team_notification_pref_tile.dart';
import 'widgets/team_logo_picker.dart';
import 'widgets/team_qr_view.dart';
import 'widgets/team_squad_empty_state.dart';
import 'widgets/team_squad_player_card.dart';

class TeamDetailScreen extends ConsumerWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(_teamProvider(teamId));
    final playersAsync = ref.watch(teamPlayersProvider(teamId));
    final uid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: teamAsync.when(
          data: (team) => Text(
            (team?.name ?? 'Team').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          loading: () => const Text('TEAM'),
          error: (_, __) => const Text('TEAM'),
        ),
        actions: [
          teamAsync.maybeWhen(
            data: (team) {
              if (team == null || !TeamSquadUtils.isTeamOwner(uid, team)) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Edit team',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/teams/$teamId/edit'),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: teamAsync.when(
        data: (team) {
          if (team == null) {
            return const Center(child: Text('Team not found'));
          }

          return playersAsync.when(
            data: (players) {
              final isOwner = TeamSquadUtils.isTeamOwner(uid, team);
              final canManageRequests =
                  TeamSquadUtils.canManageJoinRequests(uid, team);
              final canManageMembers = canManageRequests;
              final isMember = uid != null &&
                  (players.any((p) => p.userId == uid || p.id == uid) ||
                      TeamSquadUtils.isTeamOwner(uid, team));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TeamDetailBanner(team: team, squadCount: players.length),
                  if (canManageRequests && uid != null)
                    TeamJoinRequestsPanel(team: team, resolverUid: uid),
                  if (isMember) TeamNotificationPrefTile(teamId: team.id),
                  const TeamSquadBannersStrip(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(_teamProvider(teamId));
                        ref.invalidate(teamPlayersProvider(teamId));
                      },
                      child: players.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                TeamSquadEmptyState(
                                  showAddButton: isOwner,
                                  onAddPlayers: () => context.push(
                                    '/teams/$teamId/add-players',
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(
                                top: AppDimens.spaceSm,
                                bottom: AppDimens.spaceXl,
                              ),
                              itemCount: players.length,
                              itemBuilder: (context, index) {
                                final squadPlayer = players[index];
                                return TeamSquadPlayerCard(
                                  player: squadPlayer,
                                  team: team,
                                  isOwnerViewer: canManageMembers,
                                  actorUid: uid,
                                  onOwnerMenu: canManageMembers
                                      ? (p, action) => _handleMemberMenu(
                                          context,
                                          ref,
                                          team,
                                          p,
                                          action,
                                          players,
                                          uid,
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      bottomNavigationBar: teamAsync.maybeWhen(
        data: (team) {
          if (team == null) return null;
          final players = playersAsync.valueOrNull ?? [];
          return _TeamDetailBottomBar(
            team: team,
            players: players,
            onProfile: () {
              final isOwner = TeamSquadUtils.isTeamOwner(uid, team);
              _showTeamProfile(context, ref, team, isOwner);
            },
            onLeave: (currentPlayer, isOwner) => _confirmLeaveTeam(
              context,
              ref,
              team,
              currentPlayer,
              players,
              isOwner,
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }

  Future<void> _handleMemberMenu(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
    PlayerModel player,
    String action,
    List<PlayerModel> squad,
    String? actorUid,
  ) async {
    final repo = ref.read(teamRepositoryProvider);
    final playerRepo = ref.read(playerRepositoryProvider);
    final isOwner = TeamSquadUtils.isTeamOwner(actorUid, team);

    try {
      switch (action) {
        case 'make_captain':
          if (!isOwner) return;
          await repo.updateCaptainRoles(teamId: team.id, captainId: player.id);
        case 'make_vice_captain':
          if (!isOwner) return;
          await repo.updateCaptainRoles(
            teamId: team.id,
            viceCaptainId: player.id,
          );
        case 'remove_captain':
          if (!isOwner) return;
          await repo.updateCaptainRoles(teamId: team.id, clearCaptain: true);
        case 'remove_vice_captain':
          if (!isOwner) return;
          await repo.updateCaptainRoles(
            teamId: team.id,
            clearViceCaptain: true,
          );
        case 'remove_player':
          if (!TeamSquadUtils.canRemoveMember(
            actorUid: actorUid,
            team: team,
            target: player,
            squad: squad,
          )) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You cannot remove this member')),
              );
            }
            return;
          }
          final displayName = TeamSquadUtils.squadFullName(player);
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Remove player?'),
              content: Text('Remove $displayName from ${team.name}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentRed,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await playerRepo.removePlayerFromTeamByOwner(
            teamId: team.id,
            playerId: player.id,
            teamName: team.name,
          );
      }
      ref.invalidate(_teamProvider(teamId));
      ref.invalidate(teamPlayersProvider(teamId));
      ref.invalidate(allTeamsProvider);
      ref.invalidate(teamPendingJoinRequestsProvider(teamId));
    } catch (e, st) {
      debugPrint('team squad action failed: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'remove_player'
                  ? 'Unable to remove player. Please try again.'
                  : 'Something went wrong. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmLeaveTeam(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
    PlayerModel player,
    List<PlayerModel> squad,
    bool isOwner,
  ) async {
    final isSoleMember = squad.length <= 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave team?'),
        content: Text(
          isOwner && isSoleMember
              ? 'You are the only member. Leaving will permanently delete ${team.name} and all pending join requests.'
              : isOwner
                  ? 'You are the team owner. Ownership will transfer to the longest-standing member before you leave.'
                  : 'You will be removed from ${team.name}. You can send a join request again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentRed),
            child: const Text('Confirm leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final teamDeleted = await ref
          .read(playerRepositoryProvider)
          .leaveTeam(teamId: team.id, leavingPlayer: player, squad: squad);
      ref.invalidate(_teamProvider(teamId));
      ref.invalidate(teamPlayersProvider(teamId));
      ref.invalidate(allTeamsProvider);
      ref.invalidate(teamPendingJoinRequestsProvider(teamId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              teamDeleted
                  ? '${team.name} was deleted'
                  : 'You left ${team.name}',
            ),
          ),
        );
        context.pop();
      }
    } catch (e, st) {
      debugPrint('leaveTeam failed: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to leave team. Please try again.'),
          ),
        );
      }
    }
  }

  void _showTeamProfile(
    BuildContext context,
    WidgetRef ref,
    TeamModel team,
    bool isOwner,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TeamLogoPicker(
                  logoUrl: team.profileImageUrl,
                  teamName: team.name,
                  size: 96,
                  onTap: isOwner
                      ? () {
                          Navigator.pop(ctx);
                          context.push('/teams/$teamId/edit');
                        }
                      : null,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                team.name,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.headlineMedium,
              ),
              if (team.teamCode != null && team.teamCode!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  CfTeamIdFormat.displayLabel(team.teamCode),
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              Text(
                team.location.displayLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              TeamQrView(team: team),
              const SizedBox(height: AppDimens.spaceLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(ctx, 'Played', '${team.stats.matchesPlayed}'),
                  _stat(ctx, 'Won', '${team.stats.matchesWon}'),
                  _stat(ctx, 'Points', '${team.stats.points}'),
                ],
              ),
              const SizedBox(height: AppDimens.spaceLg),
              OutlinedButton.icon(
                onPressed: () {
                  final link = DeepLinkUtils.httpsTeamUri(team.id).toString();
                  Share.share('Join ${team.name} on CrickFlow.\n$link');
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share team invite'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.gold,
          ),
        ),
        Text(label),
      ],
    );
  }
}

final _teamProvider = StreamProvider.family<TeamModel?, String>((ref, teamId) {
  return ref.watch(teamRepositoryProvider).watchTeam(teamId);
});

class _TeamDetailBottomBar extends ConsumerWidget {
  const _TeamDetailBottomBar({
    required this.team,
    required this.players,
    required this.onProfile,
    required this.onLeave,
  });

  final TeamModel team;
  final List<PlayerModel> players;
  final VoidCallback onProfile;
  final void Function(PlayerModel player, bool isOwner) onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();

    final onSquad = TeamSquadUtils.isOnSquad(uid, team, players);
    final currentPlayer = TeamSquadUtils.currentSquadPlayer(uid, players);
    final isOwner = TeamSquadUtils.isTeamOwner(uid, team);
    final pendingRequest = ref
        .watch(userTeamJoinRequestProvider((teamId: team.id, userId: uid)))
        .valueOrNull
        ?.isPending;

    String? secondaryLabel;
    VoidCallback? onSecondary;
    var secondaryEnabled = true;
    var secondaryIsGold = false;

    if (onSquad) {
      secondaryLabel = 'Leave team';
      onSecondary = () async {
        var leaving = currentPlayer;
        leaving ??= await ref.read(playerRepositoryProvider).getPlayer(uid);
        if (leaving == null) return;
        onLeave(leaving, isOwner);
      };
    } else if (!isOwner) {
      if (pendingRequest == true) {
        secondaryLabel = 'Requested';
        secondaryEnabled = false;
      } else {
        secondaryLabel = 'Join team';
        secondaryIsGold = true;
        onSecondary = () => sendTeamJoinRequest(
          ref: ref,
          context: context,
          team: team,
        );
      }
    }

    return TeamDetailBottomBar(
      onProfile: onProfile,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      secondaryEnabled: secondaryEnabled,
      secondaryIsGold: secondaryIsGold,
    );
  }
}
