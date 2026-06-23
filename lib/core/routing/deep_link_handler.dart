import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import '../utils/deep_link_utils.dart';

/// Listens for incoming deep links and navigates [GoRouter] accordingly.
class DeepLinkHandler {
  DeepLinkHandler(this._router);

  /// Set when a link arrives before auth; consumed after login / splash.
  static String? pendingPath;

  static String? _cachedInitialLocation;
  static Future<String?>? _initialLocationFuture;

  final GoRouter _router;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  static bool get hasCachedLaunchRoute => _cachedInitialLocation != null;

  static String? takePendingPath() {
    final p = pendingPath;
    pendingPath = null;
    return p;
  }

  /// Peek without consuming — splash uses this to avoid clobbering a route.
  static String? peekPendingPath() => pendingPath ?? _cachedInitialLocation;

  /// Resolves cold-start App Link / custom-scheme URI (splash awaits this).
  static Future<String?> resolveInitialLocation({bool retry = false}) {
    if (_cachedInitialLocation != null) {
      return Future.value(_cachedInitialLocation);
    }
    if (retry) {
      _initialLocationFuture = null;
    }
    return _initialLocationFuture ??= _readInitialLocation();
  }

  static Future<String?> _readInitialLocation() async {
    try {
      // Plugin reads the activity intent in onAttachedToActivity, which can
      // finish after the first frame — poll until the link appears or timeout.
      const attempts = 30;
      for (var attempt = 0; attempt < attempts; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        final raw = await AppLinks().getInitialLinkString();
        if (raw != null && raw.isNotEmpty) {
          final location = locationFromUri(Uri.tryParse(raw));
          if (location != null) {
            _cachedInitialLocation = location;
            pendingPath ??= location;
            debugPrint('DeepLinkHandler initial: $location');
            return location;
          }
        }

        final uri = await AppLinks().getInitialLink();
        final location = locationFromUri(uri);
        if (location != null) {
          _cachedInitialLocation = location;
          pendingPath ??= location;
          debugPrint('DeepLinkHandler initial: $location');
          return location;
        }
      }
      return null;
    } catch (e) {
      debugPrint('DeepLinkHandler resolveInitial: $e');
      return null;
    }
  }

  static String? locationFromUri(Uri? uri) {
    if (uri == null) return null;
    var path = DeepLinkUtils.pathFromUri(uri);
    if (path == null || path == '/splash' || path == '/login') return null;

    path = DeepLinkUtils.normalizeTournamentInvitePath(path, uri.queryParameters);

    return uri.query.isNotEmpty ? '$path?${uri.query}' : path;
  }

  static bool isTournamentJoinRoute(String location) {
    final path = location.split('?').first;
    return RegExp(r'^/tournaments/[^/]+/join$').hasMatch(path);
  }

  Future<void> init() async {
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _onUri(uri),
      onError: (Object e) => debugPrint('DeepLinkHandler stream: $e'),
    );
  }

  void _onUri(Uri uri) {
    final location = locationFromUri(uri);
    if (location == null) return;

    _cachedInitialLocation ??= location;

    final currentLocation = _currentLocation();
    if (currentLocation == location) return;

    // During splash, only stash — splash bootstrap performs navigation once.
    if (currentLocation == '/splash' || currentLocation.isEmpty) {
      pendingPath = location;
      return;
    }

    if (currentLocation == '/login' || currentLocation.contains('/login')) {
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
