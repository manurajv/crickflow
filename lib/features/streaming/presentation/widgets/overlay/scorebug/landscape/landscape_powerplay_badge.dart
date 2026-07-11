import 'package:flutter/material.dart';

import '../scorebug_tokens.dart';
import '../portrait/portrait_scorebug_layout.dart';

/// P1 / P2 / P3 badge shown during powerplay overs.
class LandscapePowerplayBadge extends StatelessWidget {
  const LandscapePowerplayBadge({
    super.key,
    required this.label,
    required this.tokens,
    required this.scale,
    this.portrait = false,
  });

  final String label;
  final ScorebugTokens tokens;
  final double scale;
  final bool portrait;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24 * scale,
      color: tokens.white,
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: tokens.onScore,
          fontSize: portrait
              ? PortraitScorebugLayout.powerplayFontSize(scale)
              : 10 * scale,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
