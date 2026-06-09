import 'package:equatable/equatable.dart';

/// Shot classification for wagon wheel analytics.
enum WagonWheelShotType {
  single,
  double,
  triple,
  four,
  five,
  six,
  dot,
  wicket;

  String get label => switch (this) {
        WagonWheelShotType.single => 'Single',
        WagonWheelShotType.double => 'Double',
        WagonWheelShotType.triple => 'Triple',
        WagonWheelShotType.four => 'Four',
        WagonWheelShotType.five => 'Five',
        WagonWheelShotType.six => 'Six',
        WagonWheelShotType.dot => 'Dot',
        WagonWheelShotType.wicket => 'Wicket',
      };

  static WagonWheelShotType fromBatsmanRuns(int runs) {
    return switch (runs) {
      0 => WagonWheelShotType.dot,
      1 => WagonWheelShotType.single,
      2 => WagonWheelShotType.double,
      3 => WagonWheelShotType.triple,
      4 => WagonWheelShotType.four,
      5 => WagonWheelShotType.five,
      6 => WagonWheelShotType.six,
      _ => WagonWheelShotType.single,
    };
  }
}

/// Percentage-based coordinates relative to the ground image (0–100).
///
/// Future AI / CV integrations can populate the same schema automatically.
class WagonWheelData extends Equatable {
  const WagonWheelData({
    this.enabled = true,
    required this.x,
    required this.y,
    this.shotType,
    this.source = WagonWheelSource.manual,
    this.confidence,
  });

  final bool enabled;
  final double x;
  final double y;
  final WagonWheelShotType? shotType;
  final WagonWheelSource source;
  /// 0–1 confidence for future AI-detected shots.
  final double? confidence;

  /// Pitch centre in percentage space (top-down broadcast view).
  static const double pitchCenterX = 50.0;
  static const double pitchCenterY = 50.0;

  factory WagonWheelData.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const WagonWheelData(x: pitchCenterX, y: pitchCenterY);
    }
    final shotRaw = map['shotType'] as String?;
    return WagonWheelData(
      enabled: map['enabled'] as bool? ?? true,
      x: (map['x'] as num?)?.toDouble() ?? pitchCenterX,
      y: (map['y'] as num?)?.toDouble() ?? pitchCenterY,
      shotType: shotRaw != null
          ? WagonWheelShotType.values.firstWhere(
              (e) => e.name == shotRaw.toLowerCase() || e.name == shotRaw,
              orElse: () => WagonWheelShotType.single,
            )
          : null,
      source: WagonWheelSource.values.firstWhere(
        (e) => e.name == (map['source'] as String? ?? 'manual'),
        orElse: () => WagonWheelSource.manual,
      ),
      confidence: (map['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'x': x,
        'y': y,
        if (shotType != null) 'shotType': shotType!.name,
        'source': source.name,
        if (confidence != null) 'confidence': confidence,
      };

  WagonWheelData copyWith({
    bool? enabled,
    double? x,
    double? y,
    WagonWheelShotType? shotType,
    WagonWheelSource? source,
    double? confidence,
  }) {
    return WagonWheelData(
      enabled: enabled ?? this.enabled,
      x: x ?? this.x,
      y: y ?? this.y,
      shotType: shotType ?? this.shotType,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  List<Object?> get props => [enabled, x, y, shotType, source, confidence];
}

enum WagonWheelSource {
  manual,
  aiBallTracking,
  computerVision,
  videoTracking,
  droneTracking,
}
