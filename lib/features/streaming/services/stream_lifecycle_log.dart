import 'package:flutter/foundation.dart';

/// Structured live-stream lifecycle logs for production diagnostics.
abstract final class StreamLifecycleLog {
  static const _tag = 'CrickFlowStreamLifecycle';

  static void liveStarted() => _log('LIVE_STARTED');

  static void liveStopped() => _log('LIVE_STOPPED');

  static void networkLost() => _log('NETWORK_LOST');

  static void retry(int attempt) => _log('RETRY_$attempt');

  static void retrySuccess() => _log('RETRY_SUCCESS');

  static void retryFailed() => _log('RETRY_FAILED');

  static void appRemoved() => _log('APP_REMOVED');

  static void background() => _log('BACKGROUND');

  static void foreground() => _log('FOREGROUND');

  static void cameraReconnected() => _log('CAMERA_RECONNECTED');

  static void rtmpReconnected() => _log('RTMP_RECONNECTED');

  static void _log(String event) {
    debugPrint('[$_tag] $event');
  }
}
