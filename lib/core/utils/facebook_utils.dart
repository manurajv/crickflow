/// Facebook watch / live URL helpers for in-app WebView embed.
class FacebookUtils {
  FacebookUtils._();

  static const String embedRefererOrigin = 'https://www.facebook.com';

  /// Desktop Chrome UA — Facebook's video plugin is unreliable with mobile UA in WebView.
  static const String desktopChromeUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Mobile UA for the watch-page fallback (mirrors YouTube mobile watch strategy).
  static const String mobileChromeUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36';

  static final RegExp _numericVideoId = RegExp(r'^\d{8,}$');
  static final RegExp _videosPathId = RegExp(
    r'/videos/(?:\d+/)*(\d{8,})',
    caseSensitive: false,
  );
  static final RegExp _iframeSrc = RegExp(
    r'''<iframe[^>]+src=["']([^"']+)["']''',
    caseSensitive: false,
  );
  static final RegExp _dataHref = RegExp(
    r'''data-href=["']([^"']+)["']''',
    caseSensitive: false,
  );

  static bool isFacebookUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('facebook.com') || lower.contains('fb.watch');
  }

  /// True for modern share links such as `/share/v/19hp7yKM9T/`.
  static bool isSharePermalinkUrl(String? raw) {
    final preprocessed = _preprocessUrl(raw);
    if (preprocessed == null) return false;
    final uri = Uri.tryParse(preprocessed);
    return uri != null && _isSharePermalink(uri);
  }

  /// Extracts a numeric Facebook video / live video id from classic share URLs.
  static String? videoIdFromUrl(String? raw) {
    final preprocessed = _preprocessUrl(raw);
    if (preprocessed == null) return null;
    final uri = Uri.tryParse(preprocessed);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    if (_isFbWatchHost(host)) return null;
    if (_isSharePermalink(uri)) return null;

    if (!_isFacebookHost(host)) return null;

    for (final key in const ['v', 'video_id']) {
      final value = uri.queryParameters[key];
      if (value != null && _numericVideoId.hasMatch(value)) return value;
    }

    final videosMatch = _videosPathId.firstMatch(uri.path);
    if (videosMatch != null) return videosMatch.group(1);

    final segments = uri.pathSegments;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i] == 'videos' && i + 1 < segments.length) {
        final next = segments[i + 1];
        if (_numericVideoId.hasMatch(next)) return next;
      }
      if (segments[i] == 'reel' && i + 1 < segments.length) {
        final next = segments[i + 1];
        if (_numericVideoId.hasMatch(next)) return next;
      }
    }

    return null;
  }

  /// Canonical public URL for the plugins/video.php href parameter.
  ///
  /// Supports classic `/watch/?v=`, `/{page}/videos/{id}/`, modern `/share/v/{token}/`,
  /// `fb.watch`, and pasted embed iframe / `data-href` snippets from Facebook Live.
  static String? normalizeWatchUrl(String? raw) {
    final preprocessed = _preprocessUrl(raw);
    if (preprocessed == null) return null;
    final uri = Uri.tryParse(preprocessed);
    if (uri == null || !uri.hasScheme) return null;

    final host = uri.host.toLowerCase();
    if (_isFbWatchHost(host)) {
      return _stripTrailingSlash(preprocessed);
    }
    if (!_isFacebookHost(host)) return null;

    if (_isSharePermalink(uri)) {
      return _canonicalShareUrl(uri);
    }

    final videoId = videoIdFromUrl(preprocessed);
    if (videoId != null) {
      final pageSlug = _pageSlugBeforeVideos(uri);
      if (pageSlug != null && pageSlug.isNotEmpty) {
        return 'https://www.facebook.com/$pageSlug/videos/$videoId/';
      }
      return 'https://www.facebook.com/watch/?v=$videoId';
    }

    final path = uri.path;
    if (path.isEmpty || path == '/') return null;
    final cleanPath = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    return 'https://www.facebook.com$cleanPath';
  }

  /// Last-resort in-app URL — mobile watch page or share permalink.
  static String? inAppFallbackUrl(String? watchUrl) {
    final canonical = normalizeWatchUrl(watchUrl);
    if (canonical == null) return null;
    final uri = Uri.tryParse(canonical);
    if (uri == null) return null;

    if (_isSharePermalink(uri)) {
      return 'https://m.facebook.com${uri.path}';
    }

    final videoId = videoIdFromUrl(canonical);
    if (videoId != null) {
      return watchPageUrl(videoId);
    }

    return canonical;
  }

  /// m.facebook.com watch page for classic numeric video ids.
  static String watchPageUrl(String videoId) =>
      'https://m.facebook.com/watch/?v=$videoId';

  static String pluginEmbedUrl(String watchUrl, {bool autoplay = true}) {
    final canonical = normalizeWatchUrl(watchUrl) ?? watchUrl;
    final href = Uri.encodeComponent(canonical);
    return 'https://www.facebook.com/plugins/video.php'
        '?href=$href'
        '&show_text=false'
        '&width=1280'
        '&height=720'
        '&autoplay=${autoplay ? 'true' : 'false'}'
        '&mute=false'
        '&allowfullscreen=true';
  }

  /// HTML iframe wrapper — loads reliably in WebView vs direct plugin URL.
  static String embedHtml(String watchUrl, {bool autoplay = true}) {
    final src = pluginEmbedUrl(watchUrl, autoplay: autoplay);
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <meta name="referrer" content="no-referrer-when-downgrade">
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0; padding: 0; width: 100%; height: 100%;
      background: #000; overflow: hidden;
    }
    iframe {
      position: absolute; inset: 0;
      width: 100%; height: 100%; border: 0;
    }
  </style>
