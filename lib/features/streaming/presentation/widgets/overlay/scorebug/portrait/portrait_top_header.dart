import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../landscape/landscape_scorebug_context_builder.dart';
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
            child: Align(
              alignment: Alignment.topLeft,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: IntrinsicWidth(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * scale,
                          vertical: 6 * scale,
                        ),
                        color: tokens.panelBg.withValues(alpha: 0.94),
                        child: Text(
                          matchTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PortraitScorebugLayout.headerTitleStyle(
                            tokens,
                            scale,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34 * scale,
                height: 34 * scale,
                child: CachedNetworkImage(
                  imageUrl: LandscapeScorebugContextBuilder.crickflowLogoUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Icon(
                    Icons.sports_cricket,
                    color: tokens.gold,
                    size: 28 * scale,
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.sports_cricket,
                    color: tokens.gold,
                    size: 28 * scale,
                  ),
                ),
              ),
              SizedBox(height: 4 * scale),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 6 * scale,
                  vertical: 2 * scale,
                ),
                color: tokens.liveRed,
                child: Text(
                  'LIVE',
                  style: TextStyle(
                    color: tokens.white,
                    fontSize: 8 * scale,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
