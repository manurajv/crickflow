import 'package:flutter/material.dart';

import '../scorebug/broadcast_live_branding.dart';
import '../scorebug/scorebug_tokens.dart';

/// Match introduction wrapper around shared scorebug live branding.
class LiveBrandingHeader extends StatelessWidget {
  const LiveBrandingHeader({
    super.key,
    required this.logoUrl,
    required this.tokens,
    required this.scale,
    required this.opacity,
    this.landscape = true,
  });

  final String logoUrl;
  final ScorebugTokens tokens;
  final double scale;
  final double opacity;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: BroadcastLiveBranding(
        tokens: tokens,
        scale: scale,
        landscape: landscape,
        logoUrl: logoUrl,
      ),
    );
  }
}
