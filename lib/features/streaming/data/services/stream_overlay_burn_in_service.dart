import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';
import '../../../../data/services/stream_service.dart';
import '../../data/models/stream_studio_config.dart';
import '../../domain/streaming_enums.dart';

/// 2× logical pixels for crisp scorebug text; native GL scales to encoder frame.
const _kOverlayCapturePixelRatio = 1.0;

/// Bumped on Android lifecycle resume while live — forces capture tree rebuild.
final overlayLifecycleRecoveryProvider = StateProvider<int>((ref) => 0);

/// Captures Flutter overlay widgets and pushes PNG frames to native RTMP burn-in.
class StreamOverlayBurnInService {
  StreamOverlayBurnInService(this._ref);

  final Ref _ref;
  final GlobalKey repaintKey = GlobalKey();
  Timer? _debounce;
  Timer? _liveRefreshTimer;
  int _generation = 0;
  int _pushCount = 0;
  bool _lifecycleRecoveryInFlight = false;

  bool _isLiveSession(StreamService stream) =>
      stream.liveSessionActive ||
      stream.isStreaming ||
      stream.isRtmpLive ||
      (stream.isReconnecting && !stream.reconnectExhausted);

  void schedulePush({bool force = false}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(pushNow(force: force));
      });
    });
  }

  /// Keeps RTMP overlay in sync with scorebug and event graphics while live.
  void startLiveRefresh() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final stream = _ref.read(streamServiceProvider);
      if (_isLiveSession(stream)) {
        final force = stream.isRtmpLive &&
            !stream.isReconnecting &&
            stream.networkOnline;
        schedulePush(force: force);
      } else {
        stopLiveRefresh();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      schedulePush();
      // Encoder GL filter attaches after RTMP connects and OpenGlView is ready.
      Future<void>.delayed(const Duration(milliseconds: 800), schedulePush);
      Future<void>.delayed(const Duration(milliseconds: 2000), schedulePush);
    });
  }

  void stopLiveRefresh() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;
  }

  /// Restores native GL overlay + re-captures Flutter overlay after surface/GL recreation.
  Future<void> recoverAfterLifecycle() async {
    if (_lifecycleRecoveryInFlight) return;
    final stream = _ref.read(streamServiceProvider);
    if (!stream.isStreaming && !stream.liveSessionActive && !stream.isRtmpLive) return;

    _lifecycleRecoveryInFlight = true;
    try {
      _ref.read(overlayLifecycleRecoveryProvider.notifier).state++;
      startLiveRefresh();

      const delaysMs = <int>[0, 150, 300, 450, 600, 800, 1000, 1200];
      for (final delayMs in delaysMs) {
        if (delayMs > 0) {
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
        final live = _ref.read(streamServiceProvider);
        if (!_isLiveSession(live)) return;

        await _restoreNativeOverlayPipeline();
        await SchedulerBinding.instance.endOfFrame;

        final ok = await pushNow(force: true);
        if (ok) {
          _log('overlay recovered after lifecycle');
          return;
        }
      }
      _log('overlay lifecycle recovery exhausted retries');
    } finally {
      _lifecycleRecoveryInFlight = false;
    }
  }

  Future<void> _restoreNativeOverlayPipeline() async {
    final controller = _ref.read(streamServiceProvider).cameraController;
    if (controller == null || !(controller.value.isInitialized ?? false)) {
      return;
    }
    try {
      await controller.restoreStreamOverlayPipeline();
    } catch (e) {
      _log('native overlay pipeline restore failed: $e');
    }
  }

  /// Returns true when a PNG frame was sent to the native compositor.
  Future<bool> pushNow({bool force = false}) async {
    final stream = _ref.read(streamServiceProvider);
    if (!_isLiveSession(stream)) {
      _log('push skipped — not streaming');
      return false;
    }
    if (!force && (stream.isReconnecting || !stream.networkOnline)) {
      _log('push skipped — reconnecting or offline');
      return false;
    }
    final controller = stream.cameraController;
    if (controller == null || !(controller.value.isInitialized ?? false)) {
      _log('push skipped — camera not initialized');
      return false;
    }

    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      _log('push skipped — RepaintBoundary not mounted');
      return false;
    }

    boundary.markNeedsPaint();
    final painted = await _waitUntilPainted(boundary);
    if (!painted) {
      _log('push skipped — overlay tree not painted yet');
      return false;
    }

    final gen = ++_generation;
    try {
      final image = await boundary.toImage(pixelRatio: _kOverlayCapturePixelRatio);
      if (gen != _generation) {
        image.dispose();
        return false;
      }
      final width = image.width;
      final height = image.height;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null || gen != _generation) {
        _log('push skipped — PNG encode failed');
        return false;
      }

      final png = byteData.buffer.asUint8List();
      if (png.length < 512) {
        _log('push skipped — PNG too small (${png.length} bytes), overlay not painted');
        return false;
      }

      _pushCount++;
      if (_pushCount <= 3 || _pushCount % 25 == 0) {
        _log(
          'overlay rendered ${width}x$height (${png.length} bytes) → native compositor (#$_pushCount)',
        );
      }

      await controller.updateStreamOverlay(
        png,
        width: width,
        height: height,
      );
      _ref.read(streamOverlayBurnInActiveProvider.notifier).state = true;
      if (_pushCount <= 3 || _pushCount % 25 == 0) {
        _log('frame sent to encoder (#$_pushCount)');
      }
      return true;
    } catch (e, st) {
      _log('push failed: $e\n$st');
      return false;
    }
  }

  Future<void> clear() async {
    _debounce?.cancel();
    stopLiveRefresh();
    _generation++;
    _pushCount = 0;
    _lifecycleRecoveryInFlight = false;
    _ref.read(streamOverlayBurnInActiveProvider.notifier).state = false;
    final controller = _ref.read(streamServiceProvider).cameraController;
    if (controller == null) return;
    try {
      await controller.clearStreamOverlay();
      _log('overlay cleared');
    } catch (e) {
      _log('clear failed: $e');
    }
  }

  void dispose() {
    _debounce?.cancel();
    stopLiveRefresh();
  }

  /// [Offstage] and [Visibility.visible=false] skip painting — only capture
  /// trees that are painted can be passed to [RenderRepaintBoundary.toImage].
  Future<bool> _waitUntilPainted(
    RenderRepaintBoundary boundary, {
    int maxFrames = 8,
  }) async {
    for (var i = 0; i < maxFrames; i++) {
      await SchedulerBinding.instance.endOfFrame;
      if (!boundary.debugNeedsPaint) return true;
    }
    return !boundary.debugNeedsPaint;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[CrickFlowStream] $message');
    }
  }
}

