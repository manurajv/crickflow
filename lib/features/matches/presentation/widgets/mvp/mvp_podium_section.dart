import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/match_mvp_models.dart';
import '../../../../../shared/widgets/lineup_player_avatar.dart';

class MvpPodiumSection extends StatelessWidget {
  const MvpPodiumSection({
    super.key,
    required this.podium,
    required this.cf,
  });

  final List<MvpPlayerScore> podium;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (podium.isEmpty) return const SizedBox.shrink();

    final first = podium.isNotEmpty ? podium[0] : null;
    final second = podium.length > 1 ? podium[1] : null;
    final third = podium.length > 2 ? podium[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumCard(
            player: second,
            cf: cf,
            minHeight: 128,
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: _PodiumCard(
            player: first,
            cf: cf,
            minHeight: 156,
            highlight: true,
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: _PodiumCard(
            player: third,
            cf: cf,
            minHeight: 118,
          ),
        ),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.player,
    required this.cf,
    required this.minHeight,
    this.highlight = false,
  });

  final MvpPlayerScore? player;
  final CfColors cf;
  final double minHeight;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight ? cf.accent : cf.border;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final avatarRadius = highlight
            ? (width * 0.18).clamp(16.0, 22.0)
            : (width * 0.15).clamp(14.0, 18.0);
        final nameSize = highlight
            ? (width * 0.09).clamp(10.0, 13.0)
            : (width * 0.08).clamp(9.0, 11.0);
        final scoreSize = highlight
            ? (width * 0.11).clamp(12.0, 16.0)
            : (width * 0.10).clamp(11.0, 13.0);

        return Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceXs,
            vertical: AppDimens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: cf.card,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            border: Border.all(
              color: borderColor,
              width: highlight ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: cf.cardShadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: player == null
              ? Center(
                  child: Text(
                    '—',
                    style: TextStyle(color: cf.textMuted),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LineupPlayerAvatar(
                      name: player!.playerName,
                      photoUrl: player!.photoUrl,
                      radius: avatarRadius,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      player!.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: nameSize,
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                    ),
                    Text(
                      player!.teamName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        fontStyle: FontStyle.italic,
                        color: cf.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      player!.totalMvp.toStringAsFixed(3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: scoreSize,
                        fontWeight: FontWeight.w800,
                        color: cf.scoreEmphasis,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
