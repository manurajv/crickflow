import 'package:flutter/material.dart';

import '../../../../../../core/constants/app_constants.dart';
import 'scorebug_tokens.dart';

/// CrickFlow logo + LIVE badge — shared by scorebug, burn-in, and match intro.
///
/// Uses the bundled high-res asset (not a network URL) so burn-in PNG capture
/// stays sharp when scaled into the RTMP frame.
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

  /// Kept for call-site compatibility; brand mark uses [AppConstants.crickflowLogoAsset].
  final String? logoUrl;

  /// Landscape logo edge length before [scale] (was 50; ~2× for on-air presence).
  static const double landscapeLogoSize = 100;

  /// Portrait logo edge length before [scale] (was 34; ~2×).
  static const double portraitLogoSize = 68;

  /// Gap between logo and LIVE badge (tight, TV-style stack).
  static double logoBadgeGap(double scale, {required bool landscape}) =>
      (landscape ? 8 : 6) * scale;

  /// Approximate LIVE badge height used for reserved layout space.
  static double liveBadgeHeight(double scale, {required bool landscape}) =>
      (landscape ? 22 : 18) * scale;

  @override
  Widget build(BuildContext context) {
    final logoSize =
        (landscape ? landscapeLogoSize : portraitLogoSize) * scale;
    final logoIconSize = logoSize * 0.72;
    final gap = logoBadgeGap(scale, landscape: landscape);
    final badgePaddingH = (landscape ? 10 : 8) * scale;
    final badgePaddingV = (landscape ? 4 : 3) * scale;
    final badgeFontSize = (landscape ? 13 : 11) * scale;
    final badgeLetterSpacing = landscape ? 1.4 : 1.1;
    // Decode above display size so burn-in / GL scale stays crisp.
    final cachePx = (logoSize * 3).round().clamp(256, 1024);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: Image.asset(
            AppConstants.crickflowLogoAsset,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            cacheWidth: cachePx,
            cacheHeight: cachePx,
            errorBuilder: (context, error, stackTrace) => Icon(
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
