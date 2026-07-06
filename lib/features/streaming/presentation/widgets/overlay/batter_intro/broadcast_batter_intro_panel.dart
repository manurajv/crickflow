import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/batter_intro_profile.dart';
import '../../../../data/models/stream_overlay_theme.dart';
import '../../../providers/player_intro_lookup.dart';
import '../../../providers/streaming_studio_providers.dart';
import '../events/broadcast_event_anim.dart';
import 'batter_intro_career_card.dart';
import '../scorebug/scorebug_tokens.dart';

/// TV-style batter career card — slides in from the left for ~5 seconds.
class BroadcastBatterIntroPanel extends ConsumerStatefulWidget {
  const BroadcastBatterIntroPanel({
    super.key,
    required this.matchId,
    required this.event,
    required this.tokens,
    required this.landscape,
    required this.scale,
    this.maxHeight,
    this.onFinished,
    this.forBurnInCapture = false,
  });

  final String matchId;
  final StreamEventOverlay event;
  final ScorebugTokens tokens;
  final bool landscape;
  final double scale;
  final double? maxHeight;
  final VoidCallback? onFinished;
  final bool forBurnInCapture;

  @override
  ConsumerState<BroadcastBatterIntroPanel> createState() =>
      _BroadcastBatterIntroPanelState();
}

class _BroadcastBatterIntroPanelState
    extends ConsumerState<BroadcastBatterIntroPanel>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<Offset>? _slide;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final controller = AnimationController(
      vsync: this,
      duration: BroadcastEventAnim.defaultEnter,
      reverseDuration: BroadcastEventAnim.defaultExit,
    );
    _controller = controller;
    _slide = Tween<Offset>(
      begin: Offset(widget.landscape ? -1.08 : -1.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    unawaited(
      BroadcastEventAnim.runSequence(
        controller: controller,
        hold: widget.event.duration,
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lookup = PlayerIntroLookup(
      matchId: widget.matchId,
      playerId: widget.event.playerId,
      fallbackName: widget.event.playerName,
    );
    final profileAsync = ref.watch(batterIntroProfileProvider(lookup));
    final profile = profileAsync.valueOrNull ??
        BatterIntroProfile(playerName: widget.event.playerName);

    final card = BatterIntroCareerCard(
      profile: profile,
      tokens: widget.tokens,
      scale: widget.scale,
      landscape: widget.landscape,
      maxHeight: widget.maxHeight,
    );

    if (_controller == null) {
      return card;
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        return Opacity(
          opacity: BroadcastEventAnim.exitAwareOpacity(_controller!),
          child: SlideTransition(
            position: _slide!,
            child: child,
          ),
        );
      },
      child: card,
    );
  }
}
