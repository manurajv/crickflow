import 'dart:async';

import 'package:flutter/material.dart';

/// Timing and helpers for the pre-match broadcast introduction sequence.
class MatchIntroductionAnim {
  MatchIntroductionAnim._();

  static const Duration enter = Duration(milliseconds: 900);
  static const Duration hold = Duration(seconds: 10);
  static const Duration exit = Duration(milliseconds: 850);
  static const Duration darken = Duration(milliseconds: 700);

  static Duration get totalDuration => enter + hold + exit;

  static Future<void> runSequence({
    required AnimationController controller,
    required bool Function() isMounted,
    VoidCallback? onFinished,
  }) async {
    await controller.forward();
    if (!isMounted()) return;
    await Future<void>.delayed(hold);
    if (!isMounted()) return;
    await controller.reverse();
    if (!isMounted()) return;
    onFinished?.call();
  }

  static double intervalOpacity(
    AnimationController controller, {
    required double start,
    required double end,
  }) {
    if (controller.value <= start) return 0;
    if (controller.value >= end) return 1;
    return Curves.easeOutCubic.transform(
      (controller.value - start) / (end - start),
    );
  }

  static Offset intervalSlide(
    AnimationController controller, {
    required double start,
    required double end,
    required Offset begin,
  }) {
    if (controller.value <= start) return begin;
    if (controller.value >= end) return Offset.zero;
    final t = Curves.easeOutCubic.transform(
      (controller.value - start) / (end - start),
    );
    return Offset.lerp(begin, Offset.zero, t)!;
  }

  static double exitAwareMasterOpacity(AnimationController controller) {
    return controller.status == AnimationStatus.reverse ? controller.value : 1;
  }
}
