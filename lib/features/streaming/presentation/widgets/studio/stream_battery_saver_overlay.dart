import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/services/stream_service.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../analytics/broadcast_analytics_service.dart';
import '../../../domain/streaming_enums.dart';
import '../../providers/streaming_studio_providers.dart';
import '../health/stream_health_overlay.dart';

/// Full-screen black "screen saver" shown over the live preview to save battery.
///
/// The native camera + RTMP pipeline keeps running underneath — this is purely a
/// Flutter visual layer on top, so the broadcast is never disturbed. It still
/// surfaces the essentials (live time, connection quality, speed/fps) and wakes
/// on tap.
class StreamBatterySaverOverlay extends ConsumerStatefulWidget {
  const StreamBatterySaverOverlay({
    super.key,
    required this.liveStartedAt,
    required this.onWake,
  });

  final DateTime? liveStartedAt;
  final VoidCallback onWake;

  @override
  ConsumerState<StreamBatterySaverOverlay> createState() =>
      _StreamBatterySaverOverlayState();
}

class _StreamBatterySaverOverlayState
    extends ConsumerState<StreamBatterySaverOverlay> {
  Timer? _ticker;
  bool _dimmed = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Physically dim the backlight — this is where the real battery saving
    // comes from (an OLED-black overlay alone doesn't cut LCD backlight power).
    _applyDim();
  }

  Future<void> _applyDim() async {
    try {
      await ScreenBrightness().setApplicationScreenBrightness(0.0);
      _dimmed = true;
    } catch (_) {
      // Brightness control unsupported on this device/platform — the black
      // overlay still saves power on OLED screens.
    }
  }

  Future<void> _restoreBrightness() async {
    if (!_dimmed) return;
    _dimmed = false;
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {
      // Best-effort restore.
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_restoreBrightness());
    super.dispose();
  }

  String _liveDuration() {
    final start = widget.liveStartedAt;
    if (start == null) return '00:00';
    final d = DateTime.now().difference(start);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final health = ref.watch(streamHealthProvider).valueOrNull;
    final stream = ref.watch(streamServiceProvider);
    final reconnecting =
        stream.isReconnecting || (health?.isReconnecting ?? false);
    final quality = health?.connectionQuality ?? StreamConnectionQuality.unknown;
    final dotColor = streamHealthColor(cf, quality, reconnecting);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onWake,
        child: ColoredBox(
          color: Colors.black,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LIVE badge + timer, dimmed for OLED battery saving.
                Opacity(
                  opacity: 0.85,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE  ${_liveDuration()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Opacity(
                  opacity: 0.7,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reconnecting ? Icons.sync_rounded : Icons.circle,
                        size: reconnecting ? 14 : 9,
                        color: reconnecting ? Colors.white70 : dotColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        reconnecting
                            ? 'Reconnecting…'
                            : _statsLine(health),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Opacity(
                  opacity: 0.4,
                  child: Text(
                    'Screen dimmed to save battery\nTap anywhere to wake',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statsLine(StreamHealthMetrics? health) {
    if (health == null) return 'Connecting…';
    final analytics = ref.watch(broadcastAnalyticsProvider).valueOrNull;
    final upload = analytics?.uploadSpeedKbps;
    final speed = upload != null ? upload.round() : health.bitrateKbps;
    final label = switch (health.connectionQuality) {
      StreamConnectionQuality.excellent => 'Excellent',
      StreamConnectionQuality.good => 'Good',
      StreamConnectionQuality.fair => 'Fair',
      StreamConnectionQuality.poor => 'Poor',
      StreamConnectionQuality.unknown => 'Connecting',
    };
    return '$label · $speed kbps · ${health.fps} fps';
  }
}
