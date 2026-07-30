import 'package:flutter/foundation.dart';

/// Structured admin logging — quiet in release; ready for Crashlytics later.
abstract final class AdminLogger {
  static const _tag = 'CrickFlowAdmin';

  static void debug(String message, {String? module, Object? error}) {
    if (!kDebugMode) return;
    _emit('DEBUG', message, module: module, error: error);
  }

  static void info(String message, {String? module}) {
    if (!kDebugMode) return;
    _emit('INFO', message, module: module);
  }

  static void warning(String message, {String? module, Object? error}) {
    _emit('WARN', message, module: module, error: error);
  }

  static void error(
    String message, {
    String? module,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit('ERROR', message, module: module, error: error);
    if (kDebugMode && stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
    // Future: FirebaseCrashlytics.instance.recordError(...)
  }

  static void _emit(
    String level,
    String message, {
    String? module,
    Object? error,
  }) {
    final buf = StringBuffer('[$_tag][$level]');
    if (module != null && module.isNotEmpty) buf.write('[$module]');
    buf.write(' $message');
    if (error != null) buf.write(' · $error');
    debugPrint(buf.toString());
  }
}
