import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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
      _handleUri(initial, fromColdStart: true);
    } catch (e) {
      debugPrint('DeepLinkHandler initial: $e');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleUri(uri, fromColdStart: false),
      onError: (Object e) => debugPrint('DeepLinkHandler stream: $e'),
    );
  }

  void _handleUri(Uri? uri, {required bool fromColdStart}) {
    if (uri == null) return;
    final path = DeepLinkUtils.pathFromUri(uri);
    if (path == null || path == '/splash' || path == '/login') return;

    final location =
        uri.query.isNotEmpty ? '$path?${uri.query}' : path;

    final currentLocation = _currentLocation();
    if (currentLocation == location) return;

    if (currentLocation == '/login' || currentLocation.contains('/login')) {
      pendingPath = location;
      return;
    }

    // Let splash bootstrap consume cold-start links to avoid router loops.
    if (fromColdStart &&
        (currentLocation == '/splash' || currentLocation.isEmpty)) {
      pendingPath = location;
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_currentLocation() == location) return;
      _router.go(location);
    });
  }

  String _currentLocation() {
    return _router.routerDelegate.currentConfiguration.uri.toString();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
