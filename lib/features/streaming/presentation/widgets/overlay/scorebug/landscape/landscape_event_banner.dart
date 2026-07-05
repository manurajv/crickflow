import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../data/models/stream_overlay_theme.dart';
import '../../events/broadcast_event_anim.dart';
import '../../events/broadcast_event_styles.dart';
import '../scorebug_tokens.dart';

/// Center event area — replaces batsmen panel during broadcast moments.
class LandscapeEventBanner extends StatefulWidget {
  const LandscapeEventBanner({
    super.key,
    required this.event,
    required this.tokens,
    required this.scale,
    this.forBurnInCapture = false,
    this.onFinished,
  });

  final StreamEventOverlay event;
  final ScorebugTokens tokens;
  final double scale;
  final bool forBurnInCapture;
  final VoidCallback? onFinished;

  @override
  State<LandscapeEventBanner> createState() => _LandscapeEventBannerState();
}

class _LandscapeEventBannerState extends State<LandscapeEventBanner>
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
      begin: const Offset(0, 0.35),
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
    final style = BroadcastEventStyles.forOverlay(
      type: widget.event.type,
      title: widget.event.title,
    );
    final content = _EventContent(style: style, scale: widget.scale);

    if (_controller == null) {
      return content;
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
      child: content,
    );
  }
}

class _EventContent extends StatelessWidget {
  const _EventContent({required this.style, required this.scale});

  final BroadcastEventStyle style;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isBoundary = style.label == 'FOUR' || style.label == 'SIX';
    final isWicket = style.label == 'WICKET';

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBoundary
              ? [const Color(0xFFFFC107), const Color(0xFFFFA000)]
              : [
                  style.color,
                  Color.lerp(style.color, Colors.black, 0.22)!,
                ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (style.patternChar != null)
            Positioned.fill(
              child: EventPatternBackground(
                char: style.patternChar!,
                color: isBoundary ? Colors.black : style.accent,
              ),
            ),
          Center(
            child: Text(
              style.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isBoundary ? Colors.black : Colors.white,
                fontSize: 18 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: isWicket ? 4 : 3,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
