import 'package:equatable/equatable.dart';

import '../../domain/camera_control_settings.dart';
import '../../domain/streaming_enums.dart';
import '../../domain/streaming_mode.dart';
import '../../domain/stream_credential_normalizer.dart';
/// Pre-live and in-session streaming configuration for a match.
class StreamStudioConfig extends Equatable {
  const StreamStudioConfig({
    this.title = '',
    this.description = '',
    this.category = 'Sports',
    this.visibility = StreamVisibility.public,
    this.language = 'en',
    this.tags = const [],
    this.scheduledAt,
    this.goLiveImmediately = true,
    this.broadcastSetupMode = StreamBroadcastSetupMode.automatic,
    this.platform = StreamPlatform.youtube,
    this.rtmpUrl = 'rtmp://a.rtmp.youtube.com/live2',
    this.streamKey = '',
    this.youtubeChannelId = '',
    this.youtubeChannelName = '',
    this.youtubeWatchUrl = '',
    this.youtubeBroadcastId = '',
    this.youtubeStreamId = '',
    this.facebookPageId = '',
    this.twitchChannel = '',
    this.resolution = StreamResolutionPreset.p720,
    this.fps = StreamFps.fps30,
    this.bitrateMode = StreamBitrateMode.adaptive,
    this.manualBitrateKbps = 2500,
    this.latency = StreamLatencyPreset.normal,
    this.codec = StreamVideoCodec.h264,
    this.orientation = StreamOrientationMode.landscape,
    this.orientationLocked = true,
    this.micEnabled = true,
    this.noiseSuppression = true,
    this.echoCancellation = true,
    this.micGain = 1.0,
    this.overlayLayout = StreamOverlayLayout.full,
    this.overlayPrimaryColor = 0xFF0D47A1,
    this.overlaySecondaryColor = 0xFFFFC107,
    this.overlayOpacity = 0.92,
    this.overlayRoundedCorners = true,
    this.overlayCompactMode = false,
    this.showSponsorBanner = true,
    this.showTicker = false,
    this.showWatermark = true,
    this.watermarkOpacity = 0.6,
    this.recordLocally = false,
    this.recordToGallery = true,
    this.autoReplayMarkers = true,
    this.selectedLensIndex = 0,
    this.digitalZoom = 1.0,
    this.flashEnabled = false,
    this.torchEnabled = false,
    this.thumbnailPath,
    this.streamingMode = StreamingMode.nativeCamera,
    this.cameraControls = const CameraControlSettings(),
  });

  final String title;
  final String description;
  final String category;
  final StreamVisibility visibility;
  final String language;
  final List<String> tags;
  final DateTime? scheduledAt;
  final bool goLiveImmediately;
  final StreamBroadcastSetupMode broadcastSetupMode;
  final StreamPlatform platform;
  final String rtmpUrl;
  final String streamKey;
  final String youtubeChannelId;
  final String youtubeChannelName;
  final String youtubeWatchUrl;
  final String youtubeBroadcastId;
  final String youtubeStreamId;
  final String facebookPageId;
  final String twitchChannel;
  final StreamResolutionPreset resolution;
  final StreamFps fps;
  final StreamBitrateMode bitrateMode;
  final int manualBitrateKbps;
  final StreamLatencyPreset latency;
  final StreamVideoCodec codec;
  final StreamOrientationMode orientation;
  final bool orientationLocked;
  final bool micEnabled;
  final bool noiseSuppression;
  final bool echoCancellation;
  final double micGain;
  final StreamOverlayLayout overlayLayout;
  final int overlayPrimaryColor;
  final int overlaySecondaryColor;
  final double overlayOpacity;
  final bool overlayRoundedCorners;
  final bool overlayCompactMode;
  final bool showSponsorBanner;
  final bool showTicker;
  final bool showWatermark;
  final double watermarkOpacity;
  final bool recordLocally;
  final bool recordToGallery;
  final bool autoReplayMarkers;
  final int selectedLensIndex;
  final double digitalZoom;
  final bool flashEnabled;
  final bool torchEnabled;
  final String? thumbnailPath;
  final StreamingMode streamingMode;
  final CameraControlSettings cameraControls;

  int get effectiveBitrateKbps {
    final base = switch (bitrateMode) {
      StreamBitrateMode.adaptive => switch (resolution) {
          StreamResolutionPreset.p480 => 1500,
          StreamResolutionPreset.p720 => 2500,
          StreamResolutionPreset.p1080 => 4500,
          StreamResolutionPreset.p1440 => 8000,
          StreamResolutionPreset.p4k => 12000,
        },
      StreamBitrateMode.manual => manualBitrateKbps,
    };
    return latency.adjustBitrateKbps(base);
  }

