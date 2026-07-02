import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../shared/widgets/cf_button.dart';
import '../../../data/models/saved_rtmp_server.dart';
import '../../../data/models/stream_studio_config.dart';
import '../../../domain/rtmp_server_presets.dart';
import '../../../domain/streaming_enums.dart';
import '../../../services/stream_platform_service.dart';
import '../../providers/streaming_studio_providers.dart';
import '../dashboard/stream_youtube_link_section.dart';
import 'stream_setup_checklist.dart';

/// Opens broadcast destination setup (YouTube, Facebook, or custom RTMP) without going live.
Future<void> showStreamBroadcastSetupSheet(
  BuildContext context, {
  required String matchId,
  required MatchModel match,
  required bool canStart,
  VoidCallback? onStartLive,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => _StreamBroadcastSetupSheet(
      matchId: matchId,
      match: match,
      canStart: canStart,
      onStartLive: onStartLive,
    ),
  );
}

class _StreamBroadcastSetupSheet extends ConsumerWidget {
  const _StreamBroadcastSetupSheet({
    required this.matchId,
    required this.match,
    required this.canStart,
    this.onStartLive,
  });

  final String matchId;
  final MatchModel match;
  final bool canStart;
  final VoidCallback? onStartLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final configured = config.isBroadcastConfigured;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
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
                            'Broadcast setup',
                            style: TextStyle(
                              color: cf.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Configure your destination, then start from the camera',
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
                    StreamSetupChecklist(matchId: matchId),
                    const SizedBox(height: 16),
                    StreamBroadcastDestinationSection(matchId: matchId),
                    if (config.platform == StreamPlatform.youtube &&
                        config.broadcastSetupMode ==
                            StreamBroadcastSetupMode.automatic) ...[
                      const SizedBox(height: 16),
                      _BroadcastMetadataSection(
                        matchId: matchId,
                        match: match,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _HowToGoLiveCard(matchId: matchId),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              canStart && configured ? cf.accent : cf.textDisabled,
                          foregroundColor:
                              canStart && configured ? cf.onAccent : cf.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: canStart && configured
                            ? () {
                                Navigator.pop(context);
                                onStartLive?.call();
                              }
                            : null,
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text('Start live broadcast'),
                      ),
                    ),
                    if (!configured)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Complete the checklist above, then use Ready → Go Live on the camera.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cf.textMuted, fontSize: 12),
                        ),
                      ),
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

class _HowToGoLiveCard extends ConsumerWidget {
  const _HowToGoLiveCard({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));

    final steps = switch (config.platform) {
      StreamPlatform.youtube when config.broadcastSetupMode ==
          StreamBroadcastSetupMode.manual => [
          'Pick YouTube and Manual setup above.',
          'Paste your stream key from YouTube Studio (Go Live → Stream).',
          'Tap Go Live on the camera — video goes to YouTube ingest.',
          'Open YouTube Studio and click Go live when ready (unless auto-start is on there).',
        ],
      StreamPlatform.youtube => [
          'Link your Google account and pick a channel.',
          'Set title and visibility, then create the YouTube event.',
          config.goLiveImmediately
              ? 'Tap Go Live — YouTube goes public when video connects.'
              : 'Tap Go Live — preview in YouTube Studio, then click Go live there.',
        ],
      StreamPlatform.facebook => [
          'Copy the RTMPS server URL and stream key from Facebook Live Producer.',
          'Paste them above, then tap Go Live on the camera.',
        ],
      StreamPlatform.customRtmp => [
          'Enter your RTMP server URL and stream key.',
          'Tap Go Live on the camera when credentials are saved.',
        ],
      StreamPlatform.twitch => ['Twitch is not available in this release.'],
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cf.sectionBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cf.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to go live',
            style: TextStyle(
              color: cf.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            _StepLine(cf: cf, n: '${i + 1}', text: steps[i]),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.cf, required this.n, required this.text});

