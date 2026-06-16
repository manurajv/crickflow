import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/team_players_provider.dart';
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
    final theme = Theme.of(context);
    final fullNameAsync = ref.watch(playerSquadFullNameProvider(player));
    final fullName = fullNameAsync.valueOrNull ?? TeamSquadUtils.squadFullName(player);
    final roleLine = TeamSquadUtils.roleLine(player);
    final isOwner = TeamSquadUtils.isPlayerOwner(player, team);
    final isCaptain = TeamSquadUtils.isCaptain(player, team);
    final isVc = TeamSquadUtils.isViceCaptain(player, team);
    final playerId = TeamSquadUtils.playerIdDisplay(player.playerId);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
      ),
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
                      if (roleLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          roleLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryBlueLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isOwnerViewer && onOwnerMenu != null)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textSecondary,
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
              color: AppColors.textMuted,
              letterSpacing: 0.4,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.textMuted.withValues(alpha: 0.5),
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
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: AppColors.primaryBlue,
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
            const Positioned(
              left: -2,
              bottom: -2,
              child: _CircleBadge(label: 'O', color: AppColors.gold),
            ),
          if (isCaptain)
            const Positioned(
              right: -2,
              bottom: -2,
              child: _CircleBadge(label: 'C', color: AppColors.primaryBlue),
            )
          else if (isViceCaptain)
            const Positioned(
              right: -2,
              bottom: -2,
              child: _CircleBadge(label: 'VC', color: AppColors.primaryBlue),
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
    final compact = label.length > 1;
    return Container(
      width: compact ? 22 : 20,
      height: compact ? 22 : 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surfaceElevated, width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: label == 'O' ? Colors.black : Colors.white,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