  StreamStudioConfig copyWith({
    String? title,
    String? description,
    String? category,
    StreamVisibility? visibility,
    String? language,
    List<String>? tags,
    DateTime? scheduledAt,
    bool? goLiveImmediately,
    StreamBroadcastSetupMode? broadcastSetupMode,
    StreamPlatform? platform,
    String? rtmpUrl,
    String? streamKey,
    String? youtubeChannelId,
    String? youtubeChannelName,
    String? youtubeWatchUrl,
    String? youtubeBroadcastId,
    String? youtubeStreamId,
    String? facebookPageId,
    String? twitchChannel,
    StreamResolutionPreset? resolution,
    StreamFps? fps,
    StreamBitrateMode? bitrateMode,
    int? manualBitrateKbps,
    StreamLatencyPreset? latency,
    StreamVideoCodec? codec,
    StreamOrientationMode? orientation,
    bool? orientationLocked,
    bool? micEnabled,
    bool? noiseSuppression,
    bool? echoCancellation,
    double? micGain,
    StreamOverlayLayout? overlayLayout,
    int? overlayPrimaryColor,
    int? overlaySecondaryColor,
    double? overlayOpacity,
    bool? overlayRoundedCorners,
    bool? overlayCompactMode,
    bool? showSponsorBanner,
    bool? showTicker,
    bool? showWatermark,
    double? watermarkOpacity,
    bool? recordLocally,
    bool? recordToGallery,
    bool? autoReplayMarkers,
    int? selectedLensIndex,
    double? digitalZoom,
    bool? flashEnabled,
    bool? torchEnabled,
    String? thumbnailPath,
    StreamingMode? streamingMode,
    CameraControlSettings? cameraControls,
  }) {
    return StreamStudioConfig(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      goLiveImmediately: goLiveImmediately ?? this.goLiveImmediately,
      broadcastSetupMode: broadcastSetupMode ?? this.broadcastSetupMode,
      platform: platform ?? this.platform,
      rtmpUrl: rtmpUrl ?? this.rtmpUrl,
      streamKey: streamKey ?? this.streamKey,
      youtubeChannelId: youtubeChannelId ?? this.youtubeChannelId,
      youtubeChannelName: youtubeChannelName ?? this.youtubeChannelName,
      youtubeWatchUrl: youtubeWatchUrl ?? this.youtubeWatchUrl,
      youtubeBroadcastId: youtubeBroadcastId ?? this.youtubeBroadcastId,
      youtubeStreamId: youtubeStreamId ?? this.youtubeStreamId,
      facebookPageId: facebookPageId ?? this.facebookPageId,
      twitchChannel: twitchChannel ?? this.twitchChannel,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      bitrateMode: bitrateMode ?? this.bitrateMode,
      manualBitrateKbps: manualBitrateKbps ?? this.manualBitrateKbps,
      latency: latency ?? this.latency,
      codec: codec ?? this.codec,
      orientation: orientation ?? this.orientation,
      orientationLocked: orientationLocked ?? this.orientationLocked,
      micEnabled: micEnabled ?? this.micEnabled,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      echoCancellation: echoCancellation ?? this.echoCancellation,
      micGain: micGain ?? this.micGain,
      overlayLayout: overlayLayout ?? this.overlayLayout,
      overlayPrimaryColor: overlayPrimaryColor ?? this.overlayPrimaryColor,
      overlaySecondaryColor:
          overlaySecondaryColor ?? this.overlaySecondaryColor,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      overlayRoundedCorners:
          overlayRoundedCorners ?? this.overlayRoundedCorners,
      overlayCompactMode: overlayCompactMode ?? this.overlayCompactMode,
      showSponsorBanner: showSponsorBanner ?? this.showSponsorBanner,
      showTicker: showTicker ?? this.showTicker,
      showWatermark: showWatermark ?? this.showWatermark,
      watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      recordLocally: recordLocally ?? this.recordLocally,
      recordToGallery: recordToGallery ?? this.recordToGallery,
      autoReplayMarkers: autoReplayMarkers ?? this.autoReplayMarkers,
      selectedLensIndex: selectedLensIndex ?? this.selectedLensIndex,
      digitalZoom: digitalZoom ?? this.digitalZoom,
      flashEnabled: flashEnabled ?? this.flashEnabled,
      torchEnabled: torchEnabled ?? this.torchEnabled,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      streamingMode: streamingMode ?? this.streamingMode,
      cameraControls: cameraControls ?? this.cameraControls,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'category': category,
        'visibility': visibility.name,
        'language': language,
        'tags': tags,
        if (scheduledAt != null) 'scheduledAt': scheduledAt!.toIso8601String(),
        'goLiveImmediately': goLiveImmediately,
        'broadcastSetupMode': broadcastSetupMode.name,
        'platform': platform.name,
        'rtmpUrl': rtmpUrl,
        'resolution': resolution.name,
        'fps': fps.name,
        'bitrateMode': bitrateMode.name,
        'manualBitrateKbps': manualBitrateKbps,
        'latency': latency.name,
        'codec': codec.name,
        'orientation': orientation.name,
        'orientationLocked': orientationLocked,
        'overlayLayout': overlayLayout.name,
        'streamingMode': streamingMode.name,
      };

  bool get usesManualBroadcastSetup =>
      broadcastSetupMode == StreamBroadcastSetupMode.manual ||
      platform != StreamPlatform.youtube;

  /// Public watch link must be pasted by the user (no API watch URL).
  bool get needsManualWatchUrl {
    if (streamingMode == StreamingMode.externalEncoder) return true;
    if (platform == StreamPlatform.youtube &&
        broadcastSetupMode == StreamBroadcastSetupMode.automatic) {
      return false;
    }
    return true;
  }

  /// True when RTMP credentials are saved and the user can start broadcasting.
  bool get isBroadcastConfigured {
    if (platform == StreamPlatform.youtube &&
        broadcastSetupMode == StreamBroadcastSetupMode.automatic) {
      return youtubeChannelId.isNotEmpty;
    }
    final normalized = StreamCredentialNormalizer.normalize(
      rtmpUrl: rtmpUrl,
      streamKey: streamKey,
      platform: platform,
    );
    if (normalized.streamKey.isEmpty) return false;
    if (platform == StreamPlatform.customRtmp ||
        platform == StreamPlatform.facebook) {
      return normalized.rtmpUrl.isNotEmpty;
    }
    return true;
  }

  @override
  List<Object?> get props => [title, platform, resolution, orientation];
}
