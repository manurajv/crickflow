import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  void schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      unawaited(pushNow());
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
      // Encoder GL filter may attach only after RTMP connects.
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
    if (!stream.isStreaming) return;
    final controller = stream.cameraController;
    if (controller == null || !(controller.value.isInitialized ?? false)) {
      return;
    }

    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

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
      if (byteData == null || gen != _generation) return;

      await controller.updateStreamOverlay(
        byteData.buffer.asUint8List(),
        width: width,
        height: height,
      );
    } catch (_) {
      // Overlay burn-in is best-effort; preview overlays still work.
    }
  }

  Future<void> clear() async {
    _debounce?.cancel();
    stopLiveRefresh();
    _generation++;
    final controller = _ref.read(streamServiceProvider).cameraController;
    if (controller == null) return;
    try {
      await controller.clearStreamOverlay();
    } catch (_) {}
  }

  void dispose() {
    _debounce?.cancel();
    stopLiveRefresh();
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
