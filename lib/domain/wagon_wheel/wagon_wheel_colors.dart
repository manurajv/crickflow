import 'package:flutter/material.dart';
import '../../data/models/wagon_wheel_data.dart';

/// Broadcast-style run colours for wagon wheel shot lines.
class WagonWheelColors {
  WagonWheelColors._();

  static const Color single = Color(0xFF43A047);
  static const Color doubleRun = Color(0xFF1E88E5);
  static const Color triple = Color(0xFF8E24AA);
  static const Color four = Color(0xFFFF9800);
  static const Color five = Color(0xFFE91E63);
  static const Color six = Color(0xFFE53935);
  static const Color dot = Color(0xFF9E9E9E);
  static const Color wicket = Color(0xFF212121);

  static Color forShotType(WagonWheelShotType type) => switch (type) {
        WagonWheelShotType.single => single,
        WagonWheelShotType.double => doubleRun,
        WagonWheelShotType.triple => triple,
        WagonWheelShotType.four => four,
        WagonWheelShotType.five => five,
        WagonWheelShotType.six => six,
        WagonWheelShotType.dot => dot,
        WagonWheelShotType.wicket => wicket,
      };

  static Color forBatsmanRuns(int runs) =>
      forShotType(WagonWheelShotType.fromBatsmanRuns(runs));
}
