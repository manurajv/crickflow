import 'package:flutter/material.dart';

import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/lineup_player.dart';
import '../../../../shared/widgets/lineup_player_avatar.dart';

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
    final cf = context.cf;
    final selected = player != null;
    final name = player?.name ?? placeholder;

    return Expanded(
      flex: flex,
      child: AspectRatio(
        aspectRatio: 0.85,
        child: Material(
          color: cf.card,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: cf.sectionBackground,
                    child: selected
                        ? Center(
                            child: LineupPlayerAvatar(
                              name: name,
                              photoUrl: player?.photoUrl,
                              radius: 36,
                              backgroundColor: cf.sectionBackground,
                              foregroundColor: cf.accent,
                              fontSize: 28,
                            ),
                          )
                        : Icon(
                            icon,
                            size: 56,
                            color: cf.textMuted.withValues(alpha: 0.45),
                          ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cf.card,
                    border: Border(
                      top: BorderSide(color: cf.border, width: 0.5),
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
                      color: selected ? cf.textPrimary : cf.textMuted,
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