</head>
<body>
  <iframe
    src="$src"
    title="Facebook video"
    scrolling="no"
    allow="autoplay; clipboard-write; encrypted-media; picture-in-picture; fullscreen"
    allowfullscreen
    referrerpolicy="no-referrer-when-downgrade"></iframe>
</body>
</html>''';
  }

  /// JS probe for Facebook's in-embed "Video Unavailable" copy (HTTP 200 error page).
  static const String embedUnavailableProbeJs = '''
(function() {
  var text = (document.body && document.body.innerText) ? document.body.innerText : '';
  return text.indexOf('Video Unavailable') >= 0 ||
         text.indexOf('video may no longer exist') >= 0;
})();''';

  static bool isAllowedEmbedHost(String host) {
    final h = host.toLowerCase();
    return h.contains('facebook.com') ||
        h.contains('fbcdn.net') ||
        h.contains('fb.watch') ||
        h.contains('fbsbx.com') ||
        h.contains('facebook.net') ||
        h == 'fb.com' ||
        h.endsWith('.fb.com');
  }

  static String? _preprocessUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var trimmed = raw.trim();

    final iframeMatch = _iframeSrc.firstMatch(trimmed);
    if (iframeMatch != null) {
      return _preprocessUrl(iframeMatch.group(1));
    }
    final hrefMatch = _dataHref.firstMatch(trimmed);
    if (hrefMatch != null) {
      return _preprocessUrl(hrefMatch.group(1));
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }

    var uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    if (uri.path.contains('plugins/video.php')) {
      final href = uri.queryParameters['href'];
      if (href != null && href.trim().isNotEmpty) {
        return _preprocessUrl(Uri.decodeComponent(href.trim()));
      }
    }

    final host = uri.host.toLowerCase();
    if (host == 'm.facebook.com' ||
        host == 'web.facebook.com' ||
        host == 'mbasic.facebook.com') {
      uri = uri.replace(host: 'www.facebook.com');
      trimmed = uri.toString();
    }

    return trimmed;
  }

  static bool _isFacebookHost(String host) => host.contains('facebook.com');

  static bool _isFbWatchHost(String host) =>
      host == 'fb.watch' || host == 'www.fb.watch';

  static bool _isSharePermalink(Uri uri) {
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length < 3) return false;
    return parts[0] == 'share' && (parts[1] == 'v' || parts[1] == 'p');
  }

  static String _canonicalShareUrl(Uri uri) {
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return 'https://www.facebook.com/share/${parts[1]}/${parts[2]}/';
  }

  static String? _pageSlugBeforeVideos(Uri uri) {
    final match = RegExp(
      r'^/([^/]+(?:/[^/]+)*)/videos/',
      caseSensitive: false,
    ).firstMatch(uri.path);
    return match?.group(1);
  }

  static String _stripTrailingSlash(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
