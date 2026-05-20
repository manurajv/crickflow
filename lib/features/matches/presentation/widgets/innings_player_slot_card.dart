import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/lineup_player.dart';

/// Striker / non-striker / bowler slot on Start innings (reference-style).
class InningsPlayerSlotCard extends StatelessWidget {
  const InningsPlayerSlotCard({
    super.key,
    required this.placeholder,
    this.player,
    required this.onTap,
    this.icon = Icons.sports_cricket,
    this.flex = 1,
  });

  final String placeholder;
  final LineupPlayer? player;
  final VoidCallback onTap;
  final IconData icon;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final selected = player != null;
    final name = player?.name ?? placeholder;

    return Expanded(
      flex: flex,
      child: AspectRatio(
        aspectRatio: 0.85,
        child: Material(
          color: AppColors.card,
          borderRadius: AppDimens.cardRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: AppColors.surfaceElevated,
                    child: selected
                        ? Center(
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.primaryBlue,
                              child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          )
                        : Icon(
                            icon,
                            size: 56,
                            color: AppColors.textMuted.withValues(alpha: 0.45),
                          ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 0.5),
                    ),
                  ),
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
