import 'package:flutter/material.dart';

import '../../../../data/models/innings_break_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../scorebug/landscape/landscape_scorebug_layout.dart';
import '../scorebug/landscape/landscape_top_header.dart';
import '../scorebug/portrait/portrait_scorebug_layout.dart';
import '../scorebug/portrait/portrait_top_header.dart';
import '../scorebug/scorebug_tokens.dart';
import 'innings_break_overlay.dart';
import 'innings_break_side_panels.dart';

/// Innings break slideshow — scorebug header/LIVE only; target on side panels.
class InningsBreakOverlayHost extends StatelessWidget {
  const InningsBreakOverlayHost({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
    required this.matchTitle,
    this.onVisualChange,
  });

  final InningsBreakSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;
  final String matchTitle;
  final VoidCallback? onVisualChange;

  @override
  Widget build(BuildContext context) {
    final tokens = ScorebugTokens.fromTheme(theme);

    if (landscape) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final scale = InningsBreakVisuals.scaleFor(
            constraints.maxWidth,
            true,
          );
          final topInset =
              LandscapeScorebugLayout.topHeaderReservedHeight(scale);
          final horizontalInset =
              LandscapeScorebugLayout.overlayHorizontalInset(scale);

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
              ),
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
                top: topInset,
                left: horizontalInset,
                right: 28 * scale,
                bottom: 20 * scale,
                child: snapshot.target > 0
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 22,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: InningsBreakFirstInningsPanel(
                                snapshot: snapshot,
                                tokens: tokens,
                                scale: scale,
                                landscape: true,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 56,
                            child: Center(
                              child: InningsBreakOverlay(
                                snapshot: snapshot,
                                theme: theme,
                                landscape: true,
                                onVisualChange: onVisualChange,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 22,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: InningsBreakTargetPanel(
                                snapshot: snapshot,
                                tokens: tokens,
                                scale: scale,
                                landscape: true,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: InningsBreakOverlay(
                          snapshot: snapshot,
                          theme: theme,
                          landscape: true,
                          onVisualChange: onVisualChange,
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
        final scale = InningsBreakVisuals.scaleFor(constraints.maxWidth, false);
        final topInset = PortraitScorebugLayout.topHeaderReservedHeight(scale);

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
            ),
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
            Positioned(
              top: topInset,
              left: InningsBreakVisuals.portraitHorizontalInset(scale),
              right: InningsBreakVisuals.portraitHorizontalInset(scale),
              bottom: 12 * scale,
              child: Column(
                children: [
                  if (snapshot.target > 0) ...[
                    Padding(
                      padding: EdgeInsets.only(bottom: 10 * scale),
                      child: InningsBreakTargetPanel(
                        snapshot: snapshot,
                        tokens: tokens,
                        scale: scale,
                        landscape: false,
                        compact: true,
                      ),
                    ),
                  ],
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: InningsBreakOverlay(
                        snapshot: snapshot,
                        theme: theme,
                        landscape: false,
                        onVisualChange: onVisualChange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
