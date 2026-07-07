import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
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
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Configure destination and stream details',
                            style: TextStyle(
                              color: cf.textSecondary,
                              fontSize: 13,
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    StreamSetupChecklist(matchId: matchId),
                    const SizedBox(height: 20),
                    _SetupSectionCard(
                      title: 'Destination',
                      subtitle: 'Where your stream will be published',
                      child: StreamBroadcastDestinationSection(matchId: matchId),
                    ),
                    if (config.platform == StreamPlatform.youtube &&
                        config.broadcastSetupMode ==
                            StreamBroadcastSetupMode.automatic) ...[
                      const SizedBox(height: 16),
                      _SetupSectionCard(
                        title: 'Stream details',
                        subtitle: 'Title, visibility, and thumbnail for YouTube',
                        child: _BroadcastMetadataSection(
                          matchId: matchId,
                          match: match,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              canStart && configured ? cf.accent : cf.textDisabled,
                          foregroundColor:
                              canStart && configured ? cf.onAccent : cf.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
                    const SizedBox(height: 10),
                    Text(
                      configured
                          ? 'Or close this sheet and tap Go Live on the camera.'
                          : 'Link your YouTube account and add a title to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cf.textMuted, fontSize: 12),
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

class _SetupSectionCard extends StatelessWidget {
  const _SetupSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cf.sectionBackground.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cf.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cf.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: cf.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BroadcastMetadataSection extends ConsumerStatefulWidget {
  const _BroadcastMetadataSection({
    required this.matchId,
    required this.match,
  });

  final String matchId;
  final MatchModel match;

  static const int kYouTubeTitleMaxLength = 100;
  static const int kYouTubeDescriptionMaxLength = 5000;

  @override
  ConsumerState<_BroadcastMetadataSection> createState() =>
      _BroadcastMetadataSectionState();
}

class _BroadcastMetadataSectionState
    extends ConsumerState<_BroadcastMetadataSection> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final config = ref.read(streamStudioConfigProvider(widget.matchId));
    final defaultTitle = config.title.isNotEmpty
        ? config.title
        : 'LIVE | ${widget.match.teamAName} vs ${widget.match.teamBName}';
    final defaultDescription = config.description.isNotEmpty
        ? config.description
        : 'Live cricket on CrickFlow';

    _titleController = TextEditingController(text: defaultTitle);
    _descriptionController = TextEditingController(text: defaultDescription);

    if (config.title.isEmpty || config.description.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(streamStudioConfigProvider(widget.matchId).notifier).update(
              (c) => c.copyWith(
                title: config.title.isEmpty ? defaultTitle : c.title,
                description:
                    config.description.isEmpty ? defaultDescription : c.description,
              ),
            );
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(widget.matchId));
    final notifier = ref.read(streamStudioConfigProvider(widget.matchId).notifier);

    ref.listen(
      streamStudioConfigProvider(widget.matchId).select((c) => c.title),
      (prev, next) {
        if (_titleController.text != next) _titleController.text = next;
      },
    );
    ref.listen(
      streamStudioConfigProvider(widget.matchId).select((c) => c.description),
      (prev, next) {
        if (_descriptionController.text != next) {
          _descriptionController.text = next;
        }
      },
    );

    InputDecoration fieldDecoration(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: cf.surface,
          labelStyle: TextStyle(color: cf.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cf.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cf.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cf.accent),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          style: TextStyle(
            color: cf.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          maxLength: _BroadcastMetadataSection.kYouTubeTitleMaxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: fieldDecoration('Title'),
          onChanged: (v) => notifier.update((c) => c.copyWith(title: v)),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: TextField(
            controller: _descriptionController,
            style: TextStyle(color: cf.textPrimary, fontSize: 14),
            keyboardType: TextInputType.multiline,
            minLines: 4,
            maxLines: null,
            maxLength: _BroadcastMetadataSection.kYouTubeDescriptionMaxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            scrollPhysics: const BouncingScrollPhysics(),
            decoration: fieldDecoration('Description'),
            onChanged: (v) => notifier.update((c) => c.copyWith(description: v)),
          ),
        ),
        if (config.platform == StreamPlatform.youtube) ...[
          const SizedBox(height: 14),
          _PickerTile(
            cf: cf,
            icon: Icons.public,
            label: 'Visibility',
            value: _visibilityLabel(config.visibility),
            onTap: () => _pickVisibility(context, ref, widget.matchId, config),
          ),
          const SizedBox(height: 14),
          _ThumbnailPicker(matchId: widget.matchId),
        ],
      ],
    );
  }

  static String _visibilityLabel(StreamVisibility visibility) =>
      switch (visibility) {
        StreamVisibility.public => 'Public',
        StreamVisibility.unlisted => 'Unlisted',
        StreamVisibility.private => 'Private',
      };

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      tileColor: cf.sectionBackground.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cf.border.withValues(alpha: 0.6)),
      ),
      leading: Icon(icon, color: cf.accent, size: 22),
      title: Text(
        label,
        style: TextStyle(color: cf.textPrimary, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: cf.textMuted, fontSize: 13),
          ),
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

class _ThumbnailPicker extends ConsumerWidget {
  const _ThumbnailPicker({required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final config = ref.watch(streamStudioConfigProvider(matchId));
    final notifier = ref.read(streamStudioConfigProvider(matchId).notifier);
    final path = config.thumbnailPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thumbnail',
          style: TextStyle(
            color: cf.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 96,
                height: 54,
                color: cf.sectionBackground,
                child: path != null && path.isNotEmpty
                    ? Image.file(File(path), fit: BoxFit.cover)
                    : Icon(Icons.image_outlined, color: cf.textMuted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    path != null
                        ? 'Custom thumbnail selected'
                        : 'Optional — YouTube uses its default if empty',
                    style: TextStyle(color: cf.textPrimary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => _pickThumbnail(notifier),
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: Text(path != null ? 'Change' : 'Upload'),
                      ),
                      if (path != null)
                        TextButton(
                          onPressed: () => notifier.update(
                            (c) => c.copyWith(thumbnailPath: null),
                          ),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickThumbnail(
    StreamStudioNotifier notifier,
  ) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1920,
    );
    if (picked != null) {
      notifier.update((c) => c.copyWith(thumbnailPath: picked.path));
    }
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

    ref.listen<AsyncValue<List<YouTubeChannel>>>(
      youtubeChannelsProvider,
      (_, next) {
        syncYouTubeChannelToStudioConfig(
          ref,
          matchId,
          channels: next.valueOrNull,
        );
      },
    );
    final channelsNow = channelsAsync.valueOrNull;
    if (channelsNow != null && channelsNow.isNotEmpty) {
      syncYouTubeChannelToStudioConfig(ref, matchId, channels: channelsNow);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamYouTubeLinkSection(matchId: matchId),
        const SizedBox(height: 12),
        channelsAsync.when(
          data: (channels) {
            if (channels.isEmpty) return const SizedBox.shrink();
            final uniqueChannels = <String, YouTubeChannel>{};
            for (final ch in channels) {
              uniqueChannels.putIfAbsent(ch.id, () => ch);
            }
            final items = uniqueChannels.values.toList();
            final selectedId = items.any((c) => c.id == config.youtubeChannelId)
                ? config.youtubeChannelId
                : items.first.id;
            return DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'YouTube channel',
                filled: true,
                fillColor: cf.surface,
                labelStyle: TextStyle(color: cf.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cf.border),
                ),
              ),
              value: selectedId,
              items: items
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.title),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                final ch = items.firstWhere((c) => c.id == id);
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
          error: (error, _) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error is StreamPlatformException
                  ? error.message
                  : 'Could not load channels: $error',
              style: TextStyle(color: cf.error, fontSize: 11),
            ),
          ),
        ),
      ],
    );
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
