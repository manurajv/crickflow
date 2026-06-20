import 'package:flutter/material.dart';

import '../../core/theme/cf_colors.dart';
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

  Color _colorForKind(CfColors cf) {
    switch (kind) {
      case 'dls':
        return cf.info;
      case 'target':
        return cf.accent;
      case 'penalty':
        return cf.statusUpcoming;
      case 'end':
        return cf.textSecondary;
      case 'result':
        return cf.textMuted;
      default:
        return cf.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final color = _colorForKind(cf);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: cf.isLight ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          color: color,
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
