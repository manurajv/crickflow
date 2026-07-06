import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/batter_intro_profile.dart';
import '../../../../data/models/opening_batsmen_snapshot.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../../../providers/player_intro_lookup.dart';
import '../../../providers/streaming_studio_providers.dart';
import '../batter_intro/batter_intro_career_card.dart';
import '../events/broadcast_event_anim.dart';
import '../scorebug/broadcast_live_branding.dart';
import '../scorebug/broadcast_match_title_chip.dart';
import '../scorebug/scorebug_tokens.dart';

/// Five-second opening pair overlay — two batter intro cards side by side.
class OpeningBatsmenOverlay extends ConsumerStatefulWidget {
  const OpeningBatsmenOverlay({
    super.key,
    required this.matchId,
    required this.snapshot,
    required this.theme,
    required this.landscape,
    this.onFinished,
    this.onVisualChange,
  });

  final String matchId;
  final OpeningBatsmenSnapshot snapshot;
  final StreamOverlayTheme theme;
  final bool landscape;
  final VoidCallback? onFinished;
  final VoidCallback? onVisualChange;

  static const holdDuration = Duration(seconds: 5);

  @override
  ConsumerState<OpeningBatsmenOverlay> createState() =>
      _OpeningBatsmenOverlayState();
}

class _OpeningBatsmenOverlayState extends ConsumerState<OpeningBatsmenOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: BroadcastEventAnim.defaultEnter,
      reverseDuration: BroadcastEventAnim.defaultExit,
    )..addListener(() => widget.onVisualChange?.call());

    unawaited(
      BroadcastEventAnim.runSequence(
        controller: _controller,
        hold: OpeningBatsmenOverlay.holdDuration,
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
        final scale = widget.landscape
            ? (constraints.maxWidth / 1280).clamp(0.65, 1.35).toDouble()
            : (constraints.maxWidth / 360).clamp(0.78, 1.1).toDouble();
        final cardGap = widget.landscape ? 36 * scale : 26 * scale;
        final cardScale = scale * (widget.landscape ? 0.9 : 0.88);
        final cardMaxHeight = widget.landscape
            ? constraints.maxHeight * 0.58
            : constraints.maxHeight * 0.38;
        final headerBlock = (widget.landscape ? 58 : 52) * scale;

        final strikerLookup = PlayerIntroLookup(
          matchId: widget.matchId,
          playerId: snapshot.striker.playerId,
          fallbackName: snapshot.striker.fallbackName,
        );
        final nonStrikerLookup = PlayerIntroLookup(
          matchId: widget.matchId,
          playerId: snapshot.nonStriker.playerId,
          fallbackName: snapshot.nonStriker.fallbackName,
        );

        final strikerProfile =
            ref.watch(batterIntroProfileProvider(strikerLookup)).valueOrNull ??
                BatterIntroProfile(playerName: snapshot.striker.fallbackName);
        final nonStrikerProfile = ref
                .watch(batterIntroProfileProvider(nonStrikerLookup))
                .valueOrNull ??
            BatterIntroProfile(playerName: snapshot.nonStriker.fallbackName);

        final cards = FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              BatterIntroCareerCard(
                profile: strikerProfile,
                tokens: tokens,
                scale: cardScale,
                landscape: widget.landscape,
                maxHeight: widget.landscape ? cardMaxHeight : null,
              ),
              SizedBox(width: cardGap),
              BatterIntroCareerCard(
                profile: nonStrikerProfile,
                tokens: tokens,
                scale: cardScale,
                landscape: widget.landscape,
                maxHeight: widget.landscape ? cardMaxHeight : null,
              ),
            ],
          ),
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: BroadcastEventAnim.exitAwareOpacity(_controller),
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.38),
                  ),
                  SafeArea(
                    minimum: EdgeInsets.zero,
                    bottom: false,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: widget.landscape ? 20 * scale : 10 * scale,
                          right: widget.landscape ? 20 * scale : 10 * scale,
                          top: widget.landscape ? 8 * scale : 4 * scale,
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
                              BroadcastLiveBranding(
                                tokens: tokens,
                                scale: scale,
                                landscape: widget.landscape,
                                logoUrl: snapshot.crickflowLogoUrl.isNotEmpty
                                    ? snapshot.crickflowLogoUrl
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: headerBlock,
                          bottom: 0,
                          child: Align(
                            alignment: const Alignment(0, -0.28),
                            child: cards,
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
