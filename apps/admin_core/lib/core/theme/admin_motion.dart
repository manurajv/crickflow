import 'package:flutter/material.dart';

/// Motion tokens — subtle, purposeful, never decorative noise.
abstract final class AdminMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration page = Duration(milliseconds: 280);

  static const Curve standard = Curves.easeInOut;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeOutBack;

  static Widget fadeSlide({
    required Animation<double> animation,
    required Widget child,
    Offset begin = const Offset(0, 0.02),
  }) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: enter),
        ),
        child: child,
      ),
    );
  }
}
