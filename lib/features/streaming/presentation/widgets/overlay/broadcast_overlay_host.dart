import 'package:flutter/material.dart';

import '../../../../../data/models/overlay_state_model.dart';
import '../../../data/models/stream_overlay_theme.dart';
import 'events/portrait_event_graphic.dart';
import 'scorebug/landscape/landscape_broadcast_scorebug.dart';
import 'scorebug/landscape/landscape_scorebug_context.dart';
import 'scorebug/landscape/landscape_top_header.dart';
import 'scorebug/portrait_scorebug.dart';
import 'scorebug/scorebug_tokens.dart';

/// Routes broadcast overlay widgets to portrait or landscape layouts.
class BroadcastOverlayHost extends StatelessWidget {
  const BroadcastOverlayHost({
    super.key,
    required this.landscape,
    required this.overlay,
    required this.theme,
    this.sponsorLogoUrl,
    this.landscapeContext,
    this.eventOverlay,
    this.onEventFinished,
    this.forBurnInCapture = false,
  });

  final bool landscape;
  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final String? sponsorLogoUrl;
  final LandscapeScorebugContext? landscapeContext;
  final StreamEventOverlay? eventOverlay;
  final VoidCallback? onEventFinished;
  final bool forBurnInCapture;

  @override
  Widget build(BuildContext context) {
    if (landscape) {
      final ctx = landscapeContext ?? const LandscapeScorebugContext();
      final tokens = ScorebugTokens.fromTheme(theme);
      final matchTitle = ctx.matchTitle.isNotEmpty
          ? ctx.matchTitle
          : (overlay.teamAName.isNotEmpty && overlay.teamBName.isNotEmpty
              ? '${overlay.teamAName} vs ${overlay.teamBName}'
              : overlay.battingTeamName);

      return LayoutBuilder(
        builder: (context, constraints) {
          final scale =
              (constraints.maxWidth / 1280).clamp(0.65, 1.35).toDouble();

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LandscapeTopHeader(
                  matchTitle: matchTitle,
                  tokens: tokens,
                  scale: scale,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    28 * scale,
                    0,
                    28 * scale,
                    14 * scale,
                  ),
                  child: LandscapeBroadcastScorebug(
                    overlay: overlay,
                    theme: theme,
                    context: ctx,
                    eventOverlay: eventOverlay,
                    onEventFinished: onEventFinished,
                    forBurnInCapture: forBurnInCapture,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: 12,
          right: 12,
          bottom: 20,
          child: PortraitScorebug(
            overlay: overlay,
            theme: theme,
            sponsorLogoUrl: sponsorLogoUrl,
          ),
        ),
        if (eventOverlay != null)
          PortraitEventGraphic(
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
