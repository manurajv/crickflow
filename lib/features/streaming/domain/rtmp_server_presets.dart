import 'streaming_enums.dart';

/// Built-in RTMP ingest endpoints users can pick instead of typing URLs.
class RtmpServerPreset {
  const RtmpServerPreset({
    required this.id,
    required this.label,
    required this.url,
    required this.platform,
    this.description = '',
    this.secure = false,
  });

  final String id;
  final String label;
  final String url;
  final StreamPlatform platform;
  final String description;
  final bool secure;
}

const kBuiltInRtmpPresets = <RtmpServerPreset>[
  RtmpServerPreset(
    id: 'youtube_primary',
    label: 'YouTube Live',
    url: 'rtmp://a.rtmp.youtube.com/live2',
    platform: StreamPlatform.youtube,
    description: 'Primary ingest — paste the stream key from YouTube Studio.',
  ),
  RtmpServerPreset(
    id: 'youtube_backup',
    label: 'YouTube Live (backup)',
    url: 'rtmp://b.rtmp.youtube.com/live2?backup=1',
    platform: StreamPlatform.youtube,
    description: 'Use if the primary YouTube server is unavailable.',
  ),
  RtmpServerPreset(
    id: 'facebook_live',
    label: 'Facebook Live',
    url: 'rtmps://live-api-s.facebook.com:443/rtmp/',
    platform: StreamPlatform.facebook,
    description: 'Secure RTMPS — copy server URL and key from Live Producer.',
    secure: true,
  ),
  RtmpServerPreset(
    id: 'custom_rtmp',
    label: 'Custom RTMP',
    url: '',
    platform: StreamPlatform.customRtmp,
    description: 'Enter any RTMP or RTMPS server URL.',
  ),
  RtmpServerPreset(
    id: 'custom_rtmps',
    label: 'Custom RTMPS',
    url: 'rtmps://',
    platform: StreamPlatform.customRtmp,
    description: 'Secure RTMP (RTMPS) — include host and port.',
    secure: true,
  ),
];

List<RtmpServerPreset> presetsForPlatform(StreamPlatform platform) {
  return switch (platform) {
    StreamPlatform.youtube => kBuiltInRtmpPresets
        .where((p) => p.platform == StreamPlatform.youtube)
        .toList(),
    StreamPlatform.facebook => kBuiltInRtmpPresets
        .where((p) => p.platform == StreamPlatform.facebook)
        .toList(),
    StreamPlatform.customRtmp => kBuiltInRtmpPresets
        .where((p) => p.platform == StreamPlatform.customRtmp)
        .toList(),
    StreamPlatform.twitch => const [],
  };
}

RtmpServerPreset? presetMatchingUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  for (final p in kBuiltInRtmpPresets) {
    if (p.url.isNotEmpty && p.url == trimmed) return p;
  }
  return null;
}
