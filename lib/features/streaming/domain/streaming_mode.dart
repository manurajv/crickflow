/// How the match is broadcast from CrickFlow.
enum StreamingMode {
  /// Phone camera → hardware encoder → RTMP (default).
  nativeCamera,

  /// External encoder (OBS, vMix, etc.) receives RTMP credentials from the app.
  externalEncoder,
}

extension StreamingModeX on StreamingMode {
  String get label => switch (this) {
        StreamingMode.nativeCamera => 'Native camera',
        StreamingMode.externalEncoder => 'OBS / external encoder',
      };

  String get description => switch (this) {
        StreamingMode.nativeCamera =>
          'Stream directly from this device with built-in overlays.',
        StreamingMode.externalEncoder =>
          'Use OBS or another encoder. CrickFlow provides RTMP URL, stream key, and overlay browser source.',
      };

  bool get usesDeviceCamera => this == StreamingMode.nativeCamera;
}
