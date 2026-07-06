import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'landscape/landscape_scorebug_context_builder.dart';
import 'scorebug_tokens.dart';

/// CrickFlow logo + LIVE badge — shared by scorebug and match introduction.
class BroadcastLiveBranding extends StatelessWidget {
  const BroadcastLiveBranding({
    super.key,
    required this.tokens,
    required this.scale,
    this.landscape = true,
    this.logoUrl,
  });

  final ScorebugTokens tokens;
  final double scale;
  final bool landscape;
  final String? logoUrl;

  String get _resolvedLogoUrl =>
      logoUrl ?? LandscapeScorebugContextBuilder.crickflowLogoUrl;

  @override
  Widget build(BuildContext context) {
    final logoSize = (landscape ? 50 : 34) * scale;
    final logoIconSize = (landscape ? 70 : 28) * scale;
    final gap = (landscape ? 30 : 4) * scale;
    final badgePaddingH = (landscape ? 7 : 6) * scale;
    final badgePaddingV = (landscape ? 3 : 2) * scale;
    final badgeFontSize = (landscape ? 10 : 8) * scale;
    final badgeLetterSpacing = landscape ? 1.2 : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: CachedNetworkImage(
            imageUrl: _resolvedLogoUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => Icon(
              Icons.sports_cricket,
              color: tokens.gold,
              size: logoIconSize,
            ),
            errorWidget: (context, url, error) => Icon(
              Icons.sports_cricket,
              color: tokens.gold,
              size: logoIconSize,
            ),
          ),
        ),
        SizedBox(height: gap),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: badgePaddingH,
            vertical: badgePaddingV,
          ),
          color: tokens.liveRed,
          child: Text(
            'LIVE',
            style: TextStyle(
              color: tokens.white,
              fontSize: badgeFontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: badgeLetterSpacing,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}
