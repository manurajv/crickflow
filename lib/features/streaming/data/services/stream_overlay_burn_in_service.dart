import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';
import '../../data/models/stream_studio_config.dart';
import '../../domain/streaming_enums.dart';

/// Captures Flutter overlay widgets and pushes PNG frames to native RTMP burn-in.
class StreamOverlayBurnInService {
  StreamOverlayBurnInService(this._ref);

  final Ref _ref;
  final GlobalKey repaintKey = GlobalKey();
  Timer? _debounce;
  Timer? _liveRefreshTimer;
  int _generation = 0;
  int _pushCount = 0;

  void schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(pushNow());
      });
    });
  }

  /// Keeps RTMP overlay in sync with scorebug and event graphics while live.
  void startLiveRefresh() {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_ref.read(streamServiceProvider).isStreaming) {
        schedulePush();
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

  Future<void> pushNow() async {
    final stream = _ref.read(streamServiceProvider);
    if (!stream.isStreaming) {
      _log('push skipped — not streaming');
      return;
    }
    final controller = stream.cameraController;
    if (controller == null || !(controller.value.isInitialized ?? false)) {
      _log('push skipped — camera not initialized');
      return;
    }

    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      _log('push skipped — RepaintBoundary not mounted');
      return;
    }

    boundary.markNeedsPaint();
    final painted = await _waitUntilPainted(boundary);
    if (!painted) {
      _log('push skipped — overlay tree not painted yet');
      return;
    }

    final gen = ++_generation;
    try {
      final image = await boundary.toImage(pixelRatio: 1.0);
      if (gen != _generation) {
        image.dispose();
        return;
      }
      final width = image.width;
      final height = image.height;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null || gen != _generation) {
        _log('push skipped — PNG encode failed');
        return;
      }

      final png = byteData.buffer.asUint8List();
      if (png.length < 512) {
        _log('push skipped — PNG too small (${png.length} bytes), overlay not painted');
        return;
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
      if (_pushCount <= 3 || _pushCount % 25 == 0) {
        _log('frame sent to encoder (#$_pushCount)');
      }
    } catch (e, st) {
      _log('push failed: $e\n$st');
    }
  }

  Future<void> clear() async {
    _debounce?.cancel();
    stopLiveRefresh();
    _generation++;
    _pushCount = 0;
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
      debugPrint('[StreamOverlayBurnIn] $message');
    }
  }
}

final streamOverlayBurnInServiceProvider = Provider<StreamOverlayBurnInService>(
  (ref) {
    final service = StreamOverlayBurnInService(ref);
    ref.onDispose(service.dispose);
    return service;
  },
);

/// Encoder frame size for RTMP overlay PNG capture (landscape dimensions).
Size encoderFrameSizeFor(StreamStudioConfig config) {
  final base = switch (config.resolution) {
    StreamResolutionPreset.p480 => const Size(854, 480),
    StreamResolutionPreset.p720 => const Size(1280, 720),
    StreamResolutionPreset.p1080 => const Size(1920, 1080),
    StreamResolutionPreset.p1440 => const Size(2560, 1440),
    StreamResolutionPreset.p4k => const Size(3840, 2160),
  };
  if (config.orientation == StreamOrientationMode.portrait) {
    return Size(base.height, base.width);
  }
  return base;
}

/// Prefer native encoder dimensions when the RTMP session is active.
Future<Size> encoderFrameSizeForLive(
  StreamStudioConfig config,
  dynamic cameraController,
) async {
  if (cameraController != null) {
    try {
      final stats = await cameraController.getStreamStatistics();
      final w = stats.width;
      final h = stats.height;
      if (w != null && h != null && w > 0 && h > 0) {
        return Size(w.toDouble(), h.toDouble());
      }
    } catch (_) {}
  }
  return encoderFrameSizeFor(config);
}