final streamOverlayBurnInActiveProvider = StateProvider<bool>((ref) => false);

final streamOverlayBurnInServiceProvider = Provider<StreamOverlayBurnInService>(
  (ref) {
    final service = StreamOverlayBurnInService(ref);
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Overlay PNG capture size from studio config — never from native stats (avoids live drift).
Size encoderFrameSizeFor(StreamStudioConfig config) {
  final base = switch (config.resolution) {
    StreamResolutionPreset.p480 => const Size(854, 480),
    StreamResolutionPreset.p720 => const Size(1280, 720),
    StreamResolutionPreset.p1080 => const Size(1920, 1080),
    StreamResolutionPreset.p1440 => const Size(2560, 1440),
    StreamResolutionPreset.p4k => const Size(3840, 2160),
  };
  if (config.orientation == StreamOrientationMode.landscape) {
    return base;
  }
  return Size(base.height, base.width);
}

/// Same as [encoderFrameSizeFor] — capture size is locked from config for the live session.
Future<Size> encoderFrameSizeForLive(
  StreamStudioConfig config,
  dynamic cameraController,
) async {
  return encoderFrameSizeFor(config);
}

/// Max short-side (in px) for the Flutter overlay capture layer.
///
/// The overlay PNG is scaled to the encoder frame by native GL, so it does not
/// need to match encoder pixels. Capping the offscreen raster avoids GPU/native
/// OOM crashes at 1080p/1440p/4K while keeping scorebug text crisp.
const double _kMaxOverlayCaptureShortSide = 720;

/// Aspect-preserving capture size for the overlay burn-in tree, capped so high
/// encoder resolutions never allocate an oversized offscreen layer.
Size overlayCaptureSizeFor(StreamStudioConfig config) {
  final encoder = encoderFrameSizeFor(config);
  final short = encoder.shortestSide;
  if (short <= _kMaxOverlayCaptureShortSide || short <= 0) return encoder;
  final scale = _kMaxOverlayCaptureShortSide / short;
  return Size(
    (encoder.width * scale).roundToDouble(),
    (encoder.height * scale).roundToDouble(),
  );
}
