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

  /// Normalizes `crickflow://` and `https://…` into a GoRouter path.
  static String? pathFromUri(Uri uri) {
    if (uri.scheme == customScheme) {
      final host = uri.host;
      final path = uri.path;
      if (host.isEmpty) return path.isEmpty ? null : path;
      return '/$host$path';
    }

    if (uri.scheme == 'https' &&
        (uri.host == httpsHost || uri.host == firebaseHostingHost)) {
      final path = uri.path;
      return path.isEmpty ? null : path;
    }

    return null;
  }
}
