import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/models/stream_overlay_theme.dart';
import '../../../domain/streaming_enums.dart';

/// Animated broadcast graphic for wickets, boundaries, milestones, etc.
class StreamEventOverlayWidget extends StatefulWidget {
  const StreamEventOverlayWidget({
    super.key,
    required this.overlay,
    this.onFinished,
    this.forBurnInCapture = false,
  });

  final StreamEventOverlay overlay;
  final VoidCallback? onFinished;
  /// Static frame for RTMP PNG capture (no animation / auto-dismiss).
  final bool forBurnInCapture;

  @override
  State<StreamEventOverlayWidget> createState() =>
      _StreamEventOverlayWidgetState();
}

class _StreamEventOverlayWidgetState extends State<StreamEventOverlayWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scale;
  Animation<double>? _opacity;

  @override
  void initState() {
    super.initState();
    if (widget.forBurnInCapture) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller = controller;
    _scale = CurvedAnimation(parent: controller, curve: Curves.elasticOut);
    _opacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.7, 1, curve: Curves.easeOut),
    );
    controller.forward();
    Future<void>.delayed(widget.overlay.duration, () async {
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
    final color = _colorForType(widget.overlay.type);
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.overlay.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          if (widget.overlay.subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.overlay.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.forBurnInCapture || _controller == null) {
      return IgnorePointer(child: Center(child: card));
    }

    return IgnorePointer(
      child: Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.2, end: 1).animate(_scale!),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(_opacity!),
            child: card,
          ),
        ),
      ),
    );
  }

  Color _colorForType(StreamEventOverlayType type) {
    return switch (type) {
      StreamEventOverlayType.wicket => AppColors.accentRed,
      StreamEventOverlayType.boundaryFour => AppColors.primaryBlue,
      StreamEventOverlayType.hugeSix => AppColors.gold,
      StreamEventOverlayType.century ||
      StreamEventOverlayType.fiftyRuns =>
        AppColors.accentGreen,
      StreamEventOverlayType.matchFinished ||
      StreamEventOverlayType.tournamentWinner =>
        AppColors.goldDark,
      _ => AppColors.primaryBlueLight,
    };
  }
}
