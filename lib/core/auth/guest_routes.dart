/// Routes guests (signed-out users) may open for browse-only access.
///
/// Write / account actions stay in [isProtectedRoute] and send the user to
/// login with a contextual Sign in prompt. See docs/GUEST_ACCESS.md.
class GuestRoutes {
  GuestRoutes._();

  static const shellTabs = {
    '/home',
    '/discover',
    '/matches',
    '/community',
    '/profile',
  };

  static const browseRoots = {
    '/teams',
    '/players',
    '/player-rankings',
    '/analytics',
    '/wagon-wheel',
    '/fantasy',
    '/store',
    '/settings',
    '/legal/privacy',
    '/legal/terms',
    '/series',
    '/associations',
    '/clubs',
  };

  /// Strip query/fragment and trailing slash (except `/`).
  static String normalize(String path) {
    var p = path.trim();
    final q = p.indexOf('?');
    if (q >= 0) p = p.substring(0, q);
    final h = p.indexOf('#');
    if (h >= 0) p = p.substring(0, h);
    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    if (!p.startsWith('/')) p = '/$p';
    return p;
  }

  static bool isPublicRoute(String rawPath) {
    final path = normalize(rawPath);
    if (path == '/login' || path == '/splash' || path == '/onboarding') {
      return true;
    }
    if (path.startsWith('/invite/')) return true;
    if (isProtectedRoute(path)) return false;
    if (shellTabs.contains(path)) return true;
    if (browseRoots.contains(path)) return true;
    if (path.startsWith('/match/') && !_isProtectedMatchPath(path)) return true;
    if (path.startsWith('/teams/') && !path.contains('/add-players')) {
      return true;
    }
    if (path.startsWith('/players/')) return true;
    if (path.startsWith('/player/')) return true;
    if (path == '/find-cricketers') return true;
    if (path.startsWith('/fantasy/')) return true;
    if (_isTournamentJoinPath(path)) return true;
    if (_isTournamentDashboardPath(path)) return true;
    if (_isPublicSeriesPath(path)) return true;
    return false;
  }

  /// Org browse: list, detail, and any non-protected /series/:id child.
  /// Write routes are already excluded by [isProtectedRoute] earlier.
  static bool _isPublicSeriesPath(String path) {
    if (path == '/series' || path == '/associations' || path == '/clubs') {
      return true;
    }
    return RegExp(r'^/series/[^/]+(?:/.*)?$').hasMatch(path);
  }

  static bool _isTournamentDashboardPath(String path) {
    return RegExp(r'^/tournaments/[^/]+(?:/.*)?$').hasMatch(path) &&
        !_isTournamentJoinPath(path) &&
        path != '/tournaments/create';
  }

  static bool _isTournamentJoinPath(String path) {
    return RegExp(r'^/tournaments/[^/]+/join').hasMatch(path);
  }

  static bool isProtectedRoute(String rawPath) {
    final path = normalize(rawPath);
    if (path == '/match/create' ||
        path.startsWith('/match/create/') ||
        path == '/match/start' ||
        path == '/match/quick') {
      return true;
    }
    if (path == '/teams/create') return true;
    if (path == '/tournaments/create') return true;
    if (path == '/notifications' ||
        path == '/player-onboarding' ||
        path == '/register-player' ||
        path == '/profile/edit' ||
        path.startsWith('/community/chats')) {
      return true;
    }
    if (path.contains('/add-players') || path.contains('/add-player')) {
      return true;
    }
    if (_isProtectedSeriesPath(path)) return true;
    return _isProtectedMatchPath(path);
  }

  static bool _isProtectedSeriesPath(String path) {
    if (path == '/series/create' || path.startsWith('/series/create')) {
      return true;
    }
    const suffixes = [
      '/settings',
      '/propose-match',
      '/propose-tournament',
      '/register',
      '/my-requests',
      '/admins',
      '/audit',
      '/approvals',
      '/announcements',
      '/clubs/create',
    ];
    for (final suffix in suffixes) {
      if (path.endsWith(suffix)) return true;
    }
    if (path.contains('/add-player')) return true;
    return false;
  }

  static bool _isProtectedMatchPath(String path) {
    const suffixes = [
      '/score',
      '/start-innings',
      '/takeover',
      '/stream',
      '/overlay',
    ];
    for (final suffix in suffixes) {
      if (path.endsWith(suffix)) return true;
    }
    return false;
  }
}
