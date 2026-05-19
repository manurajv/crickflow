import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_broadcaster/camera.dart';

import '../../core/constants/enums.dart';

/// RTMP live publisher (Android/iOS). Web is not supported.
class StreamService {
  CameraController? _controller;
  StreamStatus _status = StreamStatus.idle;
  String? _lastError;

  StreamStatus get status => _status;
  String? get lastError => _lastError;
  CameraController? get cameraController => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _controller?.value.isStreamingVideoRtmp ?? false;

  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initCamera() async {
    if (!isPlatformSupported) {
      _lastError = 'RTMP streaming is only available on Android and iOS.';
      return;
    }

    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!cam.isGranted || !mic.isGranted) {
      _lastError = 'Camera and microphone permissions are required.';
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _lastError = 'No camera found on this device.';
      return;
    }

    await _controller?.dispose();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: true,
    );
    await _controller!.initialize();
    _lastError = null;
  }

  /// [rtmpUrl] base server URL; [streamKey] appended if not already in URL.
  Future<void> startStream({
    required String rtmpUrl,
    required String streamKey,
    int bitrate = 1200 * 1024,
  }) async {
    if (_controller == null || !isInitialized) {
      await initCamera();
    }
    if (_controller == null || !isInitialized) {
      throw StateError(_lastError ?? 'Camera not ready');
    }

    _status = StreamStatus.connecting;
    final endpoint = buildRtmpEndpoint(rtmpUrl, streamKey);

    try {
      await _controller!.startVideoStreaming(
        endpoint,
        bitrate: bitrate,
      );
      _status = StreamStatus.live;
      _lastError = null;
    } on CameraException catch (e) {
      _status = StreamStatus.error;
      _lastError = e.description ?? e.code;
      rethrow;
    }
  }

  Future<void> stopStream() async {
    if (_controller != null && isInitialized) {
      try {
        await _controller!.stopEverything();
      } catch (_) {}
    }
    _status = StreamStatus.ended;
  }

  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
    _status = StreamStatus.idle;
  }

  static String buildRtmpEndpoint(String rtmpUrl, String streamKey) {
    final base = rtmpUrl.trim().replaceAll(RegExp(r'/$'), '');
    final key = streamKey.trim();
    if (key.isEmpty) return base;
    if (base.endsWith(key) || base.contains('/$key')) return base;
    return '$base/$key';
  }
}
