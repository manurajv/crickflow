import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/providers.dart';
import '../../domain/camera_control_settings.dart';
import '../../presentation/providers/streaming_studio_providers.dart';

/// Professional camera controls — exposure, WB, focus, HDR, stabilization.
class ProfessionalCameraPanel extends ConsumerWidget {
  const ProfessionalCameraPanel({
    super.key,
    required this.matchId,
    this.enabled = true,
    this.showTorch = true,
  });

  final String matchId;
  final bool enabled;
  final bool showTorch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);
    final camera = config.cameraControls;
    final service = ref.watch(streamServiceProvider);

    return ExpansionTile(
      title: const Text('Pro camera controls'),
      subtitle: const Text('Exposure, focus, white balance, HDR'),
      children: [
        ListTile(
          title: const Text('Exposure compensation'),
          subtitle: Text(camera.exposureCompensation.toStringAsFixed(1)),
          trailing: SizedBox(
            width: 160,
            child: Slider(
              value: camera.exposureCompensation,
              min: -2,
              max: 2,
              divisions: 8,
              label: camera.exposureCompensation.toStringAsFixed(1),
              onChanged: !enabled
                  ? null
                  : (v) async {
                      final next = config.cameraControls.copyWith(
                        exposureCompensation: v,
                      );
                      notifier.update(
                        (c) => c.copyWith(cameraControls: next),
                      );
                      await service.applyCameraControls(next);
                    },
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Focus lock'),
          value: camera.focusLocked,
          onChanged: !enabled
              ? null
              : (v) async {
                  final next = config.cameraControls.copyWith(focusLocked: v);
                  notifier.update((c) => c.copyWith(cameraControls: next));
                  await service.applyCameraControls(next);
                },
        ),
        SwitchListTile(
          title: const Text('Tap to focus'),
          value: camera.tapToFocusEnabled,
          onChanged: !enabled
              ? null
              : (v) => notifier.update(
                    (c) => c.copyWith(
                      cameraControls:
                          c.cameraControls.copyWith(tapToFocusEnabled: v),
                    ),
                  ),
        ),
        ListTile(
          title: const Text('White balance'),
          trailing: DropdownButton<CameraWhiteBalance>(
            value: camera.whiteBalance,
            items: CameraWhiteBalance.values
                .map(
                  (wb) => DropdownMenuItem(
                    value: wb,
                    child: Text(wb.label),
                  ),
                )
                .toList(),
            onChanged: !enabled
                ? null
                : (v) {
                    if (v != null) {
                      notifier.update(
                        (c) => c.copyWith(
                          cameraControls:
                              c.cameraControls.copyWith(whiteBalance: v),
                        ),
                      );
                    }
                  },
          ),
        ),
        SwitchListTile(
          title: const Text('HDR'),
          subtitle: const Text('When supported by device'),
          value: camera.hdrEnabled,
          onChanged: !enabled
              ? null
              : (v) => notifier.update(
                    (c) => c.copyWith(
                      cameraControls:
                          c.cameraControls.copyWith(hdrEnabled: v),
                    ),
                  ),
        ),
        SwitchListTile(
          title: const Text('Image stabilization'),
          value: camera.stabilizationEnabled,
          onChanged: !enabled
              ? null
              : (v) => notifier.update(
                    (c) => c.copyWith(
                      cameraControls: c.cameraControls
                          .copyWith(stabilizationEnabled: v),
                    ),
                  ),
        ),
        if (showTorch)
          SwitchListTile(
            title: const Text('Torch'),
            value: config.torchEnabled,
            onChanged: !enabled || !service.isInitialized
                ? null
                : (v) async {
                    notifier.update((c) => c.copyWith(torchEnabled: v));
                    try {
                      await service.setTorch(v);
                    } catch (_) {}
                  },
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Optical lenses are selected via the lens row. Digital zoom applies only after max optical zoom.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
