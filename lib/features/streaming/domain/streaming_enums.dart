/// Live streaming studio enums — kept separate from core [enums.dart].
library;

enum StreamPlatform { youtube, facebook, twitch, customRtmp }

/// Platforms with working OAuth or manual RTMP in the current release.
const kImplementedStreamPlatforms = <StreamPlatform>[
  StreamPlatform.youtube,
  StreamPlatform.facebook,
  StreamPlatform.customRtmp,
];

enum StreamVisibility { public, unlisted, private }

/// How the user configures their broadcast destination.
enum StreamBroadcastSetupMode {
  /// Link account, create events, title/description (YouTube).
  automatic,
  /// Paste RTMP URL and stream key only.
  manual,
}

extension StreamBroadcastSetupModeX on StreamBroadcastSetupMode {
  String get label => switch (this) {
        StreamBroadcastSetupMode.automatic => 'Automatic',
        StreamBroadcastSetupMode.manual => 'Manual',
      };

  String get subtitle => switch (this) {
        StreamBroadcastSetupMode.automatic =>
          'Link YouTube and create events in the app',
        StreamBroadcastSetupMode.manual =>
          'Paste RTMP server and stream key from your platform',
      };
}

/// Broadcast orientation — portrait or landscape only.
enum StreamOrientationMode {
  portrait,
  landscape,
}

/// Orientations available in stream studio UI.
const kStreamStudioOrientations = <StreamOrientationMode>[
  StreamOrientationMode.portrait,
  StreamOrientationMode.landscape,
];

/// Maps legacy persisted values to the two supported modes.
StreamOrientationMode parseStreamOrientation(String? raw) {
  return switch (raw) {
    'landscape' || 'landscapeLeft' || 'landscapeRight' => StreamOrientationMode.landscape,
    _ => StreamOrientationMode.portrait,
  };
}

extension StreamOrientationModeX on StreamOrientationMode {
  String get studioLabel => switch (this) {
        StreamOrientationMode.portrait => 'Portrait',
        StreamOrientationMode.landscape => 'Landscape',
      };

  /// Native encoder / Pedro orientation mode string.
  String get nativeModeName => name;

  StreamOrientationMode get toggled => switch (this) {
        StreamOrientationMode.portrait => StreamOrientationMode.landscape,
        StreamOrientationMode.landscape => StreamOrientationMode.portrait,
      };
}

enum StreamResolutionPreset {
  p480,
  p720,
  p1080,
  p1440,
  p4k,
}

/// Resolutions offered in the studio picker — camera captures natively up to 1080p.
const kSupportedStreamResolutions = <StreamResolutionPreset>[
  StreamResolutionPreset.p480,
  StreamResolutionPreset.p720,
  StreamResolutionPreset.p1080,
];

/// Resolutions when 1080p isn't reliable (manual RTMP keys — YouTube manual,
/// Facebook, custom RTMP — where the platform stream is tied to a fixed ingest).
const kManualStreamResolutions = <StreamResolutionPreset>[
  StreamResolutionPreset.p480,
  StreamResolutionPreset.p720,
];

/// Default / recommended resolution shown in the studio picker.
const kRecommendedStreamResolution = StreamResolutionPreset.p720;

/// 1080p is only reliable on YouTube automatic (fresh `variable` ingest).
/// Manual RTMP destinations use the platform's fixed stream and can stall at 1080p.
bool streamSupports1080p({
  required StreamPlatform platform,
  required StreamBroadcastSetupMode setupMode,
}) =>
    platform == StreamPlatform.youtube &&
    setupMode == StreamBroadcastSetupMode.automatic;

/// Resolutions offered for the given destination/setup mode.
List<StreamResolutionPreset> supportedStreamResolutionsFor({
  required StreamPlatform platform,
  required StreamBroadcastSetupMode setupMode,
}) =>
    streamSupports1080p(platform: platform, setupMode: setupMode)
        ? kSupportedStreamResolutions
        : kManualStreamResolutions;

enum StreamFps { fps24, fps30, fps60 }

enum StreamBitrateMode { adaptive, manual }

enum StreamLatencyPreset {
  ultraLow,
  low,
  normal,
  highQuality,
}

extension StreamLatencyPresetX on StreamLatencyPreset {
  String get label => switch (this) {
        StreamLatencyPreset.ultraLow => 'Ultra low',
        StreamLatencyPreset.low => 'Low',
        StreamLatencyPreset.normal => 'Normal',
        StreamLatencyPreset.highQuality => 'High quality',
      };

  /// Tunes encoder bitrate — lower latency uses a leaner bitrate profile.
  int adjustBitrateKbps(int baseKbps) => switch (this) {
        StreamLatencyPreset.ultraLow => (baseKbps * 0.82).round().clamp(800, 20000),
        StreamLatencyPreset.low => (baseKbps * 0.92).round(),
        StreamLatencyPreset.normal => baseKbps,
        StreamLatencyPreset.highQuality => (baseKbps * 1.1).round(),
      };
}

extension StreamFpsX on StreamFps {
  String get label => switch (this) {
        StreamFps.fps24 => '24 fps',
        StreamFps.fps30 => '30 fps',
        StreamFps.fps60 => '60 fps',
      };

  int get value => switch (this) {
        StreamFps.fps24 => 24,
        StreamFps.fps30 => 30,
        StreamFps.fps60 => 60,
      };
}

