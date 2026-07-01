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

enum StreamOrientationMode {
  portrait,
  landscapeLeft,
  landscapeRight,
  auto,
}

enum StreamResolutionPreset {
  p480,
  p720,
  p1080,
  p1440,
  p4k,
}

enum StreamFps { fps24, fps30, fps60 }

enum StreamBitrateMode { adaptive, manual }

enum StreamLatencyPreset {
  ultraLow,
  low,
  normal,
  highQuality,
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
        StreamEventOverlayType.wicket ||
        StreamEventOverlayType.hugeSix ||
        StreamEventOverlayType.boundaryFour ||
        StreamEventOverlayType.hatTrick ||
        StreamEventOverlayType.century ||
        StreamEventOverlayType.fiftyRuns =>
          const Duration(seconds: 5),
        StreamEventOverlayType.matchFinished ||
        StreamEventOverlayType.victory ||
        StreamEventOverlayType.playerOfMatch ||
        StreamEventOverlayType.tournamentWinner =>
          const Duration(seconds: 8),
        _ => const Duration(seconds: 4),
      };
}
