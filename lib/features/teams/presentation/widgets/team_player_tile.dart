import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/models/team_model.dart';

class TeamPlayerTile extends StatelessWidget {
  const TeamPlayerTile({
    super.key,
    required this.player,
    required this.team,
    this.isCaptain = false,
    this.onPhotoTap,
  });

  final PlayerModel player;
  final TeamModel team;
  final bool isCaptain;
  final VoidCallback? onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      if (player.role.isNotEmpty) player.role,
      if (player.battingStyle.isNotEmpty) player.battingStyle,
    ];

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      child: InkWell(
        onTap: () => context.push('/players/${player.id}'),
        borderRadius: AppDimens.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: onPhotoTap,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryBlue,
                      backgroundImage: player.photoUrl != null
                          ? CachedNetworkImageProvider(player.photoUrl!)
                          : null,
                      child: player.photoUrl == null
                          ? Text(
                              player.jerseyNumber?.toString() ??
                                  (player.name.isNotEmpty
                                      ? player.name[0].toUpperCase()
                                      : '?'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (isCaptain)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Captain',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (tags.isNotEmpty)
                      Text(
                        tags.join(' • '),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primaryBlueLight,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
