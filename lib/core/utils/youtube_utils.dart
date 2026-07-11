/// Parses YouTube watch / live URLs for in-app embed (Phase 3.2).
class YoutubeUtils {
  YoutubeUtils._();

  /// Referer origin for in-app WebView embeds (YouTube requires this since 2025).
  static const String embedRefererOrigin = 'https://crickflow-b06bc.web.app';

  static String? videoIdFromUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    if (uri.host.contains('youtu.be')) {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      return id?.isNotEmpty == true ? id : null;
    }

    if (uri.host.contains('youtube.com') ||
        uri.host.contains('youtube-nocookie.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return v;
      for (final segment in uri.pathSegments) {
        if (segment == 'live' || segment == 'embed' || segment == 'shorts') {
          final idx = uri.pathSegments.indexOf(segment);
          if (idx + 1 < uri.pathSegments.length) {
            return uri.pathSegments[idx + 1];
          }
        }
      }
    }

    return null;
  }

  static String embedUrl(
    String videoId, {
    bool fullControls = false,
    int? startSeconds,
  }) {
    final params = <String, String>{
      'playsinline': '1',
      'rel': '0',
      'origin': embedRefererOrigin,
      'iv_load_policy': '3',
      if (fullControls) ...const {
        'controls': '1',
        'fs': '1',
        'modestbranding': '1',
        'color': 'white',
        'enablejsapi': '1',
      },
      if (startSeconds != null && startSeconds > 0) 'start': '$startSeconds',
    };
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'https://www.youtube-nocookie.com/embed/$videoId?$query';
  }

  /// Full YouTube watch page — avoids iframe embed restrictions (error 150) in WebView.
  static String watchPageUrl(String videoId) =>
      'https://m.youtube.com/watch?v=$videoId';

  /// Chrome mobile UA so YouTube serves the mobile player inside WebView.
  static const String mobileChromeUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36';

  /// HTML wrapper for WebView — fixes YouTube error 153 (missing Referer).
  static String embedHtml(
    String videoId, {
    bool fullControls = true,
    int? startSeconds,
  }) {
    final src = embedUrl(
      videoId,
      fullControls: fullControls,
      startSeconds: startSeconds,
    );
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0; padding: 0; width: 100%; height: 100%;
      background: #000; overflow: hidden;
    }
    .frame {
      position: absolute; inset: 0;
      width: 100%; height: 100%;
    }
    iframe {
      position: absolute; inset: 0;
      width: 100%; height: 100%; border: 0;
    }
  </style>
</head>
<body>
  <div class="frame">
    <iframe
      src="$src"
      title="YouTube"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
      allowfullscreen
      referrerpolicy="strict-origin-when-cross-origin"></iframe>
  </div>
</body>
</html>''';
  }

  /// Hides m.youtube.com chrome so only the video area remains (fallback player).
  static const String minimizeMobileWatchPageJs = '''
(function() {
  var css = document.createElement('style');
  css.textContent = [
    '#masthead-container, ytm-mobile-topbar-renderer, .related-chips-slot-wrapper,',
    '#related, ytm-item-section-renderer, ytm-comments-entry-point-header-renderer,',
    '.slim-video-metadata-header, .menu-container, ytm-pivot-bar-renderer {',
    'display: none !important; visibility: hidden !important; height: 0 !important;',
    '}',
    'body, html { margin: 0 !important; padding: 0 !important; overflow: hidden !important; background: #000 !important; }',
    '#player-container-id, #player, .player-container, ytm-watch {',
    'position: fixed !important; top: 0 !important; left: 0 !important;',
    'width: 100% !important; height: 100% !important; max-height: 100% !important;',
    'margin: 0 !important; padding: 0 !important;',
    '}',
  ].join(' ');
  document.head.appendChild(css);
  window.scrollTo(0, 0);
})();''';

  static String formatStreamOffset(Duration offset) {
    final m = offset.inMinutes;
    final s = offset.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static Duration? offsetFromStreamStart({
    required DateTime? streamStartedAt,
    required DateTime? eventTime,
  }) {
    if (streamStartedAt == null || eventTime == null) return null;
    if (eventTime.isBefore(streamStartedAt)) return null;
    return eventTime.difference(streamStartedAt);
  }

  static Duration? offsetFromMilliseconds(int? ms) {
    if (ms == null || ms < 0) return null;
    return Duration(milliseconds: ms);
  }

  /// Seek an embedded YouTube iframe via postMessage (requires enablejsapi=1).
  static String seekIframeJs(int seconds) => '''
(function() {
  var frame = document.querySelector('iframe');
  if (!frame || !frame.contentWindow) return;
  frame.contentWindow.postMessage(JSON.stringify({
    event: 'command',
    func: 'seekTo',
    args: [$seconds, true]
  }), '*');
})();
''';

  /// YouTube watch URL with `t=` seconds for replay seek.
  static String? watchUrlAtOffset(String? watchUrl, Duration? offset) {
    if (watchUrl == null || watchUrl.trim().isEmpty) return null;
    final id = videoIdFromUrl(watchUrl);
    if (id == null) return watchUrl;
    final base = 'https://www.youtube.com/watch?v=$id';
    if (offset == null || offset.inSeconds <= 0) return base;
    return '$base&t=${offset.inSeconds}s';
  }
}
