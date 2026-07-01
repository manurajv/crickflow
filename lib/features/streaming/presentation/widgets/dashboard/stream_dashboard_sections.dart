import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/models/match_model.dart';
import '../../../domain/streaming_enums.dart';
import '../../providers/streaming_studio_providers.dart';

class StreamMatchInfoSection extends StatelessWidget {
  const StreamMatchInfoSection({super.key, required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(match.title),
        subtitle: Text('${match.teamAName} vs ${match.teamBName}'),
        trailing: _statusBadge(match.status),
      ),
    );
  }

  Widget _statusBadge(MatchStatus status) {
    final label = status.name.toUpperCase();
    return Chip(label: Text(label, style: const TextStyle(fontSize: 10)));
  }
}

class StreamQualitySection extends ConsumerWidget {
  const StreamQualitySection({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Video quality',
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<StreamResolutionPreset>(
              value: config.resolution,
              decoration: const InputDecoration(labelText: 'Resolution'),
              items: StreamResolutionPreset.values
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.mapping.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.update((c) => c.copyWith(resolution: v));
              },
            ),
            DropdownButtonFormField<StreamFps>(
              value: config.fps,
              decoration: const InputDecoration(labelText: 'FPS'),
              items: StreamFps.values
                  .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.update((c) => c.copyWith(fps: v));
              },
            ),
            DropdownButtonFormField<StreamBitrateMode>(
              value: config.bitrateMode,
              decoration: const InputDecoration(labelText: 'Bitrate'),
              items: StreamBitrateMode.values
                  .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.update((c) => c.copyWith(bitrateMode: v));
              },
            ),
            DropdownButtonFormField<StreamLatencyPreset>(
              value: config.latency,
              decoration: const InputDecoration(labelText: 'Latency'),
              items: StreamLatencyPreset.values
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.update((c) => c.copyWith(latency: v));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class StreamAudioSection extends ConsumerWidget {
  const StreamAudioSection({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Audio', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Microphone'),
              value: config.micEnabled,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(micEnabled: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Noise suppression'),
              value: config.noiseSuppression,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(noiseSuppression: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Echo cancellation'),
              value: config.echoCancellation,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(echoCancellation: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gain'),
              subtitle: Slider(
                value: config.micGain,
                min: 0.5,
                max: 2,
                divisions: 6,
                label: config.micGain.toStringAsFixed(1),
                onChanged: (v) =>
                    notifier.update((c) => c.copyWith(micGain: v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StreamOverlaySettingsSection extends ConsumerWidget {
  const StreamOverlaySettingsSection({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overlay settings',
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<StreamOverlayLayout>(
              value: config.overlayLayout,
              decoration: const InputDecoration(labelText: 'Layout'),
              items: StreamOverlayLayout.values
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.name)))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.update((c) => c.copyWith(overlayLayout: v));
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sponsor banner'),
              value: config.showSponsorBanner,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(showSponsorBanner: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('CrickFlow watermark'),
              value: config.showWatermark,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(showWatermark: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Overlay opacity'),
              subtitle: Slider(
                value: config.overlayOpacity,
                min: 0.5,
                max: 1,
                onChanged: (v) =>
                    notifier.update((c) => c.copyWith(overlayOpacity: v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StreamRecordingSection extends ConsumerWidget {
  const StreamRecordingSection({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Record locally while streaming'),
            subtitle: const Text('Saved as MP4 on device'),
            value: config.recordLocally,
            onChanged: (v) =>
                notifier.update((c) => c.copyWith(recordLocally: v)),
          ),
          SwitchListTile(
            title: const Text('Auto replay markers'),
            subtitle: const Text(
              'Flag wickets, boundaries, and milestones for highlights',
            ),
            value: config.autoReplayMarkers,
            onChanged: (v) =>
                notifier.update((c) => c.copyWith(autoReplayMarkers: v)),
          ),
        ],
      ),
    );
  }
}
