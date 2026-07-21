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

  static String playerPath(String playerId) => '/player/$playerId';

  static String findCricketersPath() => '/find-cricketers';

  static String communityPostPath(String postId) => '/community?postId=$postId';

  static Uri hostedCommunityPostUri(
    String postId, {
    bool useCustomDomain = false,
  }) =>
      hostedUri(communityPostPath(postId), useCustomDomain: useCustomDomain);

  static String tournamentJoinPath(String tournamentId, {bool fromQr = true}) {
    final path = '/tournaments/$tournamentId/join';
    return fromQr ? '$path?from=qr' : path;
  }

  static Uri hostedTournamentJoinUri(
    String tournamentId, {
    bool useCustomDomain = false,
    bool fromQr = true,
  }) =>
      hostedUri(
        tournamentJoinPath(tournamentId, fromQr: fromQr),
        useCustomDomain: useCustomDomain,
      );

  /// Maps bare `/tournaments/:id` invite URLs to the join screen path.
  static String normalizeTournamentInvitePath(
    String path,
    Map<String, String> query,
  ) {
    final bare = RegExp(r'^/tournaments/([^/]+)$').firstMatch(path);
    if (bare == null) return path;
    if (query['from'] == 'qr' || query.containsKey('code')) {
      return tournamentJoinPath(bare.group(1)!, fromQr: query['from'] == 'qr');
    }
    return path;
  }

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

  static Uri playerUri(String playerId) => Uri(
        scheme: customScheme,
        host: 'player',
        path: '/$playerId',
      );

  static Uri hostedPlayerUri(String playerId, {bool useCustomDomain = false}) =>
      hostedUri(playerPath(playerId), useCustomDomain: useCustomDomain);

  static Uri hostedUri(String path, {bool useCustomDomain = false}) => Uri(
        scheme: 'https',
        host: useCustomDomain ? httpsHost : firebaseHostingHost,
        path: path.startsWith('/') ? path : '/$path',
      );

  static Uri privacyPolicyUri({bool useCustomDomain = false}) =>
      hostedUri('/privacy.html', useCustomDomain: useCustomDomain);

  static Uri termsOfServiceUri({bool useCustomDomain = false}) =>
      hostedUri('/terms.html', useCustomDomain: useCustomDomain);

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

  /// Maps hosted privacy/terms URLs to in-app legal routes.
  static String? legalAppPath(String path) {
    switch (path) {
      case '/privacy.html':
      case '/privacy':
        return '/legal/privacy';
      case '/terms.html':
      case '/terms':
        return '/legal/terms';
      default:
        return null;
    }
  }

  /// Normalizes `crickflow://`, `https://…`, or raw location strings to a GoRouter path.
  static String? pathFromUri(Uri uri) {
    if (uri.scheme == customScheme) {
      return _pathFromCustomScheme(uri);
    }

    if (uri.scheme == 'https' &&
        (uri.host == httpsHost || uri.host == firebaseHostingHost)) {
      final path = uri.path;
      if (path.isEmpty) return null;
      final normalized = path.startsWith('/') ? path : '/$path';
      return legalAppPath(normalized) ?? normalized;
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

    if (trimmed.startsWith('/')) {
      return legalAppPath(trimmed) ?? trimmed;
    }
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
