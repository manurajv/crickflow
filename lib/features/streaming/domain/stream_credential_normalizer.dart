import '../domain/streaming_enums.dart';

/// Normalizes RTMP URL + stream key pasted from YouTube Studio, Facebook, etc.
class StreamCredentialNormalizer {
  const StreamCredentialNormalizer._();

  static ({String rtmpUrl, String streamKey}) normalize({
    required String rtmpUrl,
    required String streamKey,
    StreamPlatform? platform,
  }) {
    var url = _clean(rtmpUrl);
    var key = _clean(streamKey);

    // Full secure stream URL pasted into the key field (common on Facebook)
    // even when the server preset is already filled.
    if (_isRtmpEndpoint(key)) {
      final parsed = _splitCombinedEndpoint(key);
      if (parsed.key.isNotEmpty) {
        url = parsed.server.isNotEmpty
            ? parsed.server
            : (url.isNotEmpty ? url : (platform?.defaultRtmpUrl ?? ''));
        key = parsed.key;
      } else {
        // Server URL pasted into the key field by mistake — keep server, clear key.
        if (parsed.server.isNotEmpty) {
          url = parsed.server;
        }
        key = '';
      }
    }

    // Some users paste the full ingest URL (with key) into the URL field.
    if (key.isEmpty && _looksLikeCompleteEndpoint(url)) {
      final parsed = _splitCombinedEndpoint(url);
      return _finalize(
        rtmpUrl: parsed.server,
        streamKey: parsed.key,
        platform: platform,
      );
    }

    // Key pasted into URL field, server left empty.
    if (url.isEmpty && key.toLowerCase().contains('rtmp')) {
      final parsed = _splitCombinedEndpoint(key);
      return _finalize(
        rtmpUrl: parsed.server,
        streamKey: parsed.key,
        platform: platform,
      );
    }

    if (key.isNotEmpty) {
      key = key.replaceFirst(RegExp(r'^/+'), '');
      if (url.endsWith('/$key')) {
        key = '';
      } else if (url.contains('/$key') && !key.contains('?')) {
        return _finalize(rtmpUrl: url, streamKey: key, platform: platform);
      }
    }

    if (key.isEmpty && url.contains('/')) {
      final parsed = _splitCombinedEndpoint(url);
      if (parsed.key.isNotEmpty) {
        return _finalize(
          rtmpUrl: parsed.server,
          streamKey: parsed.key,
          platform: platform,
        );
      }
    }

    return _finalize(rtmpUrl: url, streamKey: key, platform: platform);
  }

  static String buildEndpoint(String rtmpUrl, String streamKey) {
    final normalized = normalize(rtmpUrl: rtmpUrl, streamKey: streamKey);
    final base = normalized.rtmpUrl.replaceAll(RegExp(r'/+$'), '');
    final key = normalized.streamKey.replaceFirst(RegExp(r'^/+'), '');
    if (key.isEmpty) return ensureRtmpsPort(base);
    if (base.endsWith('/$key')) return ensureRtmpsPort(base);
    return ensureRtmpsPort('$base/$key');
  }

  /// Pedro defaults RTMPS without an explicit port to 1935 — Facebook needs 443.
  static String ensureRtmpsPort(String endpoint) {
    final trimmed = endpoint.trim();
    if (!trimmed.toLowerCase().startsWith('rtmps://')) return trimmed;
    final rest = trimmed.substring('rtmps://'.length);
    final slash = rest.indexOf('/');
    final authority = slash >= 0 ? rest.substring(0, slash) : rest;
    final path = slash >= 0 ? rest.substring(slash) : '';
    if (authority.contains(':')) return trimmed;
    return 'rtmps://$authority:443$path';
  }

  static ({String rtmpUrl, String streamKey}) _finalize({
    required String rtmpUrl,
    required String streamKey,
    StreamPlatform? platform,
  }) {
    var url = ensureRtmpsPort(rtmpUrl.trim().replaceAll(RegExp(r'/+$'), ''));
    final key = streamKey.trim().replaceFirst(RegExp(r'^/+'), '');

    if (platform != null) {
      if (url.isEmpty || _hostMismatch(url, platform)) {
        url = ensureRtmpsPort(
          platform.defaultRtmpUrl.replaceAll(RegExp(r'/+$'), ''),
        );
      }
    }

    return (rtmpUrl: url, streamKey: key);
  }

  static String _clean(String value) =>
      value.trim().replaceAll(RegExp(r'[\r\n\t]+'), '');

  /// True when [url] clearly belongs to a different platform's ingest.
  static bool _hostMismatch(String url, StreamPlatform platform) {
    final lower = url.toLowerCase();
    final isYouTube = lower.contains('youtube.com') ||
        lower.contains('youtu.be') ||
        lower.contains('a.rtmp.youtube');
    final isFacebook = lower.contains('facebook.com') ||
        lower.contains('fbcdn.net') ||
        lower.contains('live-api-s.');
    final isTwitch = lower.contains('twitch.tv') || lower.contains('ttvnw.net');

    return switch (platform) {
      StreamPlatform.facebook => isYouTube || isTwitch,
      StreamPlatform.youtube => isFacebook || isTwitch,
      StreamPlatform.twitch => isYouTube || isFacebook,
      StreamPlatform.customRtmp => false,
    };
  }

  static bool _isRtmpEndpoint(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('rtmp://') || lower.startsWith('rtmps://');
  }

  static bool _looksLikeCompleteEndpoint(String value) {
    if (!_isRtmpEndpoint(value)) return false;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) return false;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
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
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return (server: value.trim(), key: '');
    }
    final last = segments.last;
    const serverOnly = {'live2', 'live', 'rtmp', 'app'};
    if (serverOnly.contains(last)) {
      return (
        server: ensureRtmpsPort(value.trim().replaceAll(RegExp(r'/+$'), '')),
        key: '',
      );
    }
    final serverPath = segments.sublist(0, segments.length - 1).join('/');
    final authority =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final server = serverPath.isEmpty ? authority : '$authority/$serverPath';
    // Facebook secure_stream_url puts auth params in the query — they are part
    // of the stream key, not optional extras.
    final key = uri.hasQuery ? '$last?${uri.query}' : last;
    return (
      server: ensureRtmpsPort(server.replaceAll(RegExp(r'/+$'), '')),
      key: key,
    );
  }
}
