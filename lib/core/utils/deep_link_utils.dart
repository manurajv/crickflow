/// Deep link URLs for sharing and `app_links` routing.
class DeepLinkUtils {
  DeepLinkUtils._();

  static const String customScheme = 'crickflow';
  /// Custom domain when configured in Firebase Hosting.
  static const String httpsHost = 'crickflow.app';
  /// Default Firebase Hosting site (works without custom domain).
  static const String firebaseHostingHost = 'crickflow-b06bc.web.app';

  static String matchPath(String matchId) => '/match/$matchId';

  static String scorecardPath(String matchId) => '/match/$matchId/scorecard';

  /// Public web scorecard (no app required).
  static String publicLivePath(String matchId) => '/live/$matchId';

  static String teamPath(String teamId) => '/teams/$teamId';

  static Uri matchUri(String matchId) =>
      Uri(scheme: customScheme, host: 'match', path: '/$matchId');

  static Uri scorecardUri(String matchId) => Uri(
        scheme: customScheme,
        host: 'match',
        path: '/$matchId/scorecard',
      );

  static Uri teamUri(String teamId) => Uri(
        scheme: customScheme,
        host: 'teams',
        path: '/$teamId',
      );

  static Uri hostedUri(String path, {bool useCustomDomain = false}) => Uri(
        scheme: 'https',
        host: useCustomDomain ? httpsHost : firebaseHostingHost,
        path: path.startsWith('/') ? path : '/$path',
      );

  static Uri privacyPolicyUri({bool useCustomDomain = false}) =>
      hostedUri('/privacy.html', useCustomDomain: useCustomDomain);

  /// HTTPS link that opens the app when App Links are verified (Firebase Hosting).
  static Uri httpsScorecardUri(String matchId, {bool useCustomDomain = false}) =>
      Uri(
        scheme: 'https',
        host: useCustomDomain ? httpsHost : firebaseHostingHost,
        path: scorecardPath(matchId),
      );

  static Uri publicLiveScorecardUri(String matchId, {bool useCustomDomain = false}) =>
      hostedUri(publicLivePath(matchId), useCustomDomain: useCustomDomain);

  /// HTTPS team invite (App Links / universal links).
  static Uri httpsTeamUri(String teamId, {bool useCustomDomain = false}) =>
      hostedUri(teamPath(teamId), useCustomDomain: useCustomDomain);

  /// Normalizes `crickflow://`, `https://…`, or raw location strings to a GoRouter path.
  static String? pathFromUri(Uri uri) {
    if (uri.scheme == customScheme) {
      return _pathFromCustomScheme(uri);
    }

    if (uri.scheme == 'https' &&
        (uri.host == httpsHost || uri.host == firebaseHostingHost)) {
      final path = uri.path;
      if (path.isEmpty) return null;
      return path.startsWith('/') ? path : '/$path';
    }

    return null;
  }

  /// Handles platform routes like `crickflow://teams/<id>` passed as [location].
  static String? normalizeLocation(String location) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('$customScheme://')) {
      return pathFromUri(Uri.parse(trimmed));
    }

    if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
      return pathFromUri(Uri.parse(trimmed));
    }

    if (trimmed.startsWith('/')) return trimmed;
    return null;
  }

  static String? _pathFromCustomScheme(Uri uri) {
    final host = uri.host;
    var path = uri.path;

    if (host.isNotEmpty) {
      if (path.isEmpty && uri.pathSegments.length == 1) {
        path = '/${uri.pathSegments.first}';
      }
      if (!path.startsWith('/')) path = '/$path';
      return '/$host$path';
    }

    if (path.isNotEmpty) {
      return path.startsWith('/') ? path : '/$path';
    }

    if (uri.pathSegments.isNotEmpty) {
      return '/${uri.pathSegments.join('/')}';
    }

    return null;
  }
}
