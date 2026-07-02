import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android foreground service bridge — keeps the process alive during live RTMP.
class StreamForegroundBridge {
  StreamForegroundBridge._();

  static const _channel = MethodChannel('com.mavixas.crickflow/stream_foreground');

  static bool get isSupported =>
      !kIsWeb && Platform.isAndroid;

  static Future<void> start({required String title}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('startLiveForeground', {'title': title});
    } catch (_) {}
  }

  static Future<void> update({required String title}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('updateLiveForeground', {'title': title});
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stopLiveForeground');
    } catch (_) {}
  }
}
