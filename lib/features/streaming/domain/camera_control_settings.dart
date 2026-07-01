import 'package:equatable/equatable.dart';

/// Advanced camera controls — persisted in [StreamStudioConfig].
/// Native wiring is incremental; unsupported fields are no-ops on device.
class CameraControlSettings extends Equatable {
  const CameraControlSettings({
    this.exposureCompensation = 0,
    this.focusLocked = false,
    this.tapToFocusEnabled = true,
    this.whiteBalance = CameraWhiteBalance.auto,
    this.hdrEnabled = false,
    this.stabilizationEnabled = true,
    this.manualFocusDistance,
  });

  final double exposureCompensation;
  final bool focusLocked;
  final bool tapToFocusEnabled;
  final CameraWhiteBalance whiteBalance;
  final bool hdrEnabled;
  final bool stabilizationEnabled;
  final double? manualFocusDistance;

  CameraControlSettings copyWith({
    double? exposureCompensation,
    bool? focusLocked,
    bool? tapToFocusEnabled,
    CameraWhiteBalance? whiteBalance,
    bool? hdrEnabled,
    bool? stabilizationEnabled,
    double? manualFocusDistance,
  }) {
    return CameraControlSettings(
      exposureCompensation: exposureCompensation ?? this.exposureCompensation,
      focusLocked: focusLocked ?? this.focusLocked,
      tapToFocusEnabled: tapToFocusEnabled ?? this.tapToFocusEnabled,
      whiteBalance: whiteBalance ?? this.whiteBalance,
      hdrEnabled: hdrEnabled ?? this.hdrEnabled,
      stabilizationEnabled: stabilizationEnabled ?? this.stabilizationEnabled,
      manualFocusDistance: manualFocusDistance ?? this.manualFocusDistance,
    );
  }

  @override
  List<Object?> get props => [
        exposureCompensation,
        focusLocked,
        tapToFocusEnabled,
        whiteBalance,
        hdrEnabled,
        stabilizationEnabled,
      ];
}

enum CameraWhiteBalance {
  auto,
  daylight,
  cloudy,
  tungsten,
  fluorescent,
}

extension CameraWhiteBalanceX on CameraWhiteBalance {
  String get label => switch (this) {
        CameraWhiteBalance.auto => 'Auto',
        CameraWhiteBalance.daylight => 'Daylight',
        CameraWhiteBalance.cloudy => 'Cloudy',
        CameraWhiteBalance.tungsten => 'Tungsten',
        CameraWhiteBalance.fluorescent => 'Fluorescent',
      };
}
