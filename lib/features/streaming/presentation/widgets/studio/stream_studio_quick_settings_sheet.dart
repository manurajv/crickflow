import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
import '../../../camera/presentation/professional_camera_panel.dart';
import '../../../settings/presentation/stream_mode_selector.dart';
import '../../providers/streaming_studio_providers.dart';
import '../camera/stream_camera_controls.dart';
import 'stream_setup_bottom_sheet.dart';
import 'stream_setup_checklist.dart';

Future<void> showStreamStudioQuickSettingsSheet(
  BuildContext context, {
  required String matchId,
  required MatchModel match,
  required bool canStart,
  required bool cameraReady,
  required VoidCallback onOpenBroadcastSetup,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return _QuickSettingsSheet(
          scrollController: scrollController,
          matchId: matchId,
          match: match,
          canStart: canStart,
          cameraReady: cameraReady,
          onOpenBroadcastSetup: onOpenBroadcastSetup,
        );
      },
    ),
  );
}

class _QuickSettingsSheet extends ConsumerWidget {
  const _QuickSettingsSheet({
    required this.scrollController,
    required this.matchId,
    required this.match,
    required this.canStart,
    required this.cameraReady,
    required this.onOpenBroadcastSetup,
  });

  final ScrollController scrollController;
  final String matchId;
  final MatchModel match;
  final bool canStart;
  final bool cameraReady;
  final VoidCallback onOpenBroadcastSetup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cf.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: cf.border)),
      ),
      child: Column(
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Stream settings',
                    style: TextStyle(
                      color: cf.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onOpenBroadcastSetup();
                  },
                  child: Text(
                    'Broadcast',
                    style: TextStyle(color: cf.accent),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                StreamSetupChecklist(matchId: matchId, compact: true),
                const SizedBox(height: 12),
                StreamModeSelector(matchId: matchId),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Record locally', style: TextStyle(color: cf.textPrimary)),
                  value: config.recordLocally,
                  activeTrackColor: cf.accent,
                  onChanged: (v) =>
                      notifier.update((c) => c.copyWith(recordLocally: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Auto replay markers', style: TextStyle(color: cf.textPrimary)),
                  value: config.autoReplayMarkers,
                  activeTrackColor: cf.accent,
                  onChanged: (v) =>
                      notifier.update((c) => c.copyWith(autoReplayMarkers: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Score ticker', style: TextStyle(color: cf.textPrimary)),
                  value: config.showTicker,
                  activeTrackColor: cf.accent,
                  onChanged: (v) =>
                      notifier.update((c) => c.copyWith(showTicker: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Sponsor banner', style: TextStyle(color: cf.textPrimary)),
                  value: config.showSponsorBanner,
                  activeTrackColor: cf.accent,
                  onChanged: (v) =>
                      notifier.update((c) => c.copyWith(showSponsorBanner: v)),
                ),
                const SizedBox(height: 8),
                CameraOrientationSelector(matchId: matchId),
                if (cameraReady) ...[
                  const SizedBox(height: 8),
                  ProfessionalCameraPanel(matchId: matchId, enabled: true),
                  const SizedBox(height: 8),
                  CameraControlsPanel(matchId: matchId),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showStreamSetupSheet(
                      context,
                      matchId: matchId,
                      match: match,
                      canStart: canStart,
                      cameraLoading: !cameraReady,
                      onOpenBroadcastSetup: onOpenBroadcastSetup,
                    );
                  },
                  icon: Icon(Icons.open_in_new, color: cf.accent),
                  label: Text(
                    'Full setup (quality, overlays, recording)',
                    style: TextStyle(color: cf.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
