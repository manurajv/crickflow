import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/services/stream_service.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../analytics/broadcast_analytics_service.dart';
import '../../../domain/streaming_enums.dart';
import '../../providers/streaming_studio_providers.dart';

class StreamHealthPanel extends ConsumerWidget {
  const StreamHealthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(streamHealthProvider);
    final analyticsAsync = ref.watch(broadcastAnalyticsProvider);
    final streamService = ref.watch(streamServiceProvider);

    return healthAsync.when(
      data: (metrics) => analyticsAsync.when(
        data: (analytics) => _HealthCard(
          metrics: metrics,
          analytics: analytics,
          isLive: streamService.isStreaming,
        ),
        loading: () => _HealthCard(
          metrics: metrics,
          analytics: const BroadcastAnalyticsSnapshot(),
          isLive: streamService.isStreaming,
        ),
        error: (_, __) => _HealthCard(
          metrics: metrics,
          analytics: const BroadcastAnalyticsSnapshot(),
          isLive: streamService.isStreaming,
        ),
      ),
      loading: () => const _HealthCard(
        metrics: StreamHealthMetrics(),
        analytics: BroadcastAnalyticsSnapshot(),
        isLive: false,
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.metrics,
    required this.analytics,
    required this.isLive,
  });

  final StreamHealthMetrics metrics;
  final BroadcastAnalyticsSnapshot analytics;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Stream Health',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (metrics.isReconnecting)
                  const Chip(
                    label: Text('Reconnecting'),
                    backgroundColor: AppColors.gold,
                  )
                else if (isLive)
                  _qualityChip(metrics.connectionQuality),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _metric('Bitrate', '${metrics.bitrateKbps} kbps'),
                _metric('FPS', '${metrics.fps}'),
                _metric('Dropped', '${metrics.droppedVideoFrames}'),
                _metric('Audio drops', '${metrics.droppedAudioFrames}'),
                _metric('Network', analytics.networkType),
                if (analytics.uploadSpeedKbps != null)
                  _metric(
                    'Upload',
                    '${analytics.uploadSpeedKbps!.round()} kbps',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _qualityChip(StreamConnectionQuality q) {
    final color = switch (q) {
      StreamConnectionQuality.excellent => AppColors.accentGreen,
      StreamConnectionQuality.good => AppColors.primaryBlueLight,
      StreamConnectionQuality.fair => AppColors.gold,
      StreamConnectionQuality.poor => AppColors.accentRed,
      _ => AppColors.textMuted,
    };
    return Chip(
      label: Text(q.name.toUpperCase()),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: color, fontSize: 11),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
