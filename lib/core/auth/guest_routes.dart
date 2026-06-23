/// Routes accessible without signing in (browse-only platform).
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
    '/analytics',
    '/wagon-wheel',
    '/fantasy',
    '/store',
    '/settings',
  };

  static bool isPublicRoute(String path) {
    if (path == '/login' || path == '/splash' || path == '/onboarding') {
      return true;
    }
    if (isProtectedRoute(path)) return false;
    if (shellTabs.contains(path)) return true;
    if (browseRoots.contains(path)) return true;
    if (path.startsWith('/match/') && !_isProtectedMatchPath(path)) return true;
    if (path.startsWith('/teams/') && !path.contains('/add-players')) return true;
    if (path.startsWith('/players/')) return true;
    if (path.startsWith('/player/')) return true;
    if (path == '/find-cricketers') return true;
    if (path.startsWith('/fantasy/')) return true;
    if (_isTournamentJoinPath(path)) return true;
    if (_isTournamentDashboardPath(path)) return true;
    return false;
  }

  static bool _isTournamentDashboardPath(String path) {
    return RegExp(r'^/tournaments/[^/]+(?:/.*)?$').hasMatch(path) &&
        !_isTournamentJoinPath(path) &&
        path != '/tournaments/create';
  }

  static bool _isTournamentJoinPath(String path) {
    return RegExp(r'^/tournaments/[^/]+/join').hasMatch(path);
  }

  static bool isProtectedRoute(String path) {
    if (path == '/match/create' || path.startsWith('/match/create/')) {
      return true;
    }
    if (path == '/notifications' ||
        path == '/player-onboarding' ||
        path == '/profile/edit') {
      return true;
    }
    if (path.contains('/add-players')) return true;
    return _isProtectedMatchPath(path);
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
