import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_broadcaster/camera.dart';

import '../../core/constants/enums.dart';
import '../../features/streaming/domain/camera_control_settings.dart';
import '../../features/streaming/domain/stream_credential_normalizer.dart';
import '../../features/streaming/data/models/camera_lens_info.dart';
import '../../features/streaming/services/stream_foreground_bridge.dart';
import '../../features/streaming/services/stream_lifecycle_log.dart';
import '../../features/streaming/domain/streaming_enums.dart';

export '../../features/streaming/data/models/camera_lens_info.dart';

/// Max wait for first RTMP publish during go-live.
const _kGoLiveConnectDeadline = Duration(minutes: 2);

/// Exponential backoff delays for RTMP transport reconnect (ms).
const _kReconnectBackoffMs = [1000, 2000, 4000, 8000, 15000];

const _kMaxReconnectAttempts = 5;

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
  StreamOrientationMode _orientation = StreamOrientationMode.portrait;
  bool _orientationLocked = false;
  bool _liveSessionActive = false;
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
  bool _previewRecovering = false;
  VoidCallback? onRtmpConnected;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _reconnectExhausted = false;
  bool _reconnectInFlight = false;
  bool _networkOnline = true;
  Completer<bool>? _pendingConnectCompleter;
  bool _healthMonitoringActive = false;
  Timer? _connectivityDebounce;
  int _zeroBitrateTicks = 0;
  StreamHealthMetrics _lastHealth = const StreamHealthMetrics();
  bool _rtmpPublishConfirmed = false;
  bool _confirmingPublish = false;
  int _baselineSentVideoFrames = 0;
  // True from the initial go-live connect until the first confirmed publish (or
  // failure). While set, transient transport losses must NOT spin up the
  // persistent reconnect loop — a low-network go-live should fail cleanly
  // instead of getting stuck half-live.
  bool _initialConnectInProgress = false;
  /// True while the native [startVideoStreaming] call is in flight — ignore
  /// stale RTMP_STOPPED events from intentional pre-publish cleanup.
  bool _nativeStreamHandoffPending = false;
  /// After the first RTMP publish confirm, ignore transient transport drops
  /// while the camera/overlay pipeline settles (lifecycle churn, GL relink).
  DateTime? _goLiveSettlingUntil;
  StreamPlatform? _lastConnectPlatform;

  bool get _inGoLiveSettling =>
      _goLiveSettlingUntil != null &&
      DateTime.now().isBefore(_goLiveSettlingUntil!);

  StreamStatus get status => _status;
  String? get lastError => _lastError;
  CameraController? get cameraController => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _controller?.value.isStreamingVideoRtmp ?? false;
  /// True when RTMP is connected AND video frames are reaching the destination.
  bool get isRtmpLive => _rtmpPublishConfirmed && _status == StreamStatus.live;
  bool get isSwitchingLens => _switchingLens;
  /// Zoom / back lens changes are supported while RTMP is active.
  bool get canAdjustZoomWhileLive => isInitialized && _controller != null;
  List<CameraLensInfo> get lenses => _lenses;
  int get selectedLensIndex => _selectedLensIndex;
  StreamOrientationMode get orientation => _orientation;
  bool get orientationLocked => _orientationLocked;
  bool get liveSessionActive => _liveSessionActive;
  bool get reconnectExhausted => _reconnectExhausted;
  /// Path of the most recent local recording (MP4), if record-locally was on.
  String? get lastRecordingPath => _localRecordingPath;
  bool get isReconnecting {
    if (_reconnectExhausted) return false;
    final sessionActive = _liveSessionActive || _lastEndpoint != null;
    if (!sessionActive) return false;
    if (_reconnectInFlight || _reconnectTimer != null) return true;
    if (!_networkOnline &&
        (_status == StreamStatus.live || _status == StreamStatus.connecting)) {
      return true;
    }
    if (_status == StreamStatus.connecting && !_rtmpPublishConfirmed) {
      return true;
    }
    // Native RTMP dropped but Dart state still thinks we are live.
    if (_status == StreamStatus.live &&
        _rtmpPublishConfirmed &&
        !isStreaming &&
        _networkOnline) {
      return true;
    }
    return false;
  }
  bool get networkOnline => _networkOnline;
  Stream<StreamHealthMetrics> get healthStream => _healthController.stream;

  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initCamera({
    int lensIndex = 0,
    StreamResolutionPreset resolution = StreamResolutionPreset.p720,
    StreamOrientationMode orientation = StreamOrientationMode.portrait,
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
      _orientation = parseStreamOrientation(orientation.name);
      _orientationLocked = lockOrientation;
      _micEnabled = enableAudio;
      _resolutionPreset = _mapResolution(resolution);

      await _applyDeviceOrientation();

      await _releaseCamera(waitForSurfaceTeardown: false);
      await _openSelectedLens();

      // Rebuild the zoom row with the device's real max zoom so it shows the
      // standard 0.5x/1x/2x/3x set (digital steps included) immediately, rather
      // than waiting on the post-mount refresh.
      try {
        final prevFactor =
            _lenses[_selectedLensIndex.clamp(0, _lenses.length - 1)].zoomFactor;
        final maxZoom = await _controller!.getMaxZoom();
        _lenses = CameraLensCatalog.standardZoomLenses(cameras, maxZoom);
        _selectedLensIndex =
            CameraLensCatalog.indexForZoomFactor(_lenses, prevFactor);
      } catch (_) {}

      _lastError = null;
      notifyListeners();
    });
  }

  /// Switches optical lens or digital zoom without tearing down RTMP when live.
  Future<void> switchLens(int index) {
    return _runCameraOperation(() async {
      if (index < 0 || index >= _lenses.length) return;
      if (_selectedLensIndex == index && isInitialized) return;

      _switchingLens = true;
      try {
        final lens = _lenses[index];
        final current = _lenses[_selectedLensIndex];
        final live = isStreaming;

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
          if (live) {
            throw StateError('Stop the stream before switching front/back camera.');
          }
          _selectedLensIndex = index;
          await _controller!.flipCamera();
          await _applyZoomForLens(lens);
          _lastError = null;
          notifyListeners();
          return;
        }

        // Physical camera switch while preview or RTMP is active.
        if (isInitialized && _controller != null) {
          _selectedLensIndex = index;
          await _controller!.switchCameraById(lens.description.name!);
          await _applyZoomForLens(lens);
          _lastError = null;
          notifyListeners();
          return;
        }

        if (live) {
          throw StateError('Camera not ready to change zoom while live.');
        }

        // Cold start / re-open fallback (pre-live only).
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

  /// Apply exposure compensation (EV steps).
  Future<void> setExposureCompensation(double ev) async {
    if (_controller == null || !isInitialized) return;
    try {
      await _applyNativeWithRetry(
        () => _controller!.setExposureCompensation(ev),
      );
    } on CameraException catch (e) {
      _lastError = e.description ?? e.code;
    }
  }

  /// Mute or unmute the microphone on the active RTMP stream.
  Future<void> setMicEnabled(bool enabled) async {
    _micEnabled = enabled;
    if (_controller == null || !isInitialized) return;
    try {
      await _controller!.setMicMuted(!enabled);
    } on CameraException catch (e) {
      _lastError = e.description ?? e.code;
    }
  }

  /// Apply pro camera settings from the studio config.
  Future<void> applyCameraControls(CameraControlSettings settings) async {
    await setExposureCompensation(settings.exposureCompensation);
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
    await _syncNativeOrientationMode();
    _attachCameraListener();
  }

  /// Re-open the camera preview after the app returns from background or the
  /// display turns off (Android often tears down the GL surface).
  Future<void> resumePreviewAfterBackground() {
    return recoverPreview();
  }

  /// Restores preview after stream end, screen lock, or a dead GL surface.
  Future<void> recoverPreview() {
    return _runCameraOperation(() async {
      if (!isPlatformSupported) return;
      if (isStreaming && _lastEndpoint != null) {
        await reconnectPreview();
        notifyListeners();
        return;
      }

      _previewRecovering = true;
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

        final lens = _lenses[_selectedLensIndex];
        var recovered = false;

        if (_controller != null && isInitialized) {
          try {
            await _controller!.restartPreview();
            await _waitForNativePreviewReady();
            recovered = isInitialized;
          } catch (_) {
            recovered = false;
          }
        }

        if (!recovered) {
          await _releaseCamera(waitForSurfaceTeardown: true);
          await _openSelectedLens();
        }

        await _syncNativeOrientationMode();
        await _applyZoomAfterPreviewReady(lens);
        _lastError = null;
      } catch (e) {
        _lastError = '$e';
      } finally {
        _previewRecovering = false;
      }
      notifyListeners();
    });
  }

  Future<void> _waitForNativePreviewReady() async {
    for (var i = 0; i < 12; i++) {
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(Duration(milliseconds: 50 * (i + 1)));
      if (_controller?.value.isInitialized == true) return;
    }
  }

  Future<void> _applyZoomAfterPreviewReady(CameraLensInfo lens) async {
    await _waitForNativePreviewReady();
    try {
      await _applyZoomForLens(lens);
    } catch (_) {}
  }

  /// Call after [CameraPreview] is mounted so the native view exists.
  Future<void> refreshDeviceZoomSteps() async {
    if (_controller == null || !isInitialized || _previewRecovering) return;
    try {
      final maxZoom = await _controller!.getMaxZoom();
      final cameras = await availableCameras();
      final prevFactor = _lenses.isNotEmpty
          ? _lenses[_selectedLensIndex.clamp(0, _lenses.length - 1)].zoomFactor
          : 1.0;
      if (cameras.isNotEmpty) {
        _lenses = CameraLensCatalog.standardZoomLenses(cameras, maxZoom);
      } else {
        _lenses = CameraLensCatalog.enrichWithDigitalZoom(_lenses, maxZoom);
      }
      _selectedLensIndex =
          CameraLensCatalog.indexForZoomFactor(_lenses, prevFactor);
      await _waitForNativePreviewReady();
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
    for (var attempt = 0; attempt < 12; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 60 * attempt));
        await SchedulerBinding.instance.endOfFrame;
      }
      try {
        await _controller!.setZoom(level);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    // Native side queues pending zoom — do not fail recovery.
    if (lastError != null && !isStreaming) throw lastError;
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
    if (lastError != null) throw lastError;
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

  /// Starts Android foreground protection for an active live session.
  Future<void> beginLiveSession({required String title}) async {
    _liveSessionActive = true;
    await StreamForegroundBridge.start(title: title);
    if (_rtmpPublishConfirmed && !_healthMonitoringActive) {
      _startHealthMonitoring();
      _healthMonitoringActive = true;
    }
    notifyListeners();
  }

  /// Ends foreground protection — call when broadcast stops.
  Future<void> endLiveSession() async {
    _liveSessionActive = false;
    await StreamForegroundBridge.stop();
    notifyListeners();
  }

  /// Reattaches GL preview without stopping RTMP (safe while live).
  Future<void> reconnectPreviewWhileLive() => reconnectPreview();

  /// Reattaches preview surface after rotation or Activity resume.
  Future<void> reconnectPreview({int retries = 6}) async {
    if (_uiOrientationChanging) return;
    if (_controller == null || !isInitialized) return;
    final live = isStreaming && _lastEndpoint != null;
    if (!live && (isReconnecting || !_networkOnline)) return;
    if (!live) {
      await recoverPreview();
      return;
    }
    _previewRecovering = true;
    try {
      for (var attempt = 0; attempt < retries; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
        }
        await SchedulerBinding.instance.endOfFrame;
        try {
          await _controller!.restartPreview();
          await _waitForNativePreviewReady();
          if (_lenses.isNotEmpty) {
            await _applyZoomForLens(
              _lenses[_selectedLensIndex.clamp(0, _lenses.length - 1)],
            );
          }
          return;
        } catch (_) {}
      }
    } finally {
      _previewRecovering = false;
    }
  }

  /// True while the studio UI is rotating — skips native preview reconnect.
  bool _uiOrientationChanging = false;

  /// Portrait ↔ landscape — UI and overlays only; camera preview is unchanged.
  Future<void> toggleOrientation() async {
    _orientation = _orientation.toggled;
    _orientationLocked = true;
    _uiOrientationChanging = true;
    try {
      await _applyDeviceOrientation();
      notifyListeners();
      await SchedulerBinding.instance.endOfFrame;
    } finally {
      _uiOrientationChanging = false;
      notifyListeners();
    }
  }

  Future<void> setOrientationMode(StreamOrientationMode mode) async {
    _orientation = parseStreamOrientation(mode.name);
    _orientationLocked = true;
    _uiOrientationChanging = true;
    try {
      await _applyDeviceOrientation();
      notifyListeners();
      await SchedulerBinding.instance.endOfFrame;
    } finally {
      _uiOrientationChanging = false;
      notifyListeners();
    }
  }

  Future<void> lockOrientation(StreamOrientationMode mode) async {
    _orientation = parseStreamOrientation(mode.name);
    _orientationLocked = true;
    await _applyDeviceOrientation();
    await _syncNativeOrientationMode();
  }

  /// Returns UI to portrait after leaving stream studio / ending a broadcast.
  Future<void> resetToPortraitUi() async {
    _orientationLocked = false;
    _orientation = StreamOrientationMode.portrait;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await _syncNativeOrientationMode(fixedMode: StreamOrientationMode.portrait);
  }

  /// Notifies native encoder of broadcast orientation (stream metadata only).
  /// Does not reconfigure the camera preview.
  Future<void> _syncNativeOrientationMode({
    StreamOrientationMode? fixedMode,
  }) async {
    if (_controller == null || !isInitialized) return;
    final mode = fixedMode ?? _orientation;
    try {
      await _controller!.setOrientationMode(
        autoRotate: false,
        mode: mode.nativeModeName,
      );
    } catch (_) {}
  }

  /// Keeps the Activity in portrait so the native camera surface is never resized
  /// or rotated. Landscape broadcast mode only changes Flutter UI + encoder metadata.
  Future<void> _applyDeviceOrientation() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> startStream({
    required String rtmpUrl,
    required String streamKey,
    int? bitrate,
    StreamResolutionPreset resolution = StreamResolutionPreset.p720,
    String? localRecordingPath,
    StreamPlatform? platform,
  }) async {
    _lastConnectPlatform = platform;
    _goLiveSettlingUntil = null;
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

    // Stream output orientation only — preview stays as initialized.
    await _syncNativeOrientationMode();

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
    _reconnectAttempt = 0;
    _reconnectExhausted = false;
    _initialConnectInProgress = true;
    _cancelReconnectTimer();
    _pendingConnectCompleter = Completer<bool>();
    _startConnectivityWatch(endpoint, bitrate);

    try {
      _nativeStreamHandoffPending = true;
      if (recordPath != null && recordPath.isNotEmpty) {
        await _controller!.startVideoRecordingAndStreaming(
          recordPath,
          endpoint,
          bitrate: bitrate,
          micEnabled: _micEnabled,
        );
      } else {
        await _controller!.startVideoStreaming(
          endpoint,
          bitrate: bitrate,
          micEnabled: _micEnabled,
        );
      }
    } finally {
      _nativeStreamHandoffPending = false;
    }

    try {
      final connected = await _pendingConnectCompleter!.future.timeout(
        _kGoLiveConnectDeadline,
        onTimeout: () => false,
      );
      if (!connected) {
        _status = StreamStatus.error;
        _lastError ??=
            'Could not connect to the streaming server. Check your network, '
            'RTMP URL, and stream key, then try again.';
        notifyListeners();
        throw StateError(_lastError!);
      }
      _lastError = null;
    } on CameraException catch (e) {
      _status = StreamStatus.error;
      final raw = e.description ?? e.code;
      _lastError = _friendlyRtmpError(raw);
      rethrow;
    } finally {
      _pendingConnectCompleter = null;
      _initialConnectInProgress = false;
    }
  }

  bool get _rtmpSessionActive =>
      _lastEndpoint != null &&
      (_status == StreamStatus.connecting ||
          _status == StreamStatus.live ||
          _liveSessionActive);

  void _attachCameraListener() {
    if (_controller == null) return;
    if (_cameraListener != null) {
      _controller!.removeListener(_cameraListener!);
    }
    _cameraListener = () {
      final event = _controller!.value.event;
      if (event is! Map) return;
      if (_nativeStreamHandoffPending) return;
      final type = event['eventType'] as String?;
      final reason = event['errorDescription'] as String?;
      if (type == 'rtmp_retry') {
        _onRtmpTransportLost(reason: reason);
      } else if (type == 'rtmp_connected') {
        _onRtmpTransportConnected();
      } else if (type == 'rtmp_stopped') {
        // Ignore spurious stop while native is still publishing during republish.
        if (_reconnectInFlight && isStreaming) return;
        if (_reconnectInFlight) _reconnectInFlight = false;
        if (_inGoLiveSettling && _rtmpPublishConfirmed) return;
        if (_initialConnectInProgress && !_rtmpPublishConfirmed) {
          // Keep waiting for the initial connect attempt — do not abort early.
          if (reason != null &&
              reason.isNotEmpty &&
              reason.toLowerCase() != 'disconnected') {
            _lastError = _friendlyRtmpError(reason);
          }
          return;
        }
        if (_rtmpSessionActive && !_reconnectExhausted) {
          _onRtmpTransportLost(reason: reason);
        } else {
          _status = StreamStatus.ended;
          if (reason != null && reason.isNotEmpty) {
            _lastError = _friendlyRtmpError(reason);
          }
          _pendingConnectCompleter?.complete(false);
          notifyListeners();
        }
      }
    };
    _controller!.addListener(_cameraListener!);
  }

  void _onRtmpTransportLost({String? reason}) {
    if (!_rtmpSessionActive && !_liveSessionActive) return;
    if (_inGoLiveSettling && _rtmpPublishConfirmed) return;
    _rtmpPublishConfirmed = false;
    _confirmingPublish = false;
    _status = StreamStatus.connecting;
    if (reason != null && reason.isNotEmpty) {
      _lastError = _friendlyRtmpError(reason);
    }
    _emitHealth(reconnecting: true);
    notifyListeners();
    // During the very first go-live connect, do not spin up the persistent
    // reconnect loop on a transient drop — let the 2 min connect window finish.
    if (_initialConnectInProgress && !_rtmpPublishConfirmed) {
      if (reason != null &&
          reason.isNotEmpty &&
          reason.toLowerCase() != 'disconnected') {
        _lastError = _friendlyRtmpError(reason);
      }
      if (reason != null && _isDefinitiveRtmpFailure(reason)) {
        _pendingConnectCompleter?.complete(false);
      }
      return;
    }
    if (!_reconnectExhausted &&
        (_liveSessionActive || _healthMonitoringActive || _lastEndpoint != null)) {
      _scheduleReconnectTransport();
    }
  }

  void _onRtmpTransportConnected() {
    if (_confirmingPublish) return;
    _confirmingPublish = true;
    unawaited(_confirmRtmpPublishing());
  }

  Future<void> _confirmRtmpPublishing() async {
    try {
      final reconnectAttempt = _reconnectAttempt > 0 || _reconnectInFlight;
      _baselineSentVideoFrames = await _readSentVideoFrames();
      final deadline = DateTime.now().add(_kGoLiveConnectDeadline);
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (_controller == null) break;

        final sent = await _readSentVideoFrames();
        final bitrate = await _readBitrateKbps();
        final publishing = sent > _baselineSentVideoFrames ||
            (sent >= 3 && bitrate > 0) ||
            (reconnectAttempt && bitrate > 0);

        if (publishing) {
          _markRtmpPublishConfirmed(wasReconnecting: reconnectAttempt);
          return;
        }
      }

      _pendingConnectCompleter?.complete(false);
      if (_healthMonitoringActive || _liveSessionActive) {
        _lastError ??=
            'Could not reach the streaming server. Check your network and stream key.';
        _onRtmpTransportLost();
      }
    } finally {
      _confirmingPublish = false;
    }
  }

  Future<int> _readSentVideoFrames() async {
    if (_controller == null) return 0;
    try {
      final stats = await _controller!.getStreamStatistics().timeout(
        const Duration(seconds: 2),
      );
      return stats.sentVideoFrames ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _readBitrateKbps() async {
    if (_controller == null) return 0;
    try {
      final stats = await _controller!.getStreamStatistics().timeout(
        const Duration(seconds: 2),
      );
      return ((stats.bitrate ?? 0) / 1024).round();
    } catch (_) {
      return 0;
    }
  }

  void _markRtmpPublishConfirmed({required bool wasReconnecting}) {
    _rtmpPublishConfirmed = true;
    _initialConnectInProgress = false;
    _status = StreamStatus.live;
    _reconnectAttempt = 0;
    _reconnectExhausted = false;
    _reconnectInFlight = false;
    _cancelReconnectTimer();
    _zeroBitrateTicks = 0;
    _emitHealth(reconnecting: false);
    if (!_healthMonitoringActive) {
      StreamLifecycleLog.liveStarted();
    } else if (wasReconnecting) {
      StreamLifecycleLog.retrySuccess();
      StreamLifecycleLog.rtmpReconnected();
    }
    _goLiveSettlingUntil = DateTime.now().add(const Duration(seconds: 4));
    _pendingConnectCompleter?.complete(true);
    final callback = onRtmpConnected;
    if (callback != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_rtmpPublishConfirmed && _status == StreamStatus.live) {
          callback();
        }
      });
    }
    notifyListeners();
  }

  void _scheduleReconnectTransport() {
    if (_inGoLiveSettling && _rtmpPublishConfirmed) return;
    if (!_rtmpSessionActive && !_liveSessionActive) return;
    if (_controller == null || _lastEndpoint == null) return;
    if (_reconnectTimer != null || _reconnectInFlight) return;

    // Pause retries until connectivity returns — do not burn attempts offline.
    if (!_networkOnline) return;

    if (_reconnectAttempt >= _kMaxReconnectAttempts) {
      _onReconnectExhausted();
      return;
    }

    final delayMs = _kReconnectBackoffMs[_reconnectAttempt];
    final attemptNumber = _reconnectAttempt + 1;
    StreamLifecycleLog.retry(attemptNumber);
    _reconnectAttempt = attemptNumber;

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      _reconnectTimer = null;
      unawaited(_attemptRtmpReconnect());
    });
    notifyListeners();
  }

  Future<void> _attemptRtmpReconnect() async {
    if (!_rtmpSessionActive && !_liveSessionActive) return;
    if (_controller == null || _lastEndpoint == null) return;
    if (!_networkOnline) {
      _reconnectInFlight = false;
      return;
    }

    _reconnectInFlight = true;
    _rtmpPublishConfirmed = false;
    _confirmingPublish = false;
    try {
      await _controller!.reconnectRtmpTransport(
        url: _lastEndpoint,
        bitrate: _lastBitrate,
      ).timeout(
        const Duration(seconds: 15),
      );
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!_rtmpSessionActive && !_liveSessionActive) return;
        if (_reconnectExhausted) return;
        if (_rtmpPublishConfirmed) return;
      }
      _reconnectInFlight = false;
      if ((_rtmpSessionActive || _liveSessionActive) && !_reconnectExhausted) {
        _scheduleReconnectTransport();
      }
    } catch (_) {
      _reconnectInFlight = false;
      if ((_rtmpSessionActive || _liveSessionActive) &&
          !_reconnectExhausted &&
          _networkOnline) {
        _scheduleReconnectTransport();
      }
    }
  }

  void _onNetworkLost() {
    if (!_liveSessionActive && _lastEndpoint == null) return;
    _networkOnline = false;
    _rtmpPublishConfirmed = false;
    _confirmingPublish = false;
    _cancelReconnectTimer();
    _reconnectInFlight = false;
    StreamLifecycleLog.networkLost();
    if (_status == StreamStatus.live || _status == StreamStatus.connecting) {
      _status = StreamStatus.connecting;
      _emitHealth(reconnecting: true);
      notifyListeners();
    }
  }

  void _onNetworkRestored() {
    if (!_liveSessionActive && _lastEndpoint == null) return;
    _networkOnline = true;
    _reconnectExhausted = false;
    _reconnectAttempt = 0;
    _reconnectInFlight = false;
    _cancelReconnectTimer();
    _zeroBitrateTicks = 0;
    if (_status == StreamStatus.live || _status == StreamStatus.connecting) {
      _status = StreamStatus.connecting;
      _emitHealth(reconnecting: true);
      notifyListeners();
      _scheduleReconnectTransport();
    }
  }

  void _emitHealth({
    bool? reconnecting,
    int? bitrateKbps,
    int? fps,
    int? droppedVideoFrames,
    int? droppedAudioFrames,
    StreamConnectionQuality? connectionQuality,
  }) {
    _lastHealth = StreamHealthMetrics(
      bitrateKbps: bitrateKbps ?? _lastHealth.bitrateKbps,
      fps: fps ?? _lastHealth.fps,
      droppedVideoFrames: droppedVideoFrames ?? _lastHealth.droppedVideoFrames,
      droppedAudioFrames: droppedAudioFrames ?? _lastHealth.droppedAudioFrames,
      uploadSpeedKbps: _lastHealth.uploadSpeedKbps,
      connectionQuality: connectionQuality ?? _lastHealth.connectionQuality,
      batteryPercent: _lastHealth.batteryPercent,
      isReconnecting:
          reconnecting ?? (_status == StreamStatus.connecting || !_networkOnline),
    );
    _healthController.add(_lastHealth);
  }

  void _onReconnectExhausted() {
    _cancelReconnectTimer();
    _reconnectExhausted = true;
    _reconnectInFlight = false;
    _emitHealth(reconnecting: false);
    StreamLifecycleLog.retryFailed();
    _pendingConnectCompleter?.complete(false);
    notifyListeners();
    unawaited(_recoverAfterReconnectExhausted());
  }

  Future<void> _recoverAfterReconnectExhausted() async {
    if (_controller == null || !isInitialized) return;
    try {
      await _controller!.recoverRtmpReconnectState();
    } catch (_) {}
    await reconnectPreview(retries: 4);
    notifyListeners();
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Manual retry after reconnect attempts are exhausted — reuses go-live endpoint.
  Future<void> retryConnection({String? endpoint, int? bitrate}) async {
    if (_lastEndpoint == null ||
        _status == StreamStatus.idle ||
        _status == StreamStatus.ended) {
      return;
    }
    if (endpoint != null && endpoint.isNotEmpty) {
      _lastEndpoint = endpoint;
    }
    if (bitrate != null && bitrate > 0) {
      _lastBitrate = bitrate;
    }
    _reconnectExhausted = false;
    _reconnectAttempt = 0;
    _cancelReconnectTimer();
    _status = StreamStatus.connecting;
    _emitHealth(reconnecting: true);
    notifyListeners();
    await _attemptRtmpReconnect();
  }

  /// Hard stop when the app is removed from Recents — no camera preview recovery.
  Future<void> emergencyStopLive() async {
    _cancelReconnectTimer();
    _pendingConnectCompleter?.complete(false);
    _pendingConnectCompleter = null;
    _healthTimer?.cancel();
    _healthMonitoringActive = false;
    _connectivityDebounce?.cancel();
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _reconnectAttempt = 0;
    _reconnectExhausted = false;
    _reconnectInFlight = false;
    _rtmpPublishConfirmed = false;
    _confirmingPublish = false;
    _goLiveSettlingUntil = null;
    onRtmpConnected = null;

    if (_controller != null && isInitialized) {
      try {
        await _controller!.clearStreamOverlay();
      } catch (_) {}
      try {
        await _controller!.stopEverything();
      } catch (_) {}
    }

    _liveSessionActive = false;
    _status = StreamStatus.idle;
    _lastEndpoint = null;
    await StreamForegroundBridge.stop();
    StreamLifecycleLog.liveStopped();
    notifyListeners();
  }

  void _startHealthMonitoring() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_controller == null) return;
      if (!_liveSessionActive && _lastEndpoint == null) return;

      if (!_networkOnline || _status == StreamStatus.connecting) {
        _emitHealth(reconnecting: true);
        return;
      }

      if (!isStreaming) {
        if (_inGoLiveSettling && _rtmpPublishConfirmed) return;
        if ((_liveSessionActive || _lastEndpoint != null) &&
            !_reconnectExhausted &&
            !_reconnectInFlight &&
            _reconnectTimer == null &&
            _rtmpPublishConfirmed &&
            _status == StreamStatus.live) {
          _onRtmpTransportLost();
        } else if (isReconnecting) {
          _emitHealth(reconnecting: true);
        }
        return;
      }

      try {
        final stats = await _controller!.getStreamStatistics().timeout(
          const Duration(seconds: 2),
        );
        final dropped = stats.droppedVideoFrames ?? 0;
        final quality = _qualityFromDrops(dropped);
        final bitrateKbps = ((stats.bitrate ?? 0) / 1024).round();

        if (_status == StreamStatus.live &&
            _rtmpPublishConfirmed &&
            _networkOnline &&
            bitrateKbps <= 0) {
          _zeroBitrateTicks++;
          if (_zeroBitrateTicks >= 3) {
            _zeroBitrateTicks = 0;
            _onRtmpTransportLost();
            return;
          }
        } else {
          _zeroBitrateTicks = 0;
        }

        _emitHealth(
          reconnecting: false,
          bitrateKbps: bitrateKbps,
          fps: 30,
          droppedVideoFrames: dropped,
          droppedAudioFrames: stats.droppedAudioFrames ?? 0,
          connectionQuality: quality,
        );
      } on TimeoutException {
        if (_status == StreamStatus.live && !_inGoLiveSettling) {
          _onRtmpTransportLost();
        }
      } catch (_) {
        if (_status == StreamStatus.live && _networkOnline) {
          _emitHealth(reconnecting: true);
        }
      }
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
    _connectivityDebounce?.cancel();
    unawaited(Connectivity().checkConnectivity().then((results) {
      _networkOnline = _hasNetwork(results);
    }));
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!_liveSessionActive && _lastEndpoint == null) return;
      _connectivityDebounce?.cancel();
      _connectivityDebounce = Timer(const Duration(milliseconds: 500), () {
        _handleConnectivityChange(results);
      });
    });
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (!_liveSessionActive && _lastEndpoint == null) return;

    final online = _hasNetwork(results);

    if (!online && _networkOnline) {
      _onNetworkLost();
    } else if (online && !_networkOnline) {
      _onNetworkRestored();
    } else if (online &&
        (_liveSessionActive || _lastEndpoint != null) &&
        !_reconnectExhausted &&
        _reconnectTimer == null &&
        !_reconnectInFlight &&
        (!_rtmpPublishConfirmed || _status == StreamStatus.connecting)) {
      _scheduleReconnectTransport();
    }
  }

  Future<void> stopStream() async {
    return _runCameraOperation(() async {
      _cancelReconnectTimer();
      _connectivityDebounce?.cancel();
      _pendingConnectCompleter?.complete(false);
      _pendingConnectCompleter = null;
      _healthTimer?.cancel();
      _healthMonitoringActive = false;
      _connectivitySub?.cancel();
      _connectivitySub = null;
      _reconnectAttempt = 0;
      _reconnectExhausted = false;
      _reconnectInFlight = false;
      _rtmpPublishConfirmed = false;
      _confirmingPublish = false;
      _initialConnectInProgress = false;
      if (_controller != null && isInitialized) {
        try {
          await _controller!.clearStreamOverlay();
        } catch (_) {}
        try {
          await _controller!.stopEverything();
        } catch (_) {}
      }
      _status = StreamStatus.idle;
      _lastEndpoint = null;
      StreamLifecycleLog.liveStopped();
      notifyListeners();
    });
  }

  /// Reopens the camera preview after RTMP stops (end stream or failed go-live).
  Future<void> resumePreviewAfterStreamEnd() => recoverPreview();

  @override
  void dispose() {
    super.dispose();
    unawaited(_shutdown());
  }

  Future<void> _shutdown() async {
    _cancelReconnectTimer();
    _healthTimer?.cancel();
    _connectivitySub?.cancel();
    _connectivitySub = null;
    await _releaseCamera(waitForSurfaceTeardown: false);
    _status = StreamStatus.idle;
    _liveSessionActive = false;
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

  /// Maps native RTMP failure reasons to actionable copy for the broadcaster.
  String _friendlyRtmpError(String reason) {
    final lower = reason.toLowerCase();
    if (lower == 'disconnected' || lower.contains('socket is not connected')) {
      return 'Connection lost. Check your network and stream key, then try again.';
    }
    if (lower.contains('connect error') || lower.contains('time out')) {
      return 'Could not connect to the streaming server. Check your network, '
          'RTMP URL, and stream key.';
    }
    if (lower.contains('publish permitted')) {
      if (_lastConnectPlatform == StreamPlatform.facebook) {
        return 'Facebook rejected the stream key. In Facebook Live Producer, '
            'create or open a live video, then paste the stream key and try again.';
      }
      return 'YouTube rejected the stream key. In YouTube Studio, click Go live '
          'first (or use a persistent stream key), then try again.';
    }
    if (lower.contains('auth')) {
      return 'RTMP authentication failed. Check your stream key and server URL.';
    }
    if (lower.contains('badname')) {
      return 'Invalid RTMP stream name. Check that the stream key is correct '
          'and the live broadcast is active on the platform.';
    }
    return reason;
  }

  static bool _isDefinitiveRtmpFailure(String reason) {
    final lower = reason.toLowerCase();
    return lower.contains('publish permitted') ||
        lower.contains('auth error') ||
        lower.contains('authfail') ||
        lower.contains('endpoint malformed') ||
        lower.contains('badname') ||
        lower.contains('bad name');
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

  /// Local recording path helper for match streams. Uses a persistent
  /// app-scoped directory (not the temp cache) so the MP4 survives until it is
  /// exported to the gallery after the stream ends.
  static Future<String> defaultRecordingPath(String matchId) async {
    Directory dir;
    try {
      dir = await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = Directory.systemTemp;
    }
    final recordings = Directory('${dir.path}/recordings');
    try {
      if (!await recordings.exists()) {
        await recordings.create(recursive: true);
      }
      dir = recordings;
    } catch (_) {
      // Fall back to the base directory if the subfolder can't be created.
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/crickflow_${matchId}_$ts.mp4';
  }
}
