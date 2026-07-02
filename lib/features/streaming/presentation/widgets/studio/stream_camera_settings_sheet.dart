import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../shared/providers/providers.dart';
import '../../providers/streaming_studio_providers.dart';

/// Compact exposure slider — opened from the studio overlay.
Future<void> showStreamCameraSettingsSheet(
  BuildContext context, {
  required String matchId,
  required bool cameraReady,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => _ExposureSheet(
      matchId: matchId,
      cameraReady: cameraReady,
    ),
  );
}

class _ExposureSheet extends ConsumerWidget {
  const _ExposureSheet({
    required this.matchId,
    required this.cameraReady,
  });

  final String matchId;
  final bool cameraReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);
    final service = ref.read(streamServiceProvider);
    final ev = config.cameraControls.exposureCompensation;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cf.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: cf.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cf.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Exposure',
                      style: TextStyle(
                        color: cf.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Done', style: TextStyle(color: cf.accent)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '−2',
                        style: TextStyle(color: cf.textMuted, fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: ev,
                          min: -2,
                          max: 2,
                          divisions: 8,
                          label: ev.toStringAsFixed(1),
                          activeColor: cf.accent,
                          onChanged: !cameraReady
                              ? null
                              : (v) async {
                                  final next = config.cameraControls.copyWith(
                                    exposureCompensation: v,
                                  );
                                  notifier.update(
                                    (c) => c.copyWith(cameraControls: next),
                                  );
                                  await service.setExposureCompensation(v);
                                },
                        ),
                      ),
                      Text(
                        '+2',
                        style: TextStyle(color: cf.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  Center(
                    child: Text(
                      ev.toStringAsFixed(1),
                      style: TextStyle(
                        color: cf.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
