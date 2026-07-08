import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../analytics/broadcast_analytics_service.dart';
import '../../../domain/streaming_enums.dart';
import '../../providers/streaming_studio_providers.dart';

/// Compact stream health readout — shown below the studio title on the preview.
class StreamHealthOverlay extends ConsumerWidget {
  const StreamHealthOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(streamHealthProvider).valueOrNull;
    final analytics = ref.watch(broadcastAnalyticsProvider).valueOrNull;
    final stream = ref.watch(streamServiceProvider);
    final cf = context.cf;

    if (health == null) return const SizedBox.shrink();

    final reconnecting =
        health.isReconnecting || stream.isReconnecting;
    final live = stream.isStreaming ||
        stream.isRtmpLive ||
        stream.liveSessionActive ||
        reconnecting;

    if (!live && health.bitrateKbps <= 0 && health.fps <= 0) {
      return Text(
        'Stream health · standby',
        style: TextStyle(
          color: cf.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final qualityLabel = reconnecting
        ? 'Reconnecting'
        : health.connectionQuality.name;
    final upload = analytics?.uploadSpeedKbps;
    final uploadText = upload != null ? ' · ↑${upload.round()} kbps' : '';

    return Text(
      reconnecting
          ? 'Reconnecting…'
          : '${health.bitrateKbps} kbps · ${health.fps} fps · $qualityLabel$uploadText',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: reconnecting ? cf.error : cf.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Standalone realtime stats pill (speed · fps · quality) shown on the preview,
/// outside the title bar. Updates live from the health monitor.
class StreamLiveStatsPill extends ConsumerWidget {
  const StreamLiveStatsPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(streamHealthProvider).valueOrNull;
    final analytics = ref.watch(broadcastAnalyticsProvider).valueOrNull;
    final stream = ref.watch(streamServiceProvider);
    final cf = context.cf;

    if (health == null) return const SizedBox.shrink();

    final reconnecting = health.isReconnecting || stream.isReconnecting;
    final live = stream.isStreaming ||
        stream.isRtmpLive ||
        stream.liveSessionActive ||
        reconnecting;

    if (!live && health.bitrateKbps <= 0 && health.fps <= 0) {
      return const SizedBox.shrink();
    }

    final quality = health.connectionQuality;
    final qualityLabel = reconnecting ? 'Reconnecting' : _qualityLabel(quality);
    final dotColor = streamHealthColor(cf, quality, reconnecting);
    // Prefer measured upload speed; fall back to the encoder target bitrate.
    final upload = analytics?.uploadSpeedKbps;
    final speedKbps = upload != null ? upload.round() : health.bitrateKbps;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reconnecting ? Icons.sync_rounded : Icons.speed_rounded,
              size: 13,
              color: reconnecting ? cf.error : Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              reconnecting
                  ? 'Reconnecting…'
                  : '$speedKbps kbps · ${health.fps} fps',
              style: TextStyle(
                color: reconnecting ? cf.error : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!reconnecting) ...[
              const SizedBox(width: 8),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                qualityLabel,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _qualityLabel(StreamConnectionQuality q) => switch (q) {
      StreamConnectionQuality.excellent => 'Excellent',
      StreamConnectionQuality.good => 'Good',
      StreamConnectionQuality.fair => 'Fair',
      StreamConnectionQuality.poor => 'Poor',
      StreamConnectionQuality.unknown => 'Connecting',
    };

Color streamHealthColor(
  CfColors cf,
  StreamConnectionQuality quality,
  bool reconnecting,
) {
  if (reconnecting) return cf.error;
  return switch (quality) {
    StreamConnectionQuality.excellent => cf.accent,
    StreamConnectionQuality.good => cf.accent,
    StreamConnectionQuality.fair => cf.info,
    StreamConnectionQuality.poor => cf.error,
    _ => cf.textMuted,
  };
}
