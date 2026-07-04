import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../data/models/stream_overlay_theme.dart';
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
  Animation<double>? _opacity;

  @override
  void initState() {
    super.initState();
    if (widget.forBurnInCapture) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 360),
    );
    _controller = controller;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.65, 1, curve: Curves.easeIn),
    );

    unawaited(controller.forward());
    Future<void>.delayed(widget.event.duration, () async {
      if (!mounted || _controller == null) return;
      await _controller!.reverse();
      widget.onFinished?.call();
    });
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

    if (widget.forBurnInCapture || _controller == null) {
      return content;
    }

    return SlideTransition(
      position: _slide!,
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(_opacity!),
        child: content,
      ),
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
