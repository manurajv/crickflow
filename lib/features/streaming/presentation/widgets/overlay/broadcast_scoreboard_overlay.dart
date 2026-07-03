import 'package:flutter/material.dart';

import '../../../../../data/models/overlay_state_model.dart';
import '../../../data/models/stream_overlay_theme.dart';
import 'broadcast_overlay_host.dart';

/// TV-style scorebug rendered over the camera preview.
///
/// Delegates to [BroadcastOverlayHost] with orientation-specific layouts.
class BroadcastScoreboardOverlay extends StatelessWidget {
  const BroadcastScoreboardOverlay({
    super.key,
    required this.overlay,
    required this.theme,
    this.tournamentLogoUrl,
    this.sponsorLogoUrl,
    this.landscape = false,
  });

  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final String? tournamentLogoUrl;
  final String? sponsorLogoUrl;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return BroadcastOverlayHost(
      landscape: landscape,
      overlay: overlay,
      theme: theme,
      sponsorLogoUrl: sponsorLogoUrl ?? tournamentLogoUrl,
    );
  }
}
