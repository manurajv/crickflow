import 'package:flutter/material.dart';

import '../../../../data/models/post_match_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../../../providers/post_match_controller.dart';
import '../scorebug/landscape/landscape_scorebug_layout.dart';
import '../scorebug/landscape/landscape_top_header.dart';
import '../scorebug/portrait/portrait_scorebug_layout.dart';
import '../scorebug/portrait/portrait_top_header.dart';
import '../scorebug/scorebug_tokens.dart';
import '../innings_break/innings_break_side_panels.dart';
import 'post_match_summary_screen.dart';
import 'post_match_thank_you_screen.dart';

/// Post-match presentation — scorebug header/LIVE only; centered summary card.
class PostMatchOverlayHost extends StatelessWidget {
  const PostMatchOverlayHost({
    super.key,
    required this.snapshot,
    required this.phase,
    required this.theme,
    required this.landscape,
    required this.matchTitle,
    this.onVisualChange,
  });

  final PostMatchSnapshot snapshot;
  final PostMatchPhase phase;
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
                right: horizontalInset,
                bottom: 20 * scale,
                child: Align(
                  alignment: Alignment.center,
                  child: _cardForPhase(scale),
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
              child: Align(
                alignment: Alignment.center,
                child: _cardForPhase(scale),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cardForPhase(double scale) {
    return switch (phase) {
      PostMatchPhase.matchSummary => PostMatchSummaryScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      PostMatchPhase.thankYou => PostMatchThankYouScreen(
          snapshot: snapshot,
          theme: theme,
          landscape: landscape,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
