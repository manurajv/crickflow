import 'dart:async';

import 'package:flutter/material.dart';

/// Enter → hold → exit sequencing for broadcast event graphics.
class BroadcastEventAnim {
  BroadcastEventAnim._();

  static const Duration defaultEnter = Duration(milliseconds: 420);
  static const Duration defaultExit = Duration(milliseconds: 360);

  static Duration totalSequenceDuration(
    Duration hold, {
    Duration enter = defaultEnter,
    Duration exit = defaultExit,
  }) =>
      enter + hold + exit;

  static Future<void> runSequence({
    required AnimationController controller,
    required Duration hold,
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

  /// Full opacity while entering and holding; fade only while reversing out.
  static double exitAwareOpacity(AnimationController controller) {
    return controller.status == AnimationStatus.reverse ? controller.value : 1;
  }
}
