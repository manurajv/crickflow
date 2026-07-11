import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../domain/services/match_mvp_models.dart';
import '../../../../../shared/widgets/lineup_player_avatar.dart';

class MvpLeaderboardRow extends StatelessWidget {
  const MvpLeaderboardRow({
    super.key,
    required this.entry,
    required this.cf,
    this.showBreakdown = true,
    this.showPotmBadge = true,
    this.expanded = false,
    this.onToggle,
  });

  final MvpLeaderboardEntry entry;
  final CfColors cf;
  final bool showBreakdown;
  final bool showPotmBadge;
  final bool expanded;
  final VoidCallback? onToggle;

  MvpPlayerScore get player => entry.player;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        children: [
          _rowContent(
            child: Row(
              children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#${entry.displayRank}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: cf.textSecondary,
                      ),
                    ),
                  ),
                  LineupPlayerAvatar(
                    name: player.playerName,
                    photoUrl: player.photoUrl,
                    radius: 20,
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                player.playerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cf.textPrimary,
                                ),
                              ),
                            ),
                            if (showPotmBadge && player.isPlayerOfTheMatch)
                              _Badge(
                                label: 'Player Of The Match',
                                emoji: '🏆',
                                color: cf.accent,
                                cf: cf,
                              ),
                            if (player.isFighterOfTheMatch)
                              _Badge(
                                label: 'Fighter Of The Match',
                                emoji: '🥊',
                                color: cf.info,
                                cf: cf,
                              ),
                          ],
                        ),
                        Text(
                          player.teamName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: cf.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        entry.scoreLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: cf.textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        entry.displayScore.toStringAsFixed(3),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: cf.scoreEmphasis,
                        ),
                      ),
                    ],
                  ),
                if (showBreakdown)
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: cf.textMuted,
                    size: 20,
                  ),
              ],
            ),
          ),
          if (showBreakdown)
            AnimatedCrossFade(
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeOut,
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
              firstChild: const SizedBox.shrink(),
              secondChild: _BreakdownPanel(player: player, cf: cf),
            ),
        ],
      ),
    );
  }

  Widget _rowContent({required Widget child}) {
    final padding = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      child: child,
    );

    if (!showBreakdown || onToggle == null) return padding;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      child: padding,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.emoji,
    required this.color,
    required this.cf,
  });

  final String label;
  final String emoji;
  final Color color;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$emoji ${label.split(' ').first}',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _BreakdownPanel extends StatelessWidget {
  const _BreakdownPanel({required this.player, required this.cf});

  final MvpPlayerScore player;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDimens.radiusMd),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line('Bat', player.battingMvp),
          _line('Bowl', player.bowlingMvp),
          _line('Field', player.fieldingMvp),
          if (player.clutchBonus > 0.001)
            _line('Clutch', player.clutchBonus),
          if (player.partnershipBonus > 0.001)
            _line('Partnership', player.partnershipBonus),
          const Divider(height: 16),
          Row(
            children: [
              Text(
                'Total MVP',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cf.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                player.totalMvp.toStringAsFixed(3),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cf.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: TextStyle(color: cf.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cf.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
