import 'package:equatable/equatable.dart';

import '../../domain/streaming_enums.dart';
import '../../domain/streaming_mode.dart';

/// Last broadcast destination + studio options used for go-live.
class SavedStreamStudioPreferences extends Equatable {
  const SavedStreamStudioPreferences({
    required this.platform,
    required this.broadcastSetupMode,
    required this.orientation,
    this.streamingMode = StreamingMode.nativeCamera,
    this.rtmpUrl = '',
    this.streamKey = '',
    this.youtubeChannelId = '',
    this.youtubeChannelName = '',
    this.goLiveImmediately = false,
    this.resolution = StreamResolutionPreset.p720,
    this.lastUsedAt,
  });

  final StreamPlatform platform;
  final StreamBroadcastSetupMode broadcastSetupMode;
  final StreamOrientationMode orientation;
  final StreamingMode streamingMode;
  final String rtmpUrl;
  final String streamKey;
  final String youtubeChannelId;
  final String youtubeChannelName;
  final bool goLiveImmediately;
  final StreamResolutionPreset resolution;
  final DateTime? lastUsedAt;

  factory SavedStreamStudioPreferences.fromMap(Map<String, dynamic> map) {
    StreamPlatform parsePlatform(String? raw) {
      return StreamPlatform.values.firstWhere(
        (p) => p.name == raw,
        orElse: () => StreamPlatform.youtube,
      );
    }

    StreamBroadcastSetupMode parseSetupMode(String? raw) {
      return StreamBroadcastSetupMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => StreamBroadcastSetupMode.automatic,
      );
    }

    StreamResolutionPreset parseResolution(String? raw) {
      return StreamResolutionPreset.values.firstWhere(
        (r) => r.name == raw,
        orElse: () => StreamResolutionPreset.p720,
      );
    }

    StreamingMode parseStreamingMode(String? raw) {
      return StreamingMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => StreamingMode.nativeCamera,
      );
    }

    return SavedStreamStudioPreferences(
      platform: parsePlatform(map['platform'] as String?),
      broadcastSetupMode: parseSetupMode(map['broadcastSetupMode'] as String?),
      orientation: parseStreamOrientation(map['orientation'] as String?),
      streamingMode: parseStreamingMode(map['streamingMode'] as String?),
      rtmpUrl: map['rtmpUrl'] as String? ?? '',
      streamKey: map['streamKey'] as String? ?? '',
      youtubeChannelId: map['youtubeChannelId'] as String? ?? '',
      youtubeChannelName: map['youtubeChannelName'] as String? ?? '',
      goLiveImmediately: map['goLiveImmediately'] as bool? ?? false,
      resolution: parseResolution(map['resolution'] as String?),
      lastUsedAt: map['lastUsedAt'] != null
          ? DateTime.tryParse(map['lastUsedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'platform': platform.name,
        'broadcastSetupMode': broadcastSetupMode.name,
        'orientation': orientation.name,
        'streamingMode': streamingMode.name,
        'rtmpUrl': rtmpUrl,
        'streamKey': streamKey,
        'youtubeChannelId': youtubeChannelId,
        'youtubeChannelName': youtubeChannelName,
        'goLiveImmediately': goLiveImmediately,
        'resolution': resolution.name,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        platform,
        broadcastSetupMode,
        orientation,
        streamingMode,
        rtmpUrl,
        streamKey,
      ];
}
