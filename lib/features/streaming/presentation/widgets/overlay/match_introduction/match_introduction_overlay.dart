import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../data/models/match_introduction_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../scorebug/broadcast_live_branding.dart';
import '../scorebug/broadcast_match_title_chip.dart';
import '../scorebug/scorebug_tokens.dart';
import 'captain_presentation_card.dart';
import 'match_introduction_anim.dart';
import 'match_introduction_bottom_band.dart';
import 'match_introduction_layout.dart';

/// Full-screen TV-style match introduction shown once when a stream goes live.
class MatchIntroductionOverlay extends StatefulWidget {
  const MatchIntroductionOverlay({
    super.key,
    required this.snapshot,
    required this.theme,
    required this.landscape,
    this.onFinished,
    this.onVisualChange,
  });

  final MatchIntroductionSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;
  final VoidCallback? onFinished;
  final VoidCallback? onVisualChange;

  @override
  State<MatchIntroductionOverlay> createState() =>
      _MatchIntroductionOverlayState();
}

class _MatchIntroductionOverlayState extends State<MatchIntroductionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MatchIntroductionAnim.enter,
      reverseDuration: MatchIntroductionAnim.exit,
    )..addListener(() => widget.onVisualChange?.call());

    unawaited(
      MatchIntroductionAnim.runSequence(
        controller: _controller,
        isMounted: () => mounted,
        onFinished: _finish,
      ),
    );
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ScorebugTokens.fromTheme(widget.theme);
    final snapshot = widget.snapshot;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final metrics = MatchIntroductionMetrics.compute(
          landscape: widget.landscape,
          size: size,
          hasVenue: snapshot.hasVenueSection,
          hasSchedule: snapshot.hasSchedule,
          hasTournament: snapshot.tournamentLabel.trim().isNotEmpty,
        );
        final scale = metrics.scale;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final masterOpacity =
                MatchIntroductionAnim.exitAwareMasterOpacity(_controller);
            final darken = MatchIntroductionAnim.intervalOpacity(
              _controller,
              start: 0,
              end: 0.18,
            ).clamp(0.0, 0.52);

            final headerOpacity = MatchIntroductionAnim.intervalOpacity(
              _controller,
              start: 0.04,
              end: 0.16,
            );
            final captainsOpacity = MatchIntroductionAnim.intervalOpacity(
              _controller,
              start: 0.08,
              end: 0.22,
            );
            final bottomOpacity = MatchIntroductionAnim.intervalOpacity(
              _controller,
              start: 0.14,
              end: 0.30,
            );

            final leftSlide = MatchIntroductionAnim.intervalSlide(
              _controller,
              start: 0.06,
              end: 0.24,
              begin: Offset(-36 * scale, 0),
            );
            final rightSlide = MatchIntroductionAnim.intervalSlide(
              _controller,
              start: 0.06,
              end: 0.24,
              begin: Offset(36 * scale, 0),
            );
            final bottomSlide = MatchIntroductionAnim.intervalSlide(
              _controller,
              start: 0.14,
              end: 0.32,
              begin: Offset(0, 28 * scale),
            );

            final bottomBand = MatchIntroductionBottomBand(
              snapshot: snapshot,
              tokens: tokens,
              scale: scale,
              opacity: bottomOpacity,
              slideOffset: bottomSlide,
              compact: !widget.landscape,
            );

            return Opacity(
              opacity: masterOpacity,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 6 * scale,
                        sigmaY: 6 * scale,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.42 + darken * 0.2),
                          Colors.black.withValues(alpha: 0.58 + darken * 0.18),
                          Colors.black.withValues(alpha: 0.78 + darken * 0.12),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    minimum: EdgeInsets.zero,
                    bottom: false,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MatchIntroductionMetrics
                                    .bottomBandMaxWidth(
                                  landscape: widget.landscape,
                                  screenWidth: size.width,
                                  scale: scale,
                                ),
                              ),
                              child: bottomBand,
                            ),
                          ),
                        ),
                        Positioned(
                          left: metrics.horizontalInset,
                          right: metrics.horizontalInset,
                          top: metrics.captainsTop,
                          bottom: metrics.estimatedBottomBandHeight -
                              metrics.captainsBottomOverlap,
                          child: Align(
                            alignment: const Alignment(0, -0.18),
                            child: Opacity(
                              opacity: captainsOpacity,
                              child: CaptainsFaceOffRow(
                                snapshot: snapshot,
                                tokens: tokens,
                                scale: scale,
                                photoHeight: metrics.photoHeight,
                                photoWidth: metrics.photoWidth,
                                photoGap: metrics.photoGap,
                                opacity: 1,
                                leftSlide: leftSlide,
                                rightSlide: rightSlide,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: widget.landscape ? 20 * scale : 10 * scale,
                          right: widget.landscape ? 20 * scale : 10 * scale,
                          top: metrics.headerTop,
                          child: Opacity(
                            opacity: headerOpacity,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: BroadcastMatchTitleChip(
                                    title: snapshot.matchTitle,
                                    tokens: tokens,
                                    scale: scale,
                                    landscape: widget.landscape,
                                  ),
                                ),
                                SizedBox(width: 10 * scale),
                                Opacity(
                                  opacity: 1,
                                  child: BroadcastLiveBranding(
                                    tokens: tokens,
                                    scale: scale,
                                    landscape: widget.landscape,
                                    logoUrl: snapshot.crickflowLogoUrl,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
