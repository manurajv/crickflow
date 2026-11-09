/// Routes guests (signed-out users) may open for browse-only access.
///
/// Write / account actions stay in [isProtectedRoute] and send the user to
/// login with "Sign in to use this". See docs/GUEST_ACCESS.md.
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

  static bool isPublicRoute(String path) {
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

  /// Org browse: list, detail, clubs, rankings. Write routes are protected.
  static bool _isPublicSeriesPath(String path) {
    if (path == '/series' ||
        path == '/associations' ||
        path == '/clubs') {
      return true;
    }
    // /series/:id and read-only children (not create / settings / propose…)
    final seriesDetail = RegExp(r'^/series/[^/]+$');
    if (seriesDetail.hasMatch(path)) return true;
    final clubDetail = RegExp(r'^/series/[^/]+/clubs/[^/]+$');
    if (clubDetail.hasMatch(path)) return true;
    if (RegExp(r'^/series/[^/]+/rankings/?$').hasMatch(path)) return true;
    if (RegExp(r'^/series/[^/]+/fixtures/?$').hasMatch(path)) return true;
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

  /// Org write / account actions — guests see the login screen.
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
      '/dashboard',
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
