import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/team_model.dart';
import 'team_list_tile.dart' show TeamLogoAvatar;

/// Wide team cover image below the app bar.
class TeamDetailBanner extends StatelessWidget {
  const TeamDetailBanner({
    super.key,
    required this.team,
    this.squadCount,
  });

  final TeamModel team;
  final int? squadCount;

  static const double height = 140;

  int get _memberCount {
    if (squadCount != null && squadCount! > 0) return squadCount!;
    if (team.memberCount > 0) return team.memberCount;
    return team.playerIds.length;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final cover = team.coverImageUrl;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image or gradient placeholder
          cover != null
              ? CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const _PlaceholderCover(),
                  errorWidget: (context, url, error) =>
                      const _PlaceholderCover(),
                )
              : const _PlaceholderCover(),

          // Gradient scrim at the bottom so logo/text sit on it cleanly
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1.0],
                  colors: [Colors.transparent, cf.bannerScrimEnd],
                ),
              ),
            ),
          ),

          // Team logo + name row pinned to bottom-left
          Positioned(
            left: AppDimens.spaceMd,
            right: AppDimens.spaceMd,
            bottom: AppDimens.spaceMd,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TeamLogoAvatar(team: team, size: 64, borderWidth: 2.5),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (team.location.displayLabel.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 11,
                              color: cf.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                team.location.displayLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cf.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_memberCount > 0)
                        Text(
                          '$_memberCount ${_memberCount == 1 ? 'player' : 'players'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cf.textSecondary,
                            height: 1.3,
                          ),
                        ),
                    ],
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

class _PlaceholderCover extends StatelessWidget {
  const _PlaceholderCover();

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D2B6B),
            CfColors.primaryBlue.withValues(alpha: 0.45),
            cf.surfaceElevated,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Promo strip matching reference — squad banners CTA.
class TeamSquadBannersStrip extends StatelessWidget {
  const TeamSquadBannersStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.accent.withValues(alpha: 0.15),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Squad banners — coming soon')),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cf.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                Icons.collections_outlined,
                size: 18,
                color: cf.accent,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Text(
                  'Get squad banners',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: cf.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
