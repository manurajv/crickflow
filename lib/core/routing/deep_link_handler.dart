import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../utils/deep_link_utils.dart';

/// Listens for incoming deep links and navigates [GoRouter] accordingly.
class DeepLinkHandler {
  DeepLinkHandler(this._router);

  /// Set when a link arrives before auth; consumed after login.
  static String? pendingPath;

  final GoRouter _router;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  static String? takePendingPath() {
    final p = pendingPath;
    pendingPath = null;
    return p;
  }

  Future<void> init() async {
    try {
      final initial = await _appLinks.getInitialLink();
      _navigate(initial);
    } catch (e) {
      debugPrint('DeepLinkHandler initial: $e');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _navigate,
      onError: (Object e) => debugPrint('DeepLinkHandler stream: $e'),
    );
  }

  void _navigate(Uri? uri) {
    if (uri == null) return;
    final path = DeepLinkUtils.pathFromUri(uri);
    if (path == null || path == '/splash' || path == '/login') return;

    final location =
        uri.query.isNotEmpty ? '$path?${uri.query}' : path;

    final currentLocation =
        _router.routerDelegate.currentConfiguration.uri.toString();
    if (currentLocation == location) return;

    if (currentLocation == '/login' || currentLocation.contains('/login')) {
      pendingPath = location;
      return;
    }

    _router.go(location);
  }

  void dispose() {
    _subscription?.cancel();
  }
}