  final CfColors cf;
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
              style: TextStyle(color: cf.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastMetadataSection extends ConsumerWidget {
  const _BroadcastMetadataSection({
    required this.matchId,
    required this.match,
  });

  final String matchId;
  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);
    final defaultTitle = config.title.isNotEmpty
        ? config.title
        : 'LIVE | ${match.teamAName} vs ${match.teamBName}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STREAM DETAILS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: cf.accent,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          style: TextStyle(color: cf.textPrimary, fontWeight: FontWeight.w600),
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Title',
            labelStyle: TextStyle(color: cf.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cf.border),
            ),
          ),
          controller: TextEditingController(text: defaultTitle),
          onChanged: (v) => notifier.update((c) => c.copyWith(title: v)),
        ),
        const SizedBox(height: 12),
        TextField(
          style: TextStyle(color: cf.textPrimary),
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Description',
            labelStyle: TextStyle(color: cf.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cf.border),
            ),
          ),
          controller: TextEditingController(
            text: config.description.isNotEmpty
                ? config.description
                : 'Live cricket on CrickFlow',
          ),
          onChanged: (v) => notifier.update((c) => c.copyWith(description: v)),
        ),
        if (config.platform == StreamPlatform.youtube) ...[
          const SizedBox(height: 12),
          _PickerTile(
            cf: cf,
            icon: Icons.public,
            label: 'Visibility',
            value: config.visibility.name,
            onTap: () => _pickVisibility(context, ref, matchId, config),
          ),
          _PickerTile(
            cf: cf,
            icon: Icons.grid_view_rounded,
            label: 'Category',
            value: config.category,
            onTap: () => _pickCategory(context, ref, matchId, config),
          ),
        ],
      ],
    );
  }

  static Future<void> _pickVisibility(
    BuildContext context,
    WidgetRef ref,
    String matchId,
    StreamStudioConfig config,
  ) async {
    final cf = context.cf;
    final picked = await showModalBottomSheet<StreamVisibility>(
      context: context,
      backgroundColor: cf.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: StreamVisibility.values
              .map(
                (v) => ListTile(
                  title: Text(v.name, style: TextStyle(color: cf.textPrimary)),
                  trailing: config.visibility == v
                      ? Icon(Icons.check, color: cf.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, v),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      ref.read(streamStudioConfigProvider(matchId).notifier).update(
            (c) => c.copyWith(visibility: picked),
          );
    }
  }

  static Future<void> _pickCategory(
    BuildContext context,
    WidgetRef ref,
    String matchId,
    StreamStudioConfig config,
  ) async {
    const categories = ['Sports', 'Entertainment', 'Gaming', 'News'];
    final cf = context.cf;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cf.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: categories
              .map(
                (c) => ListTile(
                  title: Text(c, style: TextStyle(color: cf.textPrimary)),
                  trailing: config.category == c
                      ? Icon(Icons.check, color: cf.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, c),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      ref.read(streamStudioConfigProvider(matchId).notifier).update(
            (c) => c.copyWith(category: picked),
          );
    }
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.cf,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final CfColors cf;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: cf.textSecondary),
      title: Text(label, style: TextStyle(color: cf.textPrimary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: cf.textMuted, fontSize: 13)),
          Icon(Icons.chevron_right, color: cf.textMuted, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Destination picker — YouTube (OAuth or manual key), Facebook RTMPS, custom RTMP.
class StreamBroadcastDestinationSection extends ConsumerWidget {
  const StreamBroadcastDestinationSection({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESTINATION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: cf.accent,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: kImplementedStreamPlatforms.map((platform) {
            final selected = config.platform == platform;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: platform != kImplementedStreamPlatforms.last ? 6 : 0,
                ),
                child: Material(
                  color: selected
                      ? cf.accent.withValues(alpha: 0.12)
                      : cf.sectionBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => notifier.update(
                      (c) => c.copyWith(
                        platform: platform,
                        rtmpUrl: platform.defaultRtmpUrl,
                        streamKey: platform == c.platform ? c.streamKey : '',
                      ),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? cf.accent : cf.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _platformIcon(platform),
                            color: selected ? cf.accent : cf.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            platform.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected ? cf.accent : cf.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (config.platform == StreamPlatform.youtube) ...[
          _BroadcastSetupModeSelector(matchId: matchId),
          const SizedBox(height: 16),
        ],
        switch (config.platform) {
          StreamPlatform.youtube =>
            config.broadcastSetupMode == StreamBroadcastSetupMode.manual
                ? _YouTubeManualSetup(matchId: matchId)
                : _YouTubeAutomaticSetup(matchId: matchId),
          StreamPlatform.facebook => _ManualRtmpSetup(
              matchId: matchId,
              platform: StreamPlatform.facebook,
              helpText:
                  'In Facebook → Live → Streaming setup, copy the server URL and stream key.',
            ),
          StreamPlatform.customRtmp => _ManualRtmpSetup(
              matchId: matchId,
              platform: StreamPlatform.customRtmp,
              helpText:
                  'Enter any RTMP or RTMPS server. Save frequently used servers for next time.',
              showSavedServers: true,
            ),
          StreamPlatform.twitch => const SizedBox.shrink(),
        },
      ],
    );
  }

  static IconData _platformIcon(StreamPlatform platform) => switch (platform) {
        StreamPlatform.youtube => Icons.play_circle_outline,
        StreamPlatform.facebook => Icons.facebook,
        StreamPlatform.customRtmp => Icons.settings_input_antenna,
        StreamPlatform.twitch => Icons.videogame_asset,
      };
}

class _BroadcastSetupModeSelector extends ConsumerWidget {
  const _BroadcastSetupModeSelector({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SETUP MODE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: cf.accent,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: StreamBroadcastSetupMode.values.map((mode) {
            final selected = config.broadcastSetupMode == mode;
            final isLast = mode == StreamBroadcastSetupMode.values.last;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: Material(
                  color: selected
                      ? cf.accent.withValues(alpha: 0.12)
                      : cf.sectionBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => notifier.update(
                      (c) => c.copyWith(broadcastSetupMode: mode),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? cf.accent : cf.border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            mode == StreamBroadcastSetupMode.automatic
                                ? Icons.auto_awesome
                                : Icons.vpn_key_outlined,
                            color: selected ? cf.accent : cf.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mode.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected ? cf.accent : cf.textPrimary,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          config.broadcastSetupMode.subtitle,
          style: TextStyle(color: cf.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _YouTubeAutomaticSetup extends ConsumerWidget {
  const _YouTubeAutomaticSetup({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);
    final channelsAsync = ref.watch(youtubeChannelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _YouTubeAutoStartToggle(matchId: matchId),
        const SizedBox(height: 16),
        StreamYouTubeLinkSection(matchId: matchId),
        const SizedBox(height: 8),
        channelsAsync.when(
          data: (channels) {
            if (channels.isEmpty) return const SizedBox.shrink();
            return DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'YouTube channel',
                labelStyle: TextStyle(color: cf.textSecondary),
              ),
              value: config.youtubeChannelId.isNotEmpty
                  ? config.youtubeChannelId
                  : null,
              items: channels
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.title),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                final ch = channels.firstWhere((c) => c.id == id);
                notifier.update(
                  (c) => c.copyWith(
                    youtubeChannelId: ch.id,
                    youtubeChannelName: ch.title,
                  ),
                );
              },
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        CfButton(
          compact: true,
          label: 'Create YouTube live broadcast',
          icon: Icons.live_tv,
          onPressed: () => _createYouTubeBroadcast(context, ref),
        ),
        if (config.youtubeBroadcastId.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cf.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cf.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: cf.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config.goLiveImmediately
                        ? 'YouTube event ready — goes public when connected'
                        : 'YouTube event ready — preview in Studio first',
                    style: TextStyle(color: cf.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _createYouTubeBroadcast(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final config = ref.read(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);
    try {
      final creds = await ref
          .read(streamPlatformServiceProvider)
          .createYouTubeLive(config: config);
      if (creds == null || !context.mounted) return;
      notifier.update(
        (c) => c.copyWith(
          rtmpUrl: creds.rtmpUrl,
          streamKey: creds.streamKey,
          youtubeWatchUrl: creds.watchUrl,
          youtubeBroadcastId: creds.broadcastId,
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              config.goLiveImmediately
                  ? 'YouTube broadcast created — will go public when connected'
                  : 'YouTube broadcast created — preview in Studio, then click Go live',
            ),
          ),
        );
      }
    } on StreamPlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

class _YouTubeManualSetup extends ConsumerWidget {
  const _YouTubeManualSetup({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paste credentials from YouTube Studio → Go Live → Stream.',
          style: TextStyle(color: cf.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _RtmpPresetSelector(matchId: matchId, platform: StreamPlatform.youtube),
        const SizedBox(height: 8),
        _StreamKeyField(matchId: matchId),
        _StreamKeyHistorySection(matchId: matchId),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cf.sectionBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cf.border),
          ),
          child: Text(
            'No title or thumbnail needed here — configure those in YouTube Studio. '
            'Tap Go Live in CrickFlow to send video to ingest.',
            style: TextStyle(color: cf.textSecondary, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _YouTubeAutoStartToggle extends ConsumerWidget {
  const _YouTubeAutoStartToggle({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);

    return Container(
      decoration: BoxDecoration(
        color: cf.sectionBackground.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cf.border),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          'Go live on YouTube immediately',
          style: TextStyle(
            color: cf.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          config.goLiveImmediately
              ? 'Applies when YouTube is linked — goes public when video connects'
              : 'Requires linked YouTube — preview in Studio first, you click Go live',
          style: TextStyle(color: cf.textSecondary, fontSize: 11),
        ),
        value: config.goLiveImmediately,
        activeTrackColor: cf.accent,
        onChanged: (v) => notifier.update((c) => c.copyWith(goLiveImmediately: v)),
      ),
    );
  }
}

class _ManualRtmpSetup extends ConsumerWidget {
  const _ManualRtmpSetup({
    required this.matchId,
    required this.platform,
    required this.helpText,
    this.showSavedServers = false,
  });

  final String matchId;
  final StreamPlatform platform;
  final String helpText;
  final bool showSavedServers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(helpText, style: TextStyle(color: cf.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        _RtmpPresetSelector(matchId: matchId, platform: platform),
        const SizedBox(height: 8),
        _RtmpUrlField(matchId: matchId),
        const SizedBox(height: 8),
        _StreamKeyField(matchId: matchId),
        _StreamKeyHistorySection(matchId: matchId),
        if (showSavedServers) ...[
          const SizedBox(height: 12),
          _SavedRtmpServersSection(matchId: matchId),
        ],
      ],
    );
  }
}

class _RtmpPresetSelector extends ConsumerWidget {
  const _RtmpPresetSelector({
    required this.matchId,
    required this.platform,
  });

  final String matchId;
  final StreamPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);
    final presets = presetsForPlatform(platform);
    final selected = presetMatchingUrl(config.rtmpUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server preset',
          style: TextStyle(color: cf.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final preset in presets)
              ChoiceChip(
                label: Text(
                  preset.label,
                  style: TextStyle(fontSize: 11),
                ),
                selected: selected?.id == preset.id ||
                    (selected == null &&
                        preset.url.isNotEmpty &&
                        config.rtmpUrl == preset.url),
                onSelected: (_) {
                  notifier.update(
                    (c) => c.copyWith(rtmpUrl: preset.url),
                  );
                },
                selectedColor: cf.accent.withValues(alpha: 0.2),
                side: BorderSide(
                  color: selected?.id == preset.id ? cf.accent : cf.border,
                ),
              ),
          ],
        ),
        if (selected?.description.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            selected!.description,
            style: TextStyle(color: cf.textMuted, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _RtmpUrlField extends ConsumerStatefulWidget {
  const _RtmpUrlField({required this.matchId});

  final String matchId;

  @override
  ConsumerState<_RtmpUrlField> createState() => _RtmpUrlFieldState();
}

class _RtmpUrlFieldState extends ConsumerState<_RtmpUrlField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(streamStudioConfigProvider(widget.matchId)).rtmpUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    ref.listen(
      streamStudioConfigProvider(widget.matchId).select((c) => c.rtmpUrl),
      (prev, next) {
        if (_controller.text != next) {
          _controller.text = next;
        }
      },
    );

    return TextField(
      controller: _controller,
      style: TextStyle(color: cf.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'RTMP / RTMPS server URL',
        labelStyle: TextStyle(color: cf.textSecondary),
        hintText: 'rtmp://… or rtmps://…',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cf.border),
        ),
      ),
      onChanged: (v) => ref
          .read(streamStudioConfigProvider(widget.matchId).notifier)
          .update((c) => c.copyWith(rtmpUrl: v.trim())),
    );
  }
}

class _StreamKeyField extends ConsumerStatefulWidget {
  const _StreamKeyField({required this.matchId});

  final String matchId;

  @override
  ConsumerState<_StreamKeyField> createState() => _StreamKeyFieldState();
}

class _StreamKeyFieldState extends ConsumerState<_StreamKeyField> {
  late TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(streamStudioConfigProvider(widget.matchId)).streamKey,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    ref.listen(
      streamStudioConfigProvider(widget.matchId).select((c) => c.streamKey),
      (prev, next) {
        if (_controller.text != next) {
          _controller.text = next;
        }
      },
    );

    return TextField(
      controller: _controller,
      obscureText: _obscure,
      style: TextStyle(color: cf.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: 'Stream key',
        labelStyle: TextStyle(color: cf.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cf.border),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: cf.textMuted,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      onChanged: (v) => ref
          .read(streamStudioConfigProvider(widget.matchId).notifier)
          .update((c) => c.copyWith(streamKey: v.trim())),
    );
  }
}

class _StreamKeyHistorySection extends ConsumerWidget {
  const _StreamKeyHistorySection({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);
    final historyAsync =
        ref.watch(streamKeyHistoryForPlatformProvider(config.platform));

    return historyAsync.when(
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent stream keys',
                style: TextStyle(
                  color: cf.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in entries.take(10))
                    ActionChip(
                      label: Text(
                        entry.displayLabel,
                        style: const TextStyle(fontSize: 11),
                      ),
                      side: BorderSide(color: cf.border),
                      onPressed: () {
                        notifier.update(
                          (c) => c.copyWith(
                            streamKey: entry.streamKey,
                            rtmpUrl: entry.rtmpUrl.isNotEmpty
                                ? entry.rtmpUrl
                                : c.rtmpUrl,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SavedRtmpServersSection extends ConsumerWidget {
  const _SavedRtmpServersSection({required this.matchId});

  final String matchId;

  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);
    final savedAsync = ref.watch(savedRtmpServersProvider);

    return savedAsync.when(
      data: (servers) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved servers',
              style: TextStyle(
                color: cf.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (servers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No saved servers yet.',
                  style: TextStyle(color: cf.textMuted, fontSize: 11),
                ),
              ),
            ...servers.map(
              (s) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.dns_outlined, color: cf.textSecondary, size: 18),
                title: Text(
                  s.name,
                  style: TextStyle(color: cf.textPrimary, fontSize: 13),
                ),
                subtitle: Text(
                  s.rtmpUrl,
                  style: TextStyle(color: cf.textMuted, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(Icons.chevron_right, color: cf.textMuted, size: 18),
                onTap: () => notifier.update(
                  (c) => c.copyWith(
                    rtmpUrl: s.rtmpUrl,
                    streamKey: s.streamKey.isNotEmpty ? s.streamKey : c.streamKey,
                  ),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: config.rtmpUrl.trim().isEmpty
                  ? null
                  : () async {
                      final name = await _promptServerName(context, cf);
                      if (name == null || name.isEmpty) return;
                      await ref.read(streamStudioRepositoryProvider).saveRtmpServer(
                            SavedRtmpServer(
                              id: _uuid.v4(),
                              name: name,
                              rtmpUrl: config.rtmpUrl.trim(),
                              streamKey: config.streamKey.trim(),
                            ),
                          );
                      ref.invalidate(savedRtmpServersProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Server saved')),
                        );
                      }
                    },
              icon: Icon(Icons.bookmark_add_outlined, color: cf.accent, size: 18),
              label: Text(
                'Save current server',
                style: TextStyle(color: cf.accent, fontSize: 12),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  static Future<String?> _promptServerName(
    BuildContext context,
    CfColors cf,
  ) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cf.surface,
        title: Text('Save server', style: TextStyle(color: cf.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Name',
            labelStyle: TextStyle(color: cf.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: cf.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Save', style: TextStyle(color: cf.accent)),
          ),
        ],
      ),
    );
  }
}
