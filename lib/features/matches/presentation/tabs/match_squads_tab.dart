import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/match_squads_provider.dart';

class MatchSquadsTab extends ConsumerWidget {
  const MatchSquadsTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadsAsync = ref.watch(matchDualSquadsProvider(matchId));

    return squadsAsync.when(
      data: (squads) {
        if (squads.teamAPlayers.isEmpty && squads.teamBPlayers.isEmpty) {
          return Center(
            child: Padding(
              padding: AppDimens.listPadding,
              child: Text(
                'Link teams to this match to see full squads.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceSm,
                AppDimens.spaceMd,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      squads.teamAName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('vs', style: Theme.of(context).textTheme.bodySmall),
                  Expanded(
                    child: Text(
                      squads.teamBName,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SquadColumn(
                      team: squads.teamA,
                      players: squads.teamAPlayers,
                      alignEnd: false,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _SquadColumn(
                      team: squads.teamB,
                      players: squads.teamBPlayers,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _SquadColumn extends StatelessWidget {
  const _SquadColumn({
    required this.team,
    required this.players,
    required this.alignEnd,
  });

  final TeamModel? team;
  final List<PlayerModel> players;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXs),
      itemCount: players.length,
      itemBuilder: (context, i) {
        final p = players[i];
        final isCaptain = team?.captainId == p.id;
        final isVice = team?.viceCaptainId == p.id;

        return _PlayerRow(
          player: p,
          isCaptain: isCaptain,
          isVice: isVice,
          alignEnd: alignEnd,
        );
      },
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.isCaptain,
    required this.isVice,
    required this.alignEnd,
  });

  final PlayerModel player;
  final bool isCaptain;
  final bool isVice;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final subtitle = _archetype(player);

    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.surfaceElevated,
      backgroundImage:
          player.photoUrl != null ? CachedNetworkImageProvider(player.photoUrl!) : null,
      child: player.photoUrl == null
          ? Text(
              player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12),
            )
          : null,
    );

    final text = Expanded(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCaptain)
                const _Badge(label: 'C', color: AppColors.gold),
              if (isVice) const _Badge(label: 'VC', color: AppColors.primaryBlueLight),
              Flexible(
                child: Text(
                  player.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: alignEnd
            ? [text, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), text],
      ),
    );
  }

  String _archetype(PlayerModel p) {
    final parts = <String>[];
    if (p.role.isNotEmpty) parts.add(p.role);
    if (p.battingStyle.isNotEmpty) parts.add(p.battingStyle);
    return parts.take(2).join(' · ');
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
