import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../data/models/stream_studio_config.dart';
import '../../../domain/streaming_enums.dart';
import '../../providers/streaming_studio_providers.dart';

/// Badge label for the studio destination chip (e.g. YouTube · Automatic).
String streamPlatformBadgeLabel(
  StreamStudioConfig config, {
  bool isObs = false,
}) {
  if (isObs) return 'OBS';
  final name = config.platform.label;
  return switch (config.platform) {
    StreamPlatform.youtube => '$name · ${config.broadcastSetupMode.label}',
    StreamPlatform.facebook || StreamPlatform.customRtmp => '$name · Manual',
    StreamPlatform.twitch => name,
  };
}

/// Ordered setup steps for the active destination.
List<String> streamPlatformSetupSteps(StreamStudioConfig config) {
  return switch (config.platform) {
    StreamPlatform.youtube when config.broadcastSetupMode ==
        StreamBroadcastSetupMode.manual =>
      [
        'In YouTube Studio, open Go live → Stream tab.',
        'Copy the stream key (and confirm RTMP URL if needed).',
        'In CrickFlow, open Broadcast setup and paste the stream key.',
        'Tap Go Live on the camera — video is sent to YouTube ingest.',
        'In YouTube Studio, click Go live when you are ready (unless auto-start is enabled there).',
      ],
    StreamPlatform.youtube => [
      'Link your Google account and pick a YouTube channel.',
      'Set title and visibility, then create the YouTube event in the app.',
      config.goLiveImmediately
          ? 'Tap Go Live — YouTube goes public when video connects.'
          : 'Tap Go Live — preview in YouTube Studio, then click Go live there.',
    ],
    StreamPlatform.facebook => [
      'Open Facebook Live Producer and create a live stream.',
      'Copy the RTMPS server URL and stream key.',
      'In CrickFlow Broadcast setup, paste URL and key, then tap Go Live.',
    ],
    StreamPlatform.customRtmp => [
      'Get the RTMP or RTMPS ingest URL and stream key from your platform.',
      'Enter them in CrickFlow Broadcast setup.',
      'Tap Go Live on the camera when credentials are saved.',
    ],
    StreamPlatform.twitch => ['Twitch is not available in this release.'],
  };
}

String streamPlatformSetupInfoTitle(StreamStudioConfig config) {
  if (config.platform == StreamPlatform.youtube &&
      config.broadcastSetupMode == StreamBroadcastSetupMode.manual) {
    return 'YouTube manual setup';
  }
  return '${config.platform.label} setup';
}

Future<void> showStreamPlatformSetupInfoSheet(
  BuildContext context, {
  required String matchId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => _StreamPlatformSetupInfoSheet(matchId: matchId),
  );
}

class _StreamPlatformSetupInfoSheet extends ConsumerWidget {
  const _StreamPlatformSetupInfoSheet({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final steps = streamPlatformSetupSteps(config);
    final title = streamPlatformSetupInfoTitle(config);

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.32,
      maxChildSize: 0.72,
      builder: (context, scrollController) {
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: cf.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            streamPlatformBadgeLabel(config),
                            style: TextStyle(
                              color: cf.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text(
                      'How to go live',
                      style: TextStyle(
                        color: cf.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < steps.length; i++)
                      _SetupStepLine(cf: cf, n: '${i + 1}', text: steps[i]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SetupStepLine extends StatelessWidget {
  const _SetupStepLine({
    required this.cf,
    required this.n,
    required this.text,
  });

  final CfColors cf;
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cf.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: TextStyle(
                color: cf.accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: cf.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
