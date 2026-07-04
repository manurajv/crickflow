import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../scorebug_tokens.dart';
import 'landscape_scorebug_context_builder.dart';

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
      padding: EdgeInsets.only(
        left: 32 * scale,
        top: 14 * scale,
        right: 18 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 2 * scale),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12 * scale,
                    vertical: 6 * scale,
                  ),
                  color: tokens.navyDeep.withValues(alpha: 0.92),
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
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 6 * scale, right: 6 * scale),
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
                      size: 38 * scale,
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.sports_cricket,
                      color: tokens.gold,
                      size: 38 * scale,
                    ),
                  ),
                ),
                SizedBox(height: 4 * scale),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 7 * scale,
                    vertical: 2 * scale,
                  ),
                  color: tokens.liveRed,
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      color: tokens.white,
                      fontSize: 8 * scale,
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