extension StreamBitrateModeX on StreamBitrateMode {
  String get label => switch (this) {
        StreamBitrateMode.adaptive => 'Adaptive',
        StreamBitrateMode.manual => 'Manual',
      };
}

enum StreamVideoCodec { h264, h265 }

enum StreamOverlayLayout { full, compact, minimal }

enum StreamConnectionQuality { excellent, good, fair, poor, unknown }

enum StreamEventOverlayType {
  matchStarting,
  tossWinner,
  playingXi,
  powerplay,
  powerplayEnd,
  strategicTimeout,
  newBatter,
  newBowler,
  boundaryFour,
  hugeSix,
  wicket,
  hatTrick,
  fiftyRuns,
  century,
  fiveWicketHaul,
  partnership,
  drinksBreak,
  inningsBreak,
  target,
  lastOver,
  lastWicket,
  superOver,
  rainDelay,
  matchFinished,
  victory,
  playerOfMatch,
  tournamentWinner,
  drsIndicator,
}

enum ReplayMarkerKind {
  wicket,
  six,
  four,
  century,
  milestone,
  custom,
}

extension StreamResolutionPresetX on StreamResolutionPreset {
  ResolutionPresetMapping get mapping => switch (this) {
        StreamResolutionPreset.p480 => (
            rtmp: 'medium',
            label: '480p',
          ),
        StreamResolutionPreset.p720 => (
            rtmp: 'high',
            label: '720p',
          ),
        StreamResolutionPreset.p1080 => (
            rtmp: 'veryHigh',
            label: '1080p',
          ),
        StreamResolutionPreset.p1440 => (
            rtmp: 'ultraHigh',
            label: '1440p',
          ),
        StreamResolutionPreset.p4k => (
            rtmp: 'max',
            label: '4K',
          ),
      };
}

typedef ResolutionPresetMapping = ({String rtmp, String label});

extension StreamPlatformX on StreamPlatform {
  String get label => switch (this) {
        StreamPlatform.youtube => 'YouTube',
        StreamPlatform.facebook => 'Facebook',
        StreamPlatform.twitch => 'Twitch',
        StreamPlatform.customRtmp => 'Custom RTMP',
      };

  String get defaultRtmpUrl => switch (this) {
        StreamPlatform.youtube => 'rtmp://a.rtmp.youtube.com/live2',
        StreamPlatform.facebook => 'rtmps://live-api-s.facebook.com:443/rtmp/',
        StreamPlatform.twitch => 'rtmp://live.twitch.tv/app/',
        StreamPlatform.customRtmp => '',
      };
}

extension StreamEventOverlayTypeX on StreamEventOverlayType {
  String get title => switch (this) {
        StreamEventOverlayType.matchStarting => 'Match Starting',
        StreamEventOverlayType.tossWinner => 'Toss',
        StreamEventOverlayType.playingXi => 'Playing XI',
        StreamEventOverlayType.powerplay => 'Powerplay',
        StreamEventOverlayType.powerplayEnd => 'Powerplay End',
        StreamEventOverlayType.strategicTimeout => 'Strategic Timeout',
        StreamEventOverlayType.newBatter => 'New Batter',
        StreamEventOverlayType.newBowler => 'New Bowler',
        StreamEventOverlayType.boundaryFour => 'FOUR!',
        StreamEventOverlayType.hugeSix => 'SIX!',
        StreamEventOverlayType.wicket => 'WICKET!',
        StreamEventOverlayType.hatTrick => 'HAT TRICK!',
        StreamEventOverlayType.fiftyRuns => 'FIFTY!',
        StreamEventOverlayType.century => 'CENTURY!',
        StreamEventOverlayType.fiveWicketHaul => 'FIVE WICKETS!',
        StreamEventOverlayType.partnership => 'Partnership',
        StreamEventOverlayType.drinksBreak => 'Drinks Break',
        StreamEventOverlayType.inningsBreak => 'Innings Break',
        StreamEventOverlayType.target => 'Target Set',
        StreamEventOverlayType.lastOver => 'Final Over',
        StreamEventOverlayType.lastWicket => 'Last Wicket',
        StreamEventOverlayType.superOver => 'Super Over',
        StreamEventOverlayType.rainDelay => 'Rain Delay',
        StreamEventOverlayType.matchFinished => 'Match Finished',
        StreamEventOverlayType.victory => 'Victory!',
        StreamEventOverlayType.playerOfMatch => 'Player of the Match',
        StreamEventOverlayType.tournamentWinner => 'Champions!',
        StreamEventOverlayType.drsIndicator => 'DRS',
      };

  Duration get defaultDuration => switch (this) {
        StreamEventOverlayType.newBowler ||
        StreamEventOverlayType.newBatter =>
          const Duration(seconds: 5),
        StreamEventOverlayType.wicket ||
        StreamEventOverlayType.hugeSix ||
        StreamEventOverlayType.boundaryFour ||
        StreamEventOverlayType.hatTrick ||
        StreamEventOverlayType.century ||
        StreamEventOverlayType.fiftyRuns =>
          const Duration(seconds: 4),
        StreamEventOverlayType.matchFinished ||
        StreamEventOverlayType.victory ||
        StreamEventOverlayType.playerOfMatch ||
        StreamEventOverlayType.tournamentWinner =>
          const Duration(seconds: 8),
        _ => const Duration(seconds: 4),
      };
}
