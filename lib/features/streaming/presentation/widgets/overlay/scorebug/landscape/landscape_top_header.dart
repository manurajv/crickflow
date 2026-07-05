import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../scorebug_tokens.dart';
import 'landscape_scorebug_context_builder.dart';
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
            child: Align(
              alignment: Alignment.topLeft,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: IntrinsicWidth(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12 * scale,
                          vertical: 6 * scale,
                        ),
                        color: tokens.panelBg.withValues(alpha: 0.94),
                        child: Text(
                          matchTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.white,
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.25,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12 * scale, right: 30 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50 * scale,
                  height: 50 * scale,
                  child: CachedNetworkImage(
                    imageUrl: LandscapeScorebugContextBuilder.crickflowLogoUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Icon(
                      Icons.sports_cricket,
                      color: tokens.gold,
                      size: 70 * scale,
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.sports_cricket,
                      color: tokens.gold,
                      size: 70 * scale,
                    ),
                  ),
                ),
                SizedBox(height: 30 * scale),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 7 * scale,
                    vertical: 3 * scale,
                  ),
                  color: tokens.liveRed,
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      color: tokens.white,
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
