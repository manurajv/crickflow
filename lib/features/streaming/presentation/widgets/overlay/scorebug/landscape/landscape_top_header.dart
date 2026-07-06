import 'package:flutter/material.dart';

import '../broadcast_live_branding.dart';
import '../broadcast_match_title_chip.dart';
import '../scorebug_tokens.dart';
import 'landscape_scorebug_layout.dart';

/// Top header — match title (left) and CrickFlow brand + LIVE badge (right).
class LandscapeTopHeader extends StatelessWidget {
  const LandscapeTopHeader({
    super.key,
    required this.matchTitle,
    required this.tokens,
    required this.scale,
  });

  final String matchTitle;
  final ScorebugTokens tokens;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: LandscapeScorebugLayout.topHeaderPadding(scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: BroadcastMatchTitleChip(
              title: matchTitle,
              tokens: tokens,
              scale: scale,
              landscape: true,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12 * scale, right: 30 * scale),
            child: BroadcastLiveBranding(
              tokens: tokens,
              scale: scale,
              landscape: true,
            ),
          ),
        ],
      ),
    );
  }
}
