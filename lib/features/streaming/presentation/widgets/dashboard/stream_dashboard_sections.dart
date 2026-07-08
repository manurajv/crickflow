import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../domain/streaming_enums.dart';
import '../../../domain/streaming_mode.dart';
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
            Text(
              'Applied on next go-live · ${config.effectiveBitrateKbps} kbps target',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final options = supportedStreamResolutionsFor(
                platform: config.platform,
                setupMode: config.broadcastSetupMode,
              );
              final selected = options.contains(config.resolution)
                  ? config.resolution
                  : kRecommendedStreamResolution;
              return DropdownButtonFormField<StreamResolutionPreset>(
                value: selected,
                decoration: const InputDecoration(labelText: 'Resolution'),
                items: options
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            r == kRecommendedStreamResolution
                                ? '${r.mapping.label} (Recommended)'
                                : r.mapping.label,
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    notifier.update((c) => c.copyWith(resolution: v));
                  }
                },
              );
            }),
            if (!streamSupports1080p(
              platform: config.platform,
              setupMode: config.broadcastSetupMode,
            ))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '1080p is available only on YouTube in Automatic mode. '
                  'Manual RTMP (YouTube manual, Facebook, custom) supports up to 720p.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            DropdownButtonFormField<StreamFps>(
              value: config.fps,
              decoration: const InputDecoration(labelText: 'Frame rate'),
              items: StreamFps.values
                  .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.update((c) => c.copyWith(fps: v));
              },
            ),
            DropdownButtonFormField<StreamBitrateMode>(
              value: config.bitrateMode,
              decoration: const InputDecoration(labelText: 'Bitrate mode'),
              items: StreamBitrateMode.values
                  .map((b) => DropdownMenuItem(value: b, child: Text(b.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) notifier.update((c) => c.copyWith(bitrateMode: v));
              },
            ),
            if (config.bitrateMode == StreamBitrateMode.manual)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${config.manualBitrateKbps} kbps'),
                subtitle: Slider(
                  value: config.manualBitrateKbps.toDouble(),
                  min: 800,
                  max: 12000,
                  divisions: 46,
                  label: '${config.manualBitrateKbps} kbps',
                  onChanged: (v) => notifier.update(
                    (c) => c.copyWith(manualBitrateKbps: v.round()),
                  ),
                ),
              ),
            DropdownButtonFormField<StreamLatencyPreset>(
              value: config.latency,
              decoration: const InputDecoration(labelText: 'Latency profile'),
              items: StreamLatencyPreset.values
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
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
              onChanged: (v) async {
                notifier.update((c) => c.copyWith(micEnabled: v));
                await ref.read(streamServiceProvider).setMicEnabled(v);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Noise suppression'),
              subtitle: const Text('Applied on next go-live'),
              value: config.noiseSuppression,
              onChanged: (v) =>
                  notifier.update((c) => c.copyWith(noiseSuppression: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Echo cancellation'),
              subtitle: const Text('Applied on next go-live'),
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

class StreamObsQualityNote extends StatelessWidget {
  const StreamObsQualityNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Encoder quality'),
        subtitle: Text(
          'OBS / external encoder mode uses your encoder settings. '
          'Configure resolution and bitrate in OBS.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class StreamSettingsSectionHeader extends StatelessWidget {
  const StreamSettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: color,
        ),
      ),
    );
  }
}

bool streamSettingsShowNativeEncoderOptions(StreamingMode mode) =>
    mode == StreamingMode.nativeCamera;
