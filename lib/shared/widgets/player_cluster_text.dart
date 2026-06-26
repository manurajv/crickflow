import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../domain/services/player_cricket_profile_models.dart';

/// Colored batting/bowling cluster labels (shared with profile header).
class PlayerClusterText extends StatelessWidget {
  const PlayerClusterText({
    super.key,
    required this.clusters,
    this.fontSize = 11,
    this.separatorColor,
    this.showNewPlayerForMissing = false,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.textAlign,
  });

  final PlayerClusters clusters;
  final double fontSize;
  final Color? separatorColor;
  final bool showNewPlayerForMissing;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final TextAlign? textAlign;

  static const newPlayerLabel = 'New Player';
  static const newPlayerColor = Color(0xFF4DB6AC);

  @override
  Widget build(BuildContext context) {
    final batting = clusters.batting;
    final bowling = clusters.bowling;
    final dividerColor =
        separatorColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    if (showNewPlayerForMissing) {
      if (batting == null && bowling == null) {
        return _label(newPlayerLabel, newPlayerColor);
      }
      if (batting != null && bowling != null) {
        return _pair(
          _clusterSpan(battingLabel(batting), battingColor(batting)),
          _clusterSpan(bowlingLabel(bowling), bowlingColor(bowling)),
          dividerColor,
        );
      }
      if (batting != null) {
        return _pair(
          _clusterSpan(battingLabel(batting), battingColor(batting)),
          _clusterSpan(newPlayerLabel, newPlayerColor),
          dividerColor,
        );
      }
      return _pair(
        _clusterSpan(newPlayerLabel, newPlayerColor),
        _clusterSpan(bowlingLabel(bowling!), bowlingColor(bowling)),
        dividerColor,
      );
    }

    final spans = <InlineSpan>[];
    if (batting != null) {
      spans.add(_clusterSpan(battingLabel(batting), battingColor(batting)));
    }
    if (batting != null && bowling != null) {
      spans.add(_dividerSpan(dividerColor));
    }
    if (bowling != null) {
      spans.add(_clusterSpan(bowlingLabel(bowling), bowlingColor(bowling)));
    }

    if (spans.isEmpty) return const SizedBox.shrink();
    return _richText(TextSpan(children: spans));
  }

  TextSpan _clusterSpan(String text, Color color) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
      ),
    );
  }

  TextSpan _dividerSpan(Color color) {
    return TextSpan(
      text: ' • ',
      style: TextStyle(color: color, fontSize: fontSize),
    );
  }

  Widget _label(String text, Color color) {
    return _richText(_clusterSpan(text, color));
  }

  Widget _pair(TextSpan first, TextSpan second, Color dividerColor) {
    return _richText(
      TextSpan(children: [first, _dividerSpan(dividerColor), second]),
    );
  }

  Widget _richText(InlineSpan span) {
    return Text.rich(
      span,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textAlign: textAlign,
    );
  }

  static String battingLabel(BattingClusterType type) => switch (type) {
        BattingClusterType.steadyBatter => 'Steady Batter',
        BattingClusterType.classicist => 'Classicist',
        BattingClusterType.accumulator => 'Accumulator',
        BattingClusterType.hardHitter => 'Hard Hitter',
        BattingClusterType.destroyer => 'Destroyer',
      };

  static String bowlingLabel(BowlingClusterType type) => switch (type) {
        BowlingClusterType.aspirant => 'Aspirant',
        BowlingClusterType.wildcard => 'Wildcard',
        BowlingClusterType.economist => 'Economist',
        BowlingClusterType.spearhead => 'Spearhead',
      };

  static Color battingColor(BattingClusterType type) => switch (type) {
        BattingClusterType.steadyBatter => const Color(0xFF90CAF9),
        BattingClusterType.classicist => const Color(0xFFFFCC80),
        BattingClusterType.accumulator => const Color(0xFFA5D6A7),
        BattingClusterType.hardHitter => const Color(0xFFFFAB91),
        BattingClusterType.destroyer => const Color(0xFFFF5252),
      };

  static Color bowlingColor(BowlingClusterType type) => switch (type) {
        BowlingClusterType.aspirant => const Color(0xFFB0BEC5),
        BowlingClusterType.wildcard => const Color(0xFFCE93D8),
        BowlingClusterType.economist => const Color(0xFF80DEEA),
        BowlingClusterType.spearhead => const Color(0xFFFFD54F),
      };
}
