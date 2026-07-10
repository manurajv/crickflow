/// Facebook watch / live URL helpers for in-app WebView embed.
class FacebookUtils {
  FacebookUtils._();

  static const String embedRefererOrigin = 'https://www.facebook.com';

  /// Desktop Chrome UA — Facebook's video plugin is unreliable with mobile UA in WebView.
  static const String desktopChromeUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static bool isFacebookUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('facebook.com') || lower.contains('fb.watch');
  }

  /// Canonical public URL for the plugins/video.php href parameter.
  static String? normalizeWatchUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var trimmed = raw.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return null;

    final host = uri.host.toLowerCase();
    if (host == 'fb.watch' || host == 'www.fb.watch') {
      return trimmed;
    }
    if (!host.contains('facebook.com')) return null;

    // Strip tracking query params; keep path that identifies the video/live.
    final path = uri.path;
    if (path.isEmpty || path == '/') return null;

    return Uri(
      scheme: 'https',
      host: 'www.facebook.com',
      path: path.endsWith('/') ? path.substring(0, path.length - 1) : path,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
    ).toString();
  }

  static String pluginEmbedUrl(String watchUrl, {bool autoplay = true}) {
    final href = Uri.encodeComponent(watchUrl);
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
}
