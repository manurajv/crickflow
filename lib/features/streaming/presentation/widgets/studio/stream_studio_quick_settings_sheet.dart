import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
import '../../../data/models/stream_studio_config.dart';
import '../../../domain/streaming_enums.dart';
import '../../../domain/streaming_mode.dart';
import '../../../settings/presentation/stream_mode_selector.dart';
import '../../providers/streaming_studio_providers.dart';
import '../camera/stream_camera_controls.dart';
import '../dashboard/stream_dashboard_sections.dart';
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
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return _StreamSettingsSheet(
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

/// Alias kept for any legacy callers.
Future<void> showStreamSetupSheet(
  BuildContext context, {
  required String matchId,
  required MatchModel match,
  required bool canStart,
  required bool cameraLoading,
  required VoidCallback onOpenBroadcastSetup,
}) {
  return showStreamStudioQuickSettingsSheet(
    context,
    matchId: matchId,
    match: match,
    canStart: canStart,
    cameraReady: !cameraLoading,
    onOpenBroadcastSetup: onOpenBroadcastSetup,
  );
}

class _StreamSettingsSheet extends ConsumerWidget {
  const _StreamSettingsSheet({
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
    final isNative = config.streamingMode == StreamingMode.nativeCamera;

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: cf.accent, size: 18),
                const SizedBox(width: 8),
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
                  child: Text('Broadcast', style: TextStyle(color: cf.accent)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Done', style: TextStyle(color: cf.accent)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cf.border),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceSm,
                AppDimens.spaceMd,
                AppDimens.spaceLg,
              ),
              children: [
                if (!canStart)
                  Card(
                    color: cf.error,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        'Streaming restricted',
                        style: TextStyle(color: cf.textPrimary, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Sign in with a CrickFlow account to go live.',
                        style: TextStyle(
                          color: cf.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                StreamSetupChecklist(matchId: matchId, compact: true),
                const SizedBox(height: 10),
                _BroadcastSetupCard(
                  cf: cf,
                  config: config,
                  onOpen: () {
                    Navigator.pop(context);
                    onOpenBroadcastSetup();
                  },
                ),
                const SizedBox(height: 10),
                StreamMatchInfoSection(match: match),
                const SizedBox(height: 10),
                StreamModeSelector(matchId: matchId),
                const SizedBox(height: 12),
                const StreamSettingsSectionHeader(title: 'Highlights'),
                // NOTE: "Record locally" is hidden for now — feature to be
                // completed later. See recordLocally in StreamStudioConfig.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Auto replay markers',
                    style: TextStyle(color: cf.textPrimary),
                  ),
                  subtitle: Text(
                    'Flags wickets, boundaries, and milestones for highlights',
                    style: TextStyle(color: cf.textSecondary, fontSize: 12),
                  ),
                  value: config.autoReplayMarkers,
                  activeTrackColor: cf.accent,
                  onChanged: (v) => notifier
                      .update((c) => c.copyWith(autoReplayMarkers: v)),
                ),
                if (isNative) ...[
                  const SizedBox(height: 12),
                  const StreamSettingsSectionHeader(title: 'Orientation'),
                  CameraOrientationSelector(matchId: matchId),
                  const SizedBox(height: 12),
                  const StreamSettingsSectionHeader(title: 'Quality & audio'),
                  StreamQualitySection(matchId: matchId),
                  StreamAudioSection(matchId: matchId),
                ] else ...[
                  const SizedBox(height: 12),
                  const StreamSettingsSectionHeader(title: 'Encoder'),
                  const StreamObsQualityNote(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastSetupCard extends StatelessWidget {
  const _BroadcastSetupCard({
    required this.cf,
    required this.config,
    required this.onOpen,
  });

  final CfColors cf;
  final StreamStudioConfig config;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final configured = config.isBroadcastConfigured;
    final platformLabel = config.platform.label;
    final setupHint = switch (config.platform) {
      StreamPlatform.youtube when config.broadcastSetupMode ==
              StreamBroadcastSetupMode.automatic =>
        'YouTube automatic · linked Google account',
      StreamPlatform.youtube => 'YouTube manual · stream key',
      StreamPlatform.facebook => 'Facebook Live · manual RTMP',
      _ => 'Custom RTMP',
    };

    return Card(
      child: ListTile(
        leading: Icon(
          configured ? Icons.check_circle : Icons.live_tv,
          color: configured ? cf.accent : cf.textSecondary,
        ),
        title: Text(
          configured ? 'Broadcast configured' : 'Configure broadcast',
          style: TextStyle(
            color: cf.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          configured ? '$platformLabel · $setupHint' : setupHint,
          style: TextStyle(color: cf.textSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: cf.accent),
        onTap: onOpen,
      ),
    );
  }
}
