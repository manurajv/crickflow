import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../../shared/providers/team_players_provider.dart';
import '../../../../shared/widgets/player_cluster_text.dart';
import '../utils/team_squad_utils.dart';

class TeamSquadPlayerCard extends ConsumerWidget {
  const TeamSquadPlayerCard({
    super.key,
    required this.player,
    required this.team,
    required this.isOwnerViewer,
    this.actorUid,
    this.onOwnerMenu,
  });

  final PlayerModel player;
  final TeamModel team;
  final bool isOwnerViewer;
  final String? actorUid;
  final void Function(PlayerModel player, String action)? onOwnerMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final fullNameAsync = ref.watch(playerSquadFullNameProvider(player));
    final fullName = fullNameAsync.valueOrNull ?? TeamSquadUtils.squadFullName(player);
    final clustersAsync = ref.watch(playerCricketProfileByIdProvider(player.id));
    final clusters = clustersAsync.valueOrNull?.clusters ?? const PlayerClusters();
    final isOwner = TeamSquadUtils.isPlayerOwner(player, team);
    final isCaptain = TeamSquadUtils.isCaptain(player, team);
    final isVc = TeamSquadUtils.isViceCaptain(player, team);
    final playerId = TeamSquadUtils.playerIdDisplay(player.playerId);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 5,
      ),
      decoration: cfCardDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/players/${player.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlayerAvatar(
                  player: player,
                  displayName: fullName,
                  isOwner: isOwner,
                  isCaptain: isCaptain,
                  isViceCaptain: isVc,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (playerId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _CopyablePlayerId(playerId: playerId),
                      ],
                      clustersAsync.when(
                        data: (_) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: PlayerClusterText(
                            clusters: clusters,
                            showNewPlayerForMissing: true,
                            fontSize: 11,
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (e, st) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: PlayerClusterText(
                            clusters: const PlayerClusters(),
                            showNewPlayerForMissing: true,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwnerViewer && onOwnerMenu != null)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: cf.textSecondary,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (value) => onOwnerMenu!(player, value),
                    itemBuilder: (ctx) =>
                        _memberMenuItems(player, team, actorUid),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _memberMenuItems(
    PlayerModel player,
    TeamModel team,
    String? actorUid,
  ) {
    final isCaptain = TeamSquadUtils.isCaptain(player, team);
    final isVc = TeamSquadUtils.isViceCaptain(player, team);
    final actorIsOwner = TeamSquadUtils.isTeamOwner(actorUid, team);
    final canRemove = TeamSquadUtils.canRemoveMember(
      actorUid: actorUid,
      team: team,
      target: player,
      squad: const [],
    );

    return [
      if (actorIsOwner && !isCaptain)
        const PopupMenuItem(value: 'make_captain', child: Text('Make Captain')),
      if (actorIsOwner && !isVc)
        const PopupMenuItem(
          value: 'make_vice_captain',
          child: Text('Make Vice Captain'),
        ),
      if (actorIsOwner && isCaptain)
        const PopupMenuItem(
          value: 'remove_captain',
          child: Text('Remove Captain'),
        ),
      if (actorIsOwner && isVc)
        const PopupMenuItem(
          value: 'remove_vice_captain',
          child: Text('Remove Vice Captain'),
        ),
      if (canRemove) ...[
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'remove_player',
          child: Text('Remove from team'),
        ),
      ],
    ];
  }
}

class _CopyablePlayerId extends StatelessWidget {
  const _CopyablePlayerId({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: playerId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied $playerId'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Text(
        playerId,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cf.textMuted,
              letterSpacing: 0.4,
              decoration: TextDecoration.underline,
              decorationColor: cf.textMuted.withValues(alpha: 0.5),
            ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({
    required this.player,
    required this.displayName,
    required this.isOwner,
    required this.isCaptain,
    required this.isViceCaptain,
  });

  final PlayerModel player;
  final String displayName;
  final bool isOwner;
  final bool isCaptain;
  final bool isViceCaptain;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: CfColors.primaryBlue,
            backgroundImage: player.photoUrl != null
                ? CachedNetworkImageProvider(player.photoUrl!)
                : null,
            child: player.photoUrl == null
                ? Text(
                    TeamSquadUtils.playerInitials(displayName),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          if (isOwner)
            Positioned(
              left: -2,
              bottom: -2,
              child: _CircleBadge(label: 'O', color: cf.accent),
            ),
          if (isCaptain)
            Positioned(
              right: -2,
              bottom: -2,
              child: _CircleBadge(
                label: 'C',
                color: CfColors.primaryBlue,
              ),
            )
          else if (isViceCaptain)
            Positioned(
              right: -2,
              bottom: -2,
              child: _CircleBadge(
                label: 'VC',
                color: CfColors.primaryBlue,
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleBadge extends StatelessWidget {
  const _CircleBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final compact = label.length > 1;
    return Container(
      width: compact ? 22 : 20,
      height: compact ? 22 : 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: cf.surfaceElevated, width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: label == 'O' ? cf.onAccent : Colors.white,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
