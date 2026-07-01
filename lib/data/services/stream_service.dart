import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_broadcaster/camera.dart';

import '../../core/constants/enums.dart';
import '../../features/streaming/domain/camera_control_settings.dart';
import '../../features/streaming/domain/stream_credential_normalizer.dart';
import '../../features/streaming/data/models/camera_lens_info.dart';
import '../../features/streaming/domain/streaming_enums.dart';

export '../../features/streaming/data/models/camera_lens_info.dart';

/// Live stream health metrics from RTMP stats + device probes.
class StreamHealthMetrics {
  const StreamHealthMetrics({
    this.bitrateKbps = 0,
    this.fps = 0,
    this.droppedVideoFrames = 0,
    this.droppedAudioFrames = 0,
    this.uploadSpeedKbps,
    this.connectionQuality = StreamConnectionQuality.unknown,
    this.batteryPercent,
    this.isReconnecting = false,
  });

  final int bitrateKbps;
  final int fps;
  final int droppedVideoFrames;
  final int droppedAudioFrames;
  final double? uploadSpeedKbps;
  final StreamConnectionQuality connectionQuality;
  final int? batteryPercent;
  final bool isReconnecting;
}

/// RTMP live publisher with camera lens management, orientation lock,
/// health monitoring, and auto-reconnect.
class StreamService extends ChangeNotifier {
  CameraController? _controller;
  StreamStatus _status = StreamStatus.idle;
  String? _lastError;
  List<CameraLensInfo> _lenses = const [];
  int _selectedLensIndex = 0;
  StreamOrientationMode _orientation = StreamOrientationMode.landscapeLeft;
  bool _orientationLocked = false;
  ResolutionPreset _resolutionPreset = ResolutionPreset.high;
  bool _micEnabled = true;
  String? _localRecordingPath;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  void Function()? _cameraListener;
  String? _lastEndpoint;
  int _lastBitrate = 2500 * 1024;
  final _healthController = StreamController<StreamHealthMetrics>.broadcast();
  Timer? _healthTimer;
  bool _switchingLens = false;
  Future<void>? _cameraOperation;

  StreamStatus get status => _status;
  String? get lastError => _lastError;
  CameraController? get cameraController => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _controller?.value.isStreamingVideoRtmp ?? false;
  bool get isSwitchingLens => _switchingLens;
  List<CameraLensInfo> get lenses => _lenses;
  int get selectedLensIndex => _selectedLensIndex;
  StreamOrientationMode get orientation => _orientation;
  bool get orientationLocked => _orientationLocked;
  Stream<StreamHealthMetrics> get healthStream => _healthController.stream;

  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initCamera({
    int lensIndex = 0,
    StreamResolutionPreset resolution = StreamResolutionPreset.p720,
    StreamOrientationMode orientation = StreamOrientationMode.landscapeLeft,
    bool lockOrientation = false,
    bool enableAudio = true,
  }) {
    return _runCameraOperation(() async {
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

      _lenses = CameraLensCatalog.fromCameras(cameras);
      _selectedLensIndex = lensIndex.clamp(0, _lenses.length - 1);
      _orientation = orientation;
      _orientationLocked = lockOrientation;
      _micEnabled = enableAudio;
      _resolutionPreset = _mapResolution(resolution);

      if (_orientationLocked) {
        await _applyOrientationLock();
      } else {
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      }

      await _releaseCamera(waitForSurfaceTeardown: false);
      await _openSelectedLens();
      _lastError = null;
      notifyListeners();
    });
  }

  /// Switches optical lens or digital zoom. Prefer native [switchCameraById]
  /// without tearing down the preview surface when already initialized.
  Future<void> switchLens(int index) {
    return _runCameraOperation(() async {
      if (index < 0 || index >= _lenses.length) return;
      if (_selectedLensIndex == index && isInitialized) return;
      if (isStreaming) {
        throw StateError('Stop the stream before changing camera lens.');
      }

      _switchingLens = true;
      try {
        final lens = _lenses[index];
        final current = _lenses[_selectedLensIndex];

        // Digital zoom on the same physical camera.
        if (lens.isDigitalZoom &&
            lens.description.name == current.description.name &&
            isInitialized &&
            _controller != null) {
          final maxZoom = await _controller!.getMaxZoom();
          final clamped = lens.zoomFactor.clamp(1.0, maxZoom);
          await _applyZoomWithRetry(clamped);
          _selectedLensIndex = index;
          _lastError = null;
          notifyListeners();
          return;
        }

        // Front/back toggle — use native flip when switching facing.
        if (isInitialized &&
            _controller != null &&
            lens.isFront != current.isFront) {
          _selectedLensIndex = index;
          await _controller!.flipCamera();
          await _applyZoomForLens(lens);
          _lastError = null;
          notifyListeners();
          return;
        }

        // Physical camera switch while preview is active.
        if (isInitialized && _controller != null) {
          _selectedLensIndex = index;
          await _controller!.switchCameraById(lens.description.name!);
          await _applyZoomForLens(lens);
          _lastError = null;
          notifyListeners();
          return;
        }

        // Cold start / re-open fallback.
        _selectedLensIndex = index;
        await _releaseCamera(waitForSurfaceTeardown: true);
        await _openSelectedLens();
        await _applyZoomForLens(lens);
        _lastError = null;
        notifyListeners();
      } on CameraException catch (e) {
        _lastError = e.description ?? e.code;
        rethrow;
      } finally {
        _switchingLens = false;
      }
    });
  }

