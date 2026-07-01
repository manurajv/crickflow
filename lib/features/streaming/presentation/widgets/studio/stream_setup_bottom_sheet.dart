import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
import '../../../data/models/stream_studio_config.dart';
import '../../../domain/streaming_enums.dart';
import '../../../camera/presentation/professional_camera_panel.dart';
import '../../../settings/presentation/stream_mode_selector.dart';
import '../camera/stream_camera_controls.dart';
import '../dashboard/stream_dashboard_sections.dart';
import '../health/stream_health_panel.dart';
import '../../providers/streaming_studio_providers.dart';
import 'stream_setup_checklist.dart';

/// Opens stream configuration in a modal draggable bottom sheet.
Future<void> showStreamSetupSheet(
  BuildContext context, {
  required String matchId,
  required MatchModel match,
  required bool canStart,
  required bool cameraLoading,
  required VoidCallback onOpenBroadcastSetup,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return _StreamSetupSheetBody(
          scrollController: scrollController,
          matchId: matchId,
          match: match,
          canStart: canStart,
          cameraLoading: cameraLoading,
          onOpenBroadcastSetup: onOpenBroadcastSetup,
        );
      },
    ),
  );
}

class _StreamSetupSheetBody extends ConsumerWidget {
  const _StreamSetupSheetBody({
    required this.scrollController,
    required this.matchId,
    required this.match,
    required this.canStart,
    required this.cameraLoading,
    required this.onOpenBroadcastSetup,
  });

  final ScrollController scrollController;
  final String matchId;
  final MatchModel match;
  final bool canStart;
  final bool cameraLoading;
  final VoidCallback onOpenBroadcastSetup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cf.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: cf.border)),
        boxShadow: [
          BoxShadow(
            color: cf.cardShadow.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: cf.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: cf.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stream setup',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: cf.textPrimary,
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
                        'Only organizers, streamers, or scorers can go live.',
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
                const SizedBox(height: 10),
                _SectionHeader(cf: cf, title: 'Orientation & camera'),
                CameraOrientationSelector(matchId: matchId),
                const SizedBox(height: 6),
                ProfessionalCameraPanel(matchId: matchId, enabled: !cameraLoading),
                const SizedBox(height: 6),
                CameraControlsPanel(matchId: matchId),
                const SizedBox(height: 12),
                _SectionHeader(cf: cf, title: 'Quality & audio'),
                StreamQualitySection(matchId: matchId),
                StreamAudioSection(matchId: matchId),
                const SizedBox(height: 12),
                _SectionHeader(cf: cf, title: 'Overlays & recording'),
                StreamOverlaySettingsSection(matchId: matchId),
                StreamRecordingSection(matchId: matchId),
                const SizedBox(height: 10),
                const StreamHealthPanel(),
                const SizedBox(height: 24),
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
          configured
              ? '$platformLabel · tap to review or start live'
              : 'YouTube, Facebook Live, or custom RTMP',
          style: TextStyle(color: cf.textSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: cf.accent),
        onTap: onOpen,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.cf, required this.title});

  final CfColors cf;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: cf.accent,
        ),
      ),
    );
  }
}
