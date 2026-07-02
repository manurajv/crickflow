import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/providers/providers.dart';
import '../../../domain/streaming_enums.dart';
import '../../providers/streaming_studio_providers.dart';

class CameraLensSelector extends ConsumerWidget {
  const CameraLensSelector({
    super.key,
    required this.matchId,
    required this.onLensSelected,
    this.enabled = true,
  });

  final String matchId;
  final Future<void> Function(int lensIndex) onLensSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(streamServiceProvider);
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final lenses = service.lenses;
    final canSwitch = enabled &&
        !service.isSwitchingLens &&
        (service.isStreaming ? service.canAdjustZoomWhileLive : true);

    if (lenses.isEmpty) {
      return const Text('No cameras detected');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Camera lens', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < lenses.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(lenses[i].label),
                    selected: config.selectedLensIndex == i,
                    onSelected: !canSwitch ? null : (_) => onLensSelected(i),
                  ),
                ),
            ],
          ),
        ),
        if (lenses.length == 1)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Only one back camera detected. Optical telephoto unavailable.',
              style: TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class CameraZoomControl extends ConsumerWidget {
  const CameraZoomControl({
    super.key,
    required this.matchId,
    required this.onLensSelected,
    this.enabled = true,
  });

  final String matchId;
  final Future<void> Function(int lensIndex) onLensSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(streamServiceProvider);
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final lenses = service.lenses.where((l) => !l.isFront).toList();
    final canSwitch = enabled &&
        !service.isSwitchingLens &&
        (service.isStreaming ? service.canAdjustZoomWhileLive : true);

    if (lenses.length <= 1) return const SizedBox.shrink();

    final selectedIndex = lenses.indexWhere(
      (l) => service.lenses.indexOf(l) == config.selectedLensIndex,
    ).clamp(0, lenses.length - 1);
    final currentZoom =
        lenses[selectedIndex.clamp(0, lenses.length - 1)].zoomFactor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Zoom', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(
              '${currentZoom}x',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: selectedIndex.toDouble(),
          min: 0,
          max: (lenses.length - 1).toDouble(),
          divisions: lenses.length - 1,
          label: '${lenses[selectedIndex].zoomFactor}x',
          onChanged: !canSwitch
              ? null
              : (v) {
                  final idx = service.lenses.indexOf(lenses[v.round()]);
                  if (idx >= 0) onLensSelected(idx);
                },
        ),
        Text(
          'Uses physical lenses first; digital zoom when only one sensor is available.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Portrait or landscape broadcast orientation.
class CameraOrientationSelector extends ConsumerWidget {
  const CameraOrientationSelector({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final service = ref.watch(streamServiceProvider);
    final isLandscape = config.orientation == StreamOrientationMode.landscape;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Broadcast orientation',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SegmentedButton<StreamOrientationMode>(
          segments: const [
            ButtonSegment(
              value: StreamOrientationMode.portrait,
              label: Text('Portrait'),
              icon: Icon(Icons.stay_current_portrait_rounded, size: 18),
            ),
            ButtonSegment(
              value: StreamOrientationMode.landscape,
              label: Text('Landscape'),
              icon: Icon(Icons.stay_current_landscape_rounded, size: 18),
            ),
          ],
          selected: {config.orientation},
          onSelectionChanged: (selection) async {
            final mode = selection.first;
            ref
                .read(streamStudioConfigProvider(matchId).notifier)
                .update(
                  (c) => c.copyWith(orientation: mode, orientationLocked: true),
                );
            await service.setOrientationMode(mode);
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await service.toggleOrientation();
            ref.read(streamStudioConfigProvider(matchId).notifier).update(
                  (c) => c.copyWith(
                    orientation: service.orientation,
                    orientationLocked: true,
                  ),
                );
          },
          icon: Icon(
            isLandscape
                ? Icons.stay_current_landscape_rounded
                : Icons.stay_current_portrait_rounded,
          ),
          label: Text('Toggle to ${config.orientation.toggled.studioLabel}'),
        ),
      ],
    );
  }
}

class CameraControlsPanel extends ConsumerWidget {
  const CameraControlsPanel({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return ExpansionTile(
      title: const Text('Camera controls'),
      children: [
        SwitchListTile(
          title: const Text('Torch'),
          value: config.torchEnabled,
          onChanged: (v) => notifier.update((c) => c.copyWith(torchEnabled: v)),
        ),
        SwitchListTile(
          title: const Text('Flash'),
          value: config.flashEnabled,
          onChanged: (v) => notifier.update((c) => c.copyWith(flashEnabled: v)),
        ),
        const ListTile(
          title: Text('Tap to focus / exposure'),
          subtitle: Text('Tap the camera preview while in studio mode'),
        ),
        const ListTile(
          title: Text('HDR / stabilization'),
          subtitle: Text('Uses device defaults when supported'),
        ),
      ],
    );
  }
}