  /// Toggle device torch / flashlight on the active camera.
  Future<void> setTorch(bool enabled) async {
    if (_controller == null || !isInitialized) return;
    try {
      await _applyNativeWithRetry(
        () => _controller!.setTorch(enabled),
      );
      _lastError = null;
    } on CameraException catch (e) {
      _lastError = e.description ?? e.code;
      rethrow;
    }
  }

  /// Apply pro camera settings from the studio config.
  Future<void> applyCameraControls(CameraControlSettings settings) async {
    if (_controller == null || !isInitialized) return;
    try {
      await _applyNativeWithRetry(
        () => _controller!.setExposureCompensation(settings.exposureCompensation),
      );
      await _controller!.setFocusLock(settings.focusLocked);
    } on CameraException catch (e) {
      _lastError = e.description ?? e.code;
    }
    notifyListeners();
  }

  /// Tap-to-focus at normalized coordinates (0–1) on the preview.
  Future<void> tapToFocus(double x, double y) async {
    if (_controller == null || !isInitialized) return;
    try {
      await _controller!.tapToFocus(x, y);
    } on CameraException catch (e) {
      _lastError = e.description ?? e.code;
    }
  }

  /// Apply digital zoom on the active camera (1.0 = widest).
  Future<void> setDigitalZoom(double factor) async {
    if (_controller == null || !isInitialized) return;
    final maxZoom = await _controller!.getMaxZoom();
    final level = factor < 1 ? 1.0 : factor.clamp(1.0, maxZoom);
    await _controller!.setZoom(level);
  }

  /// Maximum digital zoom supported on the active camera.
  Future<double> getMaxDigitalZoom() async {
    if (_controller == null || !isInitialized) return 1.0;
    return _controller!.getMaxZoom();
  }

  Future<void> _openSelectedLens() async {
    if (_lenses.isEmpty) return;
    final lens = _lenses[_selectedLensIndex];
    _controller = CameraController(
      lens.description,
      _resolutionPreset,
      enableAudio: _micEnabled,
    );
    await _controller!.initialize();
    _attachCameraListener();
  }

  /// Re-open the camera preview after the app returns from background or the
  /// display turns off (Android often tears down the GL surface).
  Future<void> resumePreviewAfterBackground() {
    return _runCameraOperation(() async {
      if (!isPlatformSupported) return;

      if (isStreaming) {
        notifyListeners();
        return;
      }

      if (_controller != null && isInitialized) {
        try {
          await refreshDeviceZoomSteps();
          if (isInitialized) return;
        } catch (_) {}
      }

      if (_lenses.isEmpty) {
        final cameras = await availableCameras();
        if (cameras.isEmpty) return;
        _lenses = CameraLensCatalog.fromCameras(cameras);
        _selectedLensIndex = _selectedLensIndex.clamp(0, _lenses.length - 1);
      }

      await _releaseCamera(waitForSurfaceTeardown: true);
      await _openSelectedLens();
      _lastError = null;
      notifyListeners();
    });
  }

  /// Call after [CameraPreview] is mounted so the native view exists.
  Future<void> refreshDeviceZoomSteps() async {
    if (_controller == null || !isInitialized) return;
    try {
      final maxZoom = await _controller!.getMaxZoom();
      if (maxZoom <= 1) return;
      _lenses = CameraLensCatalog.withDeviceMaxZoom(_lenses, maxZoom);
      _selectedLensIndex = _selectedLensIndex.clamp(0, _lenses.length - 1);
      await _applyZoomForLens(_lenses[_selectedLensIndex]);
      _lastError = null;
      notifyListeners();
    } on CameraException catch (e) {
      _lastError = e.description ?? e.code;
    }
  }

