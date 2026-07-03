import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/streaming_enums.dart';
import 'broadcast_event_styles.dart';

/// Animated landscape (16:9) broadcast event graphic — center banner style.
class LandscapeEventGraphic extends StatefulWidget {
  const LandscapeEventGraphic({
    super.key,
    required this.type,
    required this.title,
    this.subtitle = '',
    this.duration = const Duration(seconds: 4),
    this.onFinished,
    this.forBurnInCapture = false,
  });

  final StreamEventOverlayType type;
  final String title;
  final String subtitle;
  final Duration duration;
  final VoidCallback? onFinished;
  final bool forBurnInCapture;

  @override
  State<LandscapeEventGraphic> createState() => _LandscapeEventGraphicState();
}

class _LandscapeEventGraphicState extends State<LandscapeEventGraphic>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<Offset>? _slide;
  Animation<double>? _fade;
  Animation<double>? _scale;

  @override
  void initState() {
    super.initState();
    if (widget.forBurnInCapture) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 450),
    );
    _controller = controller;
    _slide = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.6, 1, curve: Curves.easeIn),
    );
    _scale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
    );

    unawaited(controller.forward());
    Future<void>.delayed(widget.duration, () async {
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
      type: widget.type,
      title: widget.title,
    );
    final card = BroadcastEventCard(
      style: style,
      title: style.label,
      subtitle: widget.subtitle,
      landscape: true,
    );

    if (widget.forBurnInCapture || _controller == null) {
      return IgnorePointer(child: Center(child: card));
    }

    return IgnorePointer(
      child: Center(
        child: SlideTransition(
          position: _slide!,
          child: ScaleTransition(
            scale: _scale!,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(_fade!),
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}
