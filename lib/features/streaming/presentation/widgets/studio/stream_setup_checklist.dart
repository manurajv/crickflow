import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../data/models/stream_studio_config.dart';
import '../../../domain/streaming_enums.dart';
import '../../providers/streaming_studio_providers.dart';

enum StreamSetupStepStatus { done, pending, optional }

class StreamSetupStep {
  const StreamSetupStep({
    required this.title,
    required this.subtitle,
    required this.status,
    this.actionLabel,
  });

  final String title;
  final String subtitle;
  final StreamSetupStepStatus status;
  final String? actionLabel;
}

List<StreamSetupStep> buildStreamSetupSteps(StreamStudioConfig config) {
  final hasKey = config.streamKey.trim().isNotEmpty;
  final hasUrl = config.rtmpUrl.trim().isNotEmpty;
  final isManualYouTube = config.platform == StreamPlatform.youtube &&
      config.broadcastSetupMode == StreamBroadcastSetupMode.manual;
  final isAutoYouTube = config.platform == StreamPlatform.youtube &&
      config.broadcastSetupMode == StreamBroadcastSetupMode.automatic;

  return switch (config.platform) {
    StreamPlatform.youtube when isManualYouTube => [
        StreamSetupStep(
          title: 'YouTube · Manual',
          subtitle: 'Paste stream key from YouTube Studio',
          status: StreamSetupStepStatus.done,
        ),
        StreamSetupStep(
          title: 'Enter stream key',
          subtitle: hasKey
              ? 'Stream key saved'
              : 'Copy from YouTube Studio → Go Live → Stream',
          status: hasKey
              ? StreamSetupStepStatus.done
              : StreamSetupStepStatus.pending,
        ),
      ],
    StreamPlatform.youtube when isAutoYouTube => [
        StreamSetupStep(
          title: 'YouTube · Automatic',
          subtitle: 'Link account and create event in the app',
          status: StreamSetupStepStatus.done,
        ),
        StreamSetupStep(
          title: 'YouTube delivery',
          subtitle: config.goLiveImmediately
              ? 'Go public on YouTube when video connects'
              : 'Preview in YouTube Studio first — you click Go live',
          status: StreamSetupStepStatus.done,
        ),
        StreamSetupStep(
          title: 'Connect Google account',
          subtitle: config.youtubeChannelId.isNotEmpty
              ? config.youtubeChannelName.isNotEmpty
                  ? config.youtubeChannelName
                  : 'Account linked'
              : 'Sign in with Google to create broadcasts',
          status: config.youtubeChannelId.isNotEmpty
              ? StreamSetupStepStatus.done
              : StreamSetupStepStatus.pending,
        ),
        StreamSetupStep(
          title: 'Create YouTube broadcast',
          subtitle: hasKey || config.youtubeBroadcastId.isNotEmpty
              ? (config.youtubeBroadcastId.isNotEmpty
                  ? 'YouTube event created'
                  : 'Stream key saved')
              : 'Tap "Create YouTube live broadcast" or go live to create one',
          status: hasKey || config.youtubeBroadcastId.isNotEmpty
              ? StreamSetupStepStatus.done
              : StreamSetupStepStatus.pending,
        ),
        StreamSetupStep(
          title: 'Stream title',
          subtitle: config.title.trim().isNotEmpty
              ? config.title
              : 'Add a title for the YouTube event',
          status: config.title.trim().isNotEmpty
              ? StreamSetupStepStatus.done
              : StreamSetupStepStatus.optional,
        ),
      ],
    StreamPlatform.youtube => [
        StreamSetupStep(
          title: 'Choose YouTube',
          subtitle: 'Automatic or manual setup',
          status: StreamSetupStepStatus.done,
        ),
      ],
    StreamPlatform.facebook => [
        StreamSetupStep(
          title: 'Choose Facebook Live',
          subtitle: 'Manual RTMP from Facebook Live Producer',
          status: StreamSetupStepStatus.done,
        ),
        StreamSetupStep(
          title: 'Select RTMP server',
          subtitle: hasUrl
              ? config.rtmpUrl
              : 'Pick the Facebook Live RTMPS server',
          status: hasUrl
              ? StreamSetupStepStatus.done
              : StreamSetupStepStatus.pending,
        ),
        StreamSetupStep(
          title: 'Enter stream key',
          subtitle: hasKey
              ? 'Stream key saved'
              : 'Copy from Facebook → Live → Use stream key',
          status: hasKey
              ? StreamSetupStepStatus.done
              : StreamSetupStepStatus.pending,
        ),
      ],
    StreamPlatform.customRtmp => [
        StreamSetupStep(
          title: 'Choose custom RTMP',
          subtitle: 'Restream, CDN, or other encoder destination',
          status: StreamSetupStepStatus.done,
        ),
        StreamSetupStep(
          title: 'Enter server URL',
          subtitle: hasUrl ? config.rtmpUrl : 'RTMP or RTMPS ingest URL',
          status: hasUrl
              ? StreamSetupStepStatus.done
              : StreamSetupStepStatus.pending,
        ),
        StreamSetupStep(
          title: 'Enter stream key',
          subtitle: hasKey ? 'Stream key saved' : 'Paste key from your platform',
          status: hasKey
              ? StreamSetupStepStatus.done
              : StreamSetupStepStatus.pending,
        ),
      ],
    StreamPlatform.twitch => [
        StreamSetupStep(
          title: 'Twitch',
          subtitle: 'Not available in this release',
          status: StreamSetupStepStatus.pending,
        ),
      ],
  };
}

bool isStreamSetupComplete(StreamStudioConfig config) =>
    config.isBroadcastConfigured;

/// Compact checklist for setup sheets and broadcast configuration.
class StreamSetupChecklist extends ConsumerWidget {
  const StreamSetupChecklist({
    super.key,
    required this.matchId,
    this.compact = false,
  });

  final String matchId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final steps = buildStreamSetupSteps(config);
    final complete = isStreamSetupComplete(config);
    final pending =
        steps.where((s) => s.status == StreamSetupStepStatus.pending).length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: complete
            ? cf.accent.withValues(alpha: 0.08)
            : cf.sectionBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: complete
              ? cf.accent.withValues(alpha: 0.35)
              : cf.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete ? Icons.check_circle : Icons.pending_actions,
                size: 18,
                color: complete ? cf.accent : cf.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  complete
                      ? 'Ready to broadcast'
                      : '$pending step${pending == 1 ? '' : 's'} remaining',
                  style: TextStyle(
                    color: cf.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 10),
            ...steps.map((step) => _StepRow(cf: cf, step: step)),
          ] else if (!complete) ...[
            const SizedBox(height: 6),
            Text(
              steps
                  .firstWhere((s) => s.status == StreamSetupStepStatus.pending)
                  .subtitle,
              style: TextStyle(color: cf.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.cf, required this.step});

  final CfColors cf;
  final StreamSetupStep step;

  @override
  Widget build(BuildContext context) {
    final icon = switch (step.status) {
      StreamSetupStepStatus.done => Icons.check_circle_outline,
      StreamSetupStepStatus.pending => Icons.radio_button_unchecked,
      StreamSetupStepStatus.optional => Icons.more_horiz,
    };
    final color = switch (step.status) {
      StreamSetupStepStatus.done => cf.accent,
      StreamSetupStepStatus.pending => cf.textPrimary,
      StreamSetupStepStatus.optional => cf.textMuted,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  step.subtitle,
                  style: TextStyle(color: cf.textSecondary, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
