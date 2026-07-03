import 'package:flutter/material.dart';

import '../../../../../data/models/overlay_state_model.dart';
import '../../../data/models/stream_overlay_theme.dart';
import 'events/landscape_event_graphic.dart';
import 'events/portrait_event_graphic.dart';
import 'scorebug/landscape_scorebug.dart';
import 'scorebug/portrait_scorebug.dart';

/// Routes broadcast overlay widgets to portrait or landscape layouts.
class BroadcastOverlayHost extends StatelessWidget {
  const BroadcastOverlayHost({
    super.key,
    required this.landscape,
    required this.overlay,
    required this.theme,
    this.sponsorLogoUrl,
    this.eventOverlay,
    this.onEventFinished,
    this.forBurnInCapture = false,
  });

  final bool landscape;
  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final String? sponsorLogoUrl;
  final StreamEventOverlay? eventOverlay;
  final VoidCallback? onEventFinished;
  final bool forBurnInCapture;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: landscape ? 0 : 12,
          right: landscape ? 0 : 12,
          bottom: landscape ? 16 : 20,
          child: landscape
              ? LandscapeScorebug(
                  overlay: overlay,
                  theme: theme,
                  sponsorLogoUrl: sponsorLogoUrl,
                )
              : PortraitScorebug(
                  overlay: overlay,
                  theme: theme,
                  sponsorLogoUrl: sponsorLogoUrl,
                ),
        ),
        if (eventOverlay != null)
          landscape
              ? LandscapeEventGraphic(
                  type: eventOverlay!.type,
                  title: eventOverlay!.title,
                  subtitle: eventOverlay!.subtitle,
                  duration: eventOverlay!.duration,
                  forBurnInCapture: forBurnInCapture,
                  onFinished: onEventFinished,
                )
              : PortraitEventGraphic(
                  type: eventOverlay!.type,
                  title: eventOverlay!.title,
                  subtitle: eventOverlay!.subtitle,
                  duration: eventOverlay!.duration,
                  forBurnInCapture: forBurnInCapture,
                  onFinished: onEventFinished,
                ),
      ],
    );
  }
}
