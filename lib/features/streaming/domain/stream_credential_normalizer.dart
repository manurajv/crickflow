import '../domain/streaming_enums.dart';

/// Normalizes RTMP URL + stream key pasted from YouTube Studio, Facebook, etc.
class StreamCredentialNormalizer {
  const StreamCredentialNormalizer._();

  static ({String rtmpUrl, String streamKey}) normalize({
    required String rtmpUrl,
    required String streamKey,
    StreamPlatform? platform,
  }) {
    var url = rtmpUrl.trim();
    var key = streamKey.trim();

    // Some users paste the full ingest URL (with key) into the URL field.
    if (key.isEmpty && _looksLikeCompleteEndpoint(url)) {
      final parsed = _splitCombinedEndpoint(url);
      return (rtmpUrl: parsed.server, streamKey: parsed.key);
    }

    // Key pasted into URL field, server left empty/default.
    if (url.isEmpty && key.contains('rtmp')) {
      final parsed = _splitCombinedEndpoint(key);
      return (rtmpUrl: parsed.server, streamKey: parsed.key);
    }

    url = url.replaceAll(RegExp(r'/$'), '');

    if (key.isNotEmpty) {
      if (url.endsWith('/$key')) {
        key = '';
      } else if (url.contains('/$key')) {
        return (rtmpUrl: url, streamKey: key);
      }
    }

    if (key.isEmpty && url.contains('/')) {
      final parsed = _splitCombinedEndpoint(url);
      if (parsed.key.isNotEmpty) {
        return (rtmpUrl: parsed.server, streamKey: parsed.key);
      }
    }

    if (url.isEmpty && platform != null) {
      url = platform.defaultRtmpUrl;
    }

    return (rtmpUrl: url, streamKey: key);
  }

  static String buildEndpoint(String rtmpUrl, String streamKey) {
    final normalized = normalize(rtmpUrl: rtmpUrl, streamKey: streamKey);
    final base = normalized.rtmpUrl.replaceAll(RegExp(r'/$'), '');
    final key = normalized.streamKey;
    if (key.isEmpty) return base;
    if (base.endsWith('/$key')) return base;
    return '$base/$key';
  }

  static bool _looksLikeCompleteEndpoint(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return false;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return false;
    final last = segments.last;
    const serverOnly = {'live2', 'live', 'rtmp', 'app'};
    return !serverOnly.contains(last) && last.length > 4;
  }

  static ({String server, String key}) _splitCombinedEndpoint(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) {
      return (server: value.trim(), key: '');
    }
    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      return (server: value.trim(), key: '');
    }
    final last = segments.last;
    const serverOnly = {'live2', 'live', 'rtmp', 'app'};
    if (serverOnly.contains(last)) {
      return (server: value.trim(), key: '');
    }
    final serverPath = segments.sublist(0, segments.length - 1).join('/');
    final server =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/$serverPath';
    return (server: server.replaceAll(RegExp(r'/$'), ''), key: last);
  }
}
