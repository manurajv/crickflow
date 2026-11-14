import 'dart:async';

import 'package:flutter/foundation.dart';

/// Lightweight cold-start profiler. Logs `[startup] <step> +<ms>ms` in debug
/// and profile builds (`flutter run --profile`), silent in release.
abstract final class StartupTrace {
  static final Stopwatch _clock = Stopwatch()..start();
  static int _last = 0;

  static void mark(String step) {
    if (kReleaseMode) return;
    final now = _clock.elapsedMilliseconds;
    debugPrint('[startup] $step +${now - _last}ms (total ${now}ms)');
    _last = now;
  }

  /// Awaits [future] but gives up after [timeout], returning [fallback].
  /// Used for startup work that must never block the first screen.
  static Future<T> capped<T>(
    Future<T> future, {
    required Duration timeout,
    required T fallback,
    String? label,
  }) async {
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      if (label != null) mark('$label timed out after ${timeout.inMilliseconds}ms');
      return fallback;
    } catch (e) {
      if (label != null) mark('$label failed: $e');
      return fallback;
    }
  }
}
