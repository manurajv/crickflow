import 'package:flutter/material.dart';

import '../broadcast_live_branding.dart';
import '../broadcast_match_title_chip.dart';
import '../scorebug_tokens.dart';
import 'portrait_scorebug_layout.dart';

/// Compact top header for portrait streams — match title and LIVE badge.
class PortraitTopHeader extends StatelessWidget {
  const PortraitTopHeader({
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
      padding: PortraitScorebugLayout.topHeaderPadding(scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: BroadcastMatchTitleChip(
              title: matchTitle,
              tokens: tokens,
              scale: scale,
              landscape: false,
            ),
          ),
          SizedBox(width: 8 * scale),
          BroadcastLiveBranding(
            tokens: tokens,
            scale: scale,
            landscape: false,
          ),
        ],
      ),
    );
  }
}