  Future<void> _applyZoomForLens(CameraLensInfo lens) async {
    if (_controller == null || !isInitialized) return;
    if (lens.isDigitalZoom && lens.zoomFactor > 1) {
      final maxZoom = await _controller!.getMaxZoom();
      await _applyZoomWithRetry(lens.zoomFactor.clamp(1.0, maxZoom));
    } else {
      await _applyZoomWithRetry(1);
    }
  }

  Future<void> _applyZoomWithRetry(double level) async {
    if (_controller == null) return;
    Object? lastError;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        await _controller!.setZoom(level);
        return;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)));
      }
    }
    if (lastError != null) throw lastError!;
  }

  Future<void> _applyNativeWithRetry(Future<void> Function() action) async {
    Object? lastError;
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        await action();
        return;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)));
      }
    }
    if (lastError != null) throw lastError!;
  }

  Future<void> _releaseCamera({required bool waitForSurfaceTeardown}) async {
    if (_cameraListener != null && _controller != null) {
      _controller!.removeListener(_cameraListener!);
      _cameraListener = null;
    }

    final controller = _controller;
    _controller = null;

    if (controller == null) return;

    try {
      if (controller.value.isStreamingVideoRtmp == true ||
          controller.value.isRecordingVideo == true) {
        await controller.stopEverything();
      }
    } catch (_) {}

    try {
      await controller.dispose();
    } catch (_) {}

    if (waitForSurfaceTeardown && Platform.isAndroid) {
      // Let the hybrid AndroidView / GL surface fully detach before reopening.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Future<void> _runCameraOperation(Future<void> Function() action) async {
    final previous = _cameraOperation;
    final operation = (previous ?? Future<void>.value()).then((_) => action());
    _cameraOperation = operation;
    await operation;
  }

  Future<void> lockOrientation(StreamOrientationMode mode) async {
    _orientation = mode;
    _orientationLocked = true;
    await _applyOrientationLock();
  }

  Future<void> _applyOrientationLock() async {
    final orientations = switch (_orientation) {
      StreamOrientationMode.portrait => [DeviceOrientation.portraitUp],
      StreamOrientationMode.landscapeLeft => [DeviceOrientation.landscapeLeft],
      StreamOrientationMode.landscapeRight => [DeviceOrientation.landscapeRight],
      StreamOrientationMode.auto => DeviceOrientation.values,
    };
    await SystemChrome.setPreferredOrientations(orientations);
  }

  Future<void> startStream({
    required String rtmpUrl,
    required String streamKey,
    int? bitrate,
    StreamResolutionPreset resolution = StreamResolutionPreset.p720,
    String? localRecordingPath,
  }) async {
    if (_controller == null || !isInitialized) {
      await initCamera(
        lensIndex: _selectedLensIndex,
        resolution: resolution,
        orientation: _orientation,
        lockOrientation: _orientationLocked,
        enableAudio: _micEnabled,
      );
    }
    if (_controller == null || !isInitialized) {
      throw StateError(_lastError ?? 'Camera not ready');
    }

    _status = StreamStatus.connecting;
    final endpoint = buildRtmpEndpoint(rtmpUrl, streamKey);
    _lastEndpoint = endpoint;
    _lastBitrate = (bitrate ?? 2500 * 1024);
    _localRecordingPath = localRecordingPath;

    await _startStreamingInternal(
      endpoint: endpoint,
      bitrate: _lastBitrate,
      recordPath: localRecordingPath,
    );
  }

  Future<void> _startStreamingInternal({
    required String endpoint,
    required int bitrate,
    String? recordPath,
  }) async {
    try {
      if (recordPath != null && recordPath.isNotEmpty) {
        await _controller!.startVideoRecordingAndStreaming(
          recordPath,
          endpoint,
          bitrate: bitrate,
        );
      } else {
        await _controller!.startVideoStreaming(
          endpoint,
          bitrate: bitrate,
        );
      }
      _status = StreamStatus.live;
      _lastError = null;
      _startHealthMonitoring();
      _startConnectivityWatch(endpoint, bitrate);
    } on CameraException catch (e) {
      _status = StreamStatus.error;
      _lastError = e.description ?? e.code;
      rethrow;
    }
  }

  void _attachCameraListener() {
    if (_controller == null) return;
    if (_cameraListener != null) {
      _controller!.removeListener(_cameraListener!);
    }
    _cameraListener = () {
      final event = _controller!.value.event;
      if (event is! Map) return;
      final type = event['eventType'] as String?;
      if (type == 'rtmp_retry') {
        _healthController.add(const StreamHealthMetrics(isReconnecting: true));
        _status = StreamStatus.connecting;
      } else if (type == 'rtmp_connected') {
        _status = StreamStatus.live;
        _healthController.add(const StreamHealthMetrics(isReconnecting: false));
      } else if (type == 'rtmp_stopped') {
        _status = StreamStatus.ended;
      }
    };
    _controller!.addListener(_cameraListener!);
  }

  void _startHealthMonitoring() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!isStreaming || _controller == null) return;
      try {
        final stats = await _controller!.getStreamStatistics();
        final dropped = stats.droppedVideoFrames ?? 0;
        final quality = _qualityFromDrops(dropped);
        _healthController.add(StreamHealthMetrics(
          bitrateKbps: ((stats.bitrate ?? 0) / 1024).round(),
          fps: 30,
          droppedVideoFrames: dropped,
          droppedAudioFrames: stats.droppedAudioFrames ?? 0,
          connectionQuality: quality,
        ));
      } catch (_) {}
    });
  }

  StreamConnectionQuality _qualityFromDrops(int dropped) {
    if (dropped <= 2) return StreamConnectionQuality.excellent;
    if (dropped <= 10) return StreamConnectionQuality.good;
    if (dropped <= 30) return StreamConnectionQuality.fair;
    return StreamConnectionQuality.poor;
  }

  void _startConnectivityWatch(String endpoint, int bitrate) {
    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      if (results.every((r) => r == ConnectivityResult.none)) return;
      if (!isStreaming &&
          _status == StreamStatus.error &&
          _lastEndpoint != null) {
        try {
          await _startStreamingInternal(
            endpoint: _lastEndpoint!,
            bitrate: _lastBitrate,
            recordPath: _localRecordingPath,
          );
        } catch (_) {}
      }
    });
  }

  Future<void> stopStream() async {
    return _runCameraOperation(() async {
      _healthTimer?.cancel();
      _connectivitySub?.cancel();
      if (_controller != null && isInitialized) {
        try {
          await _controller!.clearStreamOverlay();
        } catch (_) {}
        try {
          await _controller!.stopEverything();
        } catch (_) {}
      }
      _status = StreamStatus.idle;
      notifyListeners();
    });
  }

  /// Reopens the camera preview after RTMP stops (end stream or failed go-live).
  Future<void> resumePreviewAfterStreamEnd() async {
    return _runCameraOperation(() async {
      if (!isPlatformSupported) return;
      if (isStreaming) return;

      try {
        if (_lenses.isEmpty) {
          final cameras = await availableCameras();
          if (cameras.isEmpty) {
            _lastError = 'No camera found on this device.';
            notifyListeners();
            return;
          }
          _lenses = CameraLensCatalog.fromCameras(cameras);
          _selectedLensIndex = _selectedLensIndex.clamp(0, _lenses.length - 1);
        }

        await _releaseCamera(waitForSurfaceTeardown: true);
        await _openSelectedLens();
        await refreshDeviceZoomSteps();
        _lastError = null;
      } catch (e) {
        _lastError = '$e';
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    super.dispose();
    unawaited(_shutdown());
  }

  Future<void> _shutdown() async {
    _healthTimer?.cancel();
    _connectivitySub?.cancel();
    await _releaseCamera(waitForSurfaceTeardown: false);
    _status = StreamStatus.idle;
    if (!_healthController.isClosed) {
      await _healthController.close();
    }
    if (!_orientationLocked) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  static String buildRtmpEndpoint(String rtmpUrl, String streamKey) {
    return StreamCredentialNormalizer.buildEndpoint(rtmpUrl, streamKey);
  }

  ResolutionPreset _mapResolution(StreamResolutionPreset preset) {
    return switch (preset) {
      StreamResolutionPreset.p480 => ResolutionPreset.medium,
      StreamResolutionPreset.p720 => ResolutionPreset.high,
      StreamResolutionPreset.p1080 => ResolutionPreset.veryHigh,
      StreamResolutionPreset.p1440 => ResolutionPreset.ultraHigh,
      StreamResolutionPreset.p4k => ResolutionPreset.max,
    };
  }

  /// Local recording path helper for match streams.
  static Future<String> defaultRecordingPath(String matchId) async {
    final dir = Directory.systemTemp;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/crickflow_${matchId}_$ts.mp4';
  }
}
