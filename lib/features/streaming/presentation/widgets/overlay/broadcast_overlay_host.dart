import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/models/overlay_state_model.dart';
import '../../../data/models/stream_overlay_theme.dart';
import '../../../domain/streaming_enums.dart';
import 'batter_intro/broadcast_batter_intro_panel.dart';
import 'bowler_intro/broadcast_bowler_intro_panel.dart';
import 'scorebug/landscape/landscape_broadcast_scorebug.dart';
import 'scorebug/landscape/landscape_scorebug_context.dart';
import 'scorebug/landscape/landscape_scorebug_layout.dart';
import 'scorebug/landscape/landscape_top_header.dart';
import 'scorebug/portrait/portrait_broadcast_scorebug.dart';
import 'scorebug/portrait/portrait_scorebug_layout.dart';
import 'scorebug/portrait/portrait_top_header.dart';
import 'scorebug/scorebug_helpers.dart';
import 'scorebug/scorebug_tokens.dart';

/// Routes broadcast overlay widgets to portrait or landscape layouts.
class BroadcastOverlayHost extends ConsumerWidget {
  const BroadcastOverlayHost({
    super.key,
    required this.matchId,
    required this.landscape,
    required this.overlay,
    required this.theme,
    this.sponsorLogoUrl,
    this.landscapeContext,
    this.eventOverlay,
    this.onEventFinished,
    this.forBurnInCapture = false,
  });

  final String matchId;
  final bool landscape;
  final OverlayStateModel overlay;
  final StreamOverlayTheme theme;
  final String? sponsorLogoUrl;
  final LandscapeScorebugContext? landscapeContext;
  final StreamEventOverlay? eventOverlay;
  final VoidCallback? onEventFinished;
  final bool forBurnInCapture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = landscapeContext ?? const LandscapeScorebugContext();
    final tokens = ScorebugTokens.fromTheme(theme);
    final centerEvent = ScorebugHelpers.centerScorebugEvent(eventOverlay);
    final bowlerIntroEvent =
        eventOverlay?.type == StreamEventOverlayType.newBowler
            ? eventOverlay
            : null;
    final batterIntroEvent =
        eventOverlay?.type == StreamEventOverlayType.newBatter
            ? eventOverlay
            : null;
    final matchTitle = ctx.matchTitle.isNotEmpty
        ? ctx.matchTitle
        : (overlay.teamAName.isNotEmpty && overlay.teamBName.isNotEmpty
            ? '${overlay.teamAName} vs ${overlay.teamBName}'
            : overlay.battingTeamName);

    if (landscape) {
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
              if (batterIntroEvent != null)
                Positioned(
                  top: LandscapeScorebugLayout.topHeaderReservedHeight(scale) +
                      10 * scale,
                  left: LandscapeScorebugLayout.overlayHorizontalInset(scale),
                  bottom: LandscapeScorebugLayout.scorebugReservedHeight(scale),
                  child: LayoutBuilder(
                    builder: (context, panelConstraints) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: BroadcastBatterIntroPanel(
                          key: ValueKey(
                            'batter-intro-${batterIntroEvent.playerId}-'
                            '${batterIntroEvent.createdAt?.millisecondsSinceEpoch ?? batterIntroEvent.playerName}',
                          ),
                          matchId: matchId,
                          event: batterIntroEvent,
                          tokens: tokens,
                          landscape: true,
                          scale: scale,
                          maxHeight: panelConstraints.maxHeight,
                          forBurnInCapture: forBurnInCapture,
                          onFinished: onEventFinished,
                        ),
                      );
                    },
                  ),
                ),
              if (bowlerIntroEvent != null)
                Positioned(
                  top: LandscapeScorebugLayout.topHeaderReservedHeight(scale) +
                      10 * scale,
                  right: 28 * scale,
                  bottom: LandscapeScorebugLayout.scorebugReservedHeight(scale),
                  child: LayoutBuilder(
                    builder: (context, panelConstraints) {
                      return Align(
                        alignment: Alignment.topRight,
                        child: BroadcastBowlerIntroPanel(
                          key: ValueKey(
                            'bowler-intro-${bowlerIntroEvent.playerId}-'
                            '${bowlerIntroEvent.createdAt?.millisecondsSinceEpoch ?? bowlerIntroEvent.playerName}',
                          ),
                          matchId: matchId,
                          event: bowlerIntroEvent,
                          tokens: tokens,
                          landscape: true,
                          scale: scale,
                          maxHeight: panelConstraints.maxHeight,
                          forBurnInCapture: forBurnInCapture,
                          onFinished: onEventFinished,
                        ),
                      );
                    },
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    LandscapeScorebugLayout.overlayHorizontalInset(scale),
                    0,
                    28 * scale,
                    14 * scale,
                  ),
                  child: LandscapeBroadcastScorebug(
                    overlay: overlay,
                    theme: theme,
                    context: ctx,
                    eventOverlay: centerEvent,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 360).clamp(0.85, 1.25).toDouble();
        final portraitIntroTop =
            PortraitScorebugLayout.topHeaderReservedHeight(scale) + 8 * scale;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PortraitTopHeader(
                matchTitle: matchTitle,
                tokens: tokens,
                scale: scale,
              ),
            ),
            if (batterIntroEvent != null)
              Positioned(
                top: portraitIntroTop,
                left: 8 * scale,
                child: BroadcastBatterIntroPanel(
                  key: ValueKey(
                    'batter-intro-${batterIntroEvent.playerId}-'
                    '${batterIntroEvent.createdAt?.millisecondsSinceEpoch ?? batterIntroEvent.playerName}',
                  ),
                  matchId: matchId,
                  event: batterIntroEvent,
                  tokens: tokens,
                  landscape: false,
                  scale: scale,
                  forBurnInCapture: forBurnInCapture,
                  onFinished: onEventFinished,
                ),
              ),
            if (bowlerIntroEvent != null)
              Positioned(
                top: portraitIntroTop,
                right: 8 * scale,
                child: BroadcastBowlerIntroPanel(
                  key: ValueKey(
                    'bowler-intro-${bowlerIntroEvent.playerId}-'
                    '${bowlerIntroEvent.createdAt?.millisecondsSinceEpoch ?? bowlerIntroEvent.playerName}',
                  ),
                  matchId: matchId,
                  event: bowlerIntroEvent,
                  tokens: tokens,
                  landscape: false,
                  scale: scale,
                  forBurnInCapture: forBurnInCapture,
                  onFinished: onEventFinished,
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 16,
              child: PortraitBroadcastScorebug(
                overlay: overlay,
                theme: theme,
                context: ctx,
                eventOverlay: centerEvent,
                onEventFinished: onEventFinished,
                forBurnInCapture: forBurnInCapture,
              ),
            ),
          ],
        );
      },
    );
  }
}
