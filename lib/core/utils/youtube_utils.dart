/// Parses YouTube watch / live URLs for in-app embed (Phase 3.2).
class YoutubeUtils {
  YoutubeUtils._();

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

  static String embedUrl(String videoId) =>
      'https://www.youtube.com/embed/$videoId?playsinline=1&rel=0';

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
}
