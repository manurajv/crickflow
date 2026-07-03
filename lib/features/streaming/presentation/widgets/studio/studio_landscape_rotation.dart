import 'package:flutter/material.dart';

/// Lays out [child] in landscape while the Activity stays portrait (camera untouched).
///
/// Used for scoreboard overlays and studio chrome when broadcast mode is landscape.
class StudioLandscapeRotation extends StatelessWidget {
  const StudioLandscapeRotation({
    super.key,
    required this.landscape,
    required this.child,
  });

  final bool landscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!landscape) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight;
        // RotatedBox swaps constraints for its child — avoids OverflowBox min/max inversion.
        return Center(
          child: RotatedBox(
            quarterTurns: 1,
            child: SizedBox(
              width: viewH,
              height: viewW,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
