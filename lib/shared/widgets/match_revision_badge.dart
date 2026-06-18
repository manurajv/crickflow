import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/display/match_revision_display.dart';

/// Highlight chip for DLS / target / penalty / end-innings badges.
class MatchRevisionBadgeChip extends StatelessWidget {
  const MatchRevisionBadgeChip({
    super.key,
    required this.label,
    this.kind = 'default',
    this.compact = false,
  });

  MatchRevisionBadgeChip.fromBadge(
    MatchRevisionBadge badge, {
    super.key,
    this.compact = false,
  })  : label = badge.label,
        kind = badge.kind;

  final String label;
  final String kind;
  final bool compact;

  Color get _color {
    switch (kind) {
      case 'dls':
      case 'target':
        return AppColors.gold;
      case 'penalty':
        return const Color(0xFFFF9800);
      case 'end':
      case 'result':
        return AppColors.textSecondary;
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.85)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          color: _color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class MatchRevisionBadgeRow extends StatelessWidget {
  const MatchRevisionBadgeRow({
    super.key,
    required this.badges,
    this.compact = false,
    this.alignment = WrapAlignment.start,
  });

  final List<MatchRevisionBadge> badges;
  final bool compact;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: alignment,
      children: [
        for (final badge in badges)
          MatchRevisionBadgeChip.fromBadge(badge, compact: compact),
      ],
    );
  }
}
