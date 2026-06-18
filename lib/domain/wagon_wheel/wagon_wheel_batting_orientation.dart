import 'dart:ui';

import '../../data/models/match_model.dart';
import '../../data/models/wagon_wheel_data.dart';
import 'wagon_wheel_analytics_service.dart';
import 'wagon_wheel_filter.dart';

/// Single source of truth for handedness-adjusted wagon wheel coordinates.
///
/// Raw stored coordinates are never modified — transformations apply only when
/// rendering or calculating analytics.
class WagonWheelBattingOrientation {
  WagonWheelBattingOrientation._();

  static const double pitchCenterX = WagonWheelData.pitchCenterX;

  static bool isLeftHanded(String? battingStyle) {
    final normalized = (battingStyle ?? '').toLowerCase();
    return normalized.contains('left');
  }

  /// Mirror horizontally around the pitch centre for left-handed batters.
  static Offset displayCoordinate(
    double x,
    double y, {
    required bool leftHanded,
  }) {
    if (!leftHanded) return Offset(x, y);
    return Offset(100 - x, y);
  }

  /// Handedness-adjusted coordinates from raw x/y and [battingStyle].
  static Offset getAnalyticsCoordinatesFromStyle(
    double x,
    double y,
    String? battingStyle,
  ) {
    return displayCoordinate(
      x,
      y,
      leftHanded: isLeftHanded(battingStyle),
    );
  }

  /// Handedness-adjusted coordinates for a shot — use for all analytics.
  static Offset getAnalyticsCoordinates(
    WagonWheelShotPoint shot,
    Map<String, bool> leftHandedLookup, {
    String? fallbackBatterId,
    String? fallbackBattingStyle,
  }) {
    final leftHanded = leftHandedForShot(
      shot,
      leftHandedLookup,
      fallbackBatterId: fallbackBatterId,
      fallbackBattingStyle: fallbackBattingStyle,
    );
    return displayCoordinate(
      shot.wagonWheel.x,
      shot.wagonWheel.y,
      leftHanded: leftHanded,
    );
  }

  static bool showSideLabels(WagonWheelFilter filter) =>
      filter.batterId != null &&
      filter.bowlerId == null &&
      filter.teamId == null &&
      filter.tournamentId == null;

  static ({String left, String right}) sideLabels({required bool leftHanded}) {
    if (leftHanded) {
      return (left: 'LEG SIDE', right: 'OFF SIDE');
    }
    return (left: 'OFF SIDE', right: 'LEG SIDE');
  }

  /// Builds a player-id → left-handed lookup from frozen match setup snapshots.
  static Map<String, bool> leftHandedLookupFromMatches(List<MatchModel> matches) {
    final lookup = <String, bool>{};
    for (final match in matches) {
      final setup = match.setup;
      if (setup == null) continue;
      for (final player in [
        ...setup.teamAPlayingPlayers,
        ...setup.teamASubstitutePlayers,
        ...setup.teamBPlayingPlayers,
        ...setup.teamBSubstitutePlayers,
      ]) {
        lookup[player.id] = isLeftHanded(player.battingStyle);
      }
    }
    return lookup;
  }

  static Map<String, bool> enrichLeftHandedLookup(
    Map<String, bool> lookup, {
    String? batterId,
    String? battingStyle,
  }) {
    if (batterId == null ||
        battingStyle == null ||
        battingStyle.trim().isEmpty) {
      return lookup;
    }
    return {...lookup, batterId: isLeftHanded(battingStyle)};
  }

  static bool leftHandedForShot(
    WagonWheelShotPoint shot,
    Map<String, bool> lookup, {
    String? fallbackBatterId,
    String? fallbackBattingStyle,
  }) {
    final id = shot.batterId ?? fallbackBatterId;
    if (id != null && lookup.containsKey(id)) {
      return lookup[id]!;
    }
    if (fallbackBatterId != null &&
        shot.batterId == fallbackBatterId &&
        fallbackBattingStyle != null) {
      return isLeftHanded(fallbackBattingStyle);
    }
    return false;
  }

  /// Zone label from handedness-adjusted coordinates (top-striker RHB view).
  static String zoneLabel(double x, double y) {
    final h = x < 40
        ? 'Off'
        : x > 60
            ? 'Leg'
            : 'Straight';
    final v = y < 40
        ? 'Fine'
        : y > 60
            ? 'Long'
            : 'Mid';
    return '$h $v';
  }
}
