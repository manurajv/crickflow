import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cf_colors.dart';
import '../../data/models/match_model.dart';
import '../../domain/streaming/match_stream_playback.dart';
import '../../features/streaming/data/models/stream_studio_config.dart';
import '../../features/streaming/domain/streaming_enums.dart';
import '../../features/streaming/domain/streaming_mode.dart';
import '../../features/streaming/presentation/providers/streaming_studio_providers.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/cf_button.dart';
import 'match_stream_player.dart';

/// Watch panel pinned below the app bar with a stream picker when multiple URLs exist.
class MatchStreamWatchSection extends StatefulWidget {
  const MatchStreamWatchSection({
    super.key,
    required this.match,
    this.edgeToEdge = false,
  });

  final MatchModel match;
  final bool edgeToEdge;

  @override
  State<MatchStreamWatchSection> createState() => _MatchStreamWatchSectionState();
}

class _MatchStreamWatchSectionState extends State<MatchStreamWatchSection> {
  int _index = 0;
  String? _trackedNewestUrl;

  @override
  void didUpdateWidget(covariant MatchStreamWatchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sources = MatchStreamPlayback.sourcesFor(widget.match);
    if (sources.isEmpty) return;
    final newest = sources.first.url;
    if (_trackedNewestUrl != newest) {
      _trackedNewestUrl = newest;
      _index = 0;
    } else if (_index >= sources.length) {
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = MatchStreamPlayback.sourcesFor(widget.match);
    if (sources.isEmpty) {
      return const SizedBox.shrink();
    }

    final clampedIndex = _index.clamp(0, sources.length - 1);
    final current = sources[clampedIndex];
    _trackedNewestUrl ??= sources.first.url;
    final cf = context.cf;
    final horizontalPad = widget.edgeToEdge ? 0.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sources.length > 1)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad + 12, 8, horizontalPad + 12, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cf.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cf.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Stream',
                      style: TextStyle(
                        color: cf.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: clampedIndex,
                          style: TextStyle(
                            color: cf.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          items: [
                            for (var i = 0; i < sources.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  sources[i].label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _index = value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        MatchStreamPlayer(
          key: ValueKey(current.url),
          source: current,
          edgeToEdge: widget.edgeToEdge,
        ),
      ],
    );
  }
}

/// Result of the stream URL bottom sheet.
class StreamWatchUrlSheetResult {
  const StreamWatchUrlSheetResult({
    this.saved = false,
    this.skipped = false,
    this.primaryUrl,
    this.secondaryUrl,
  });

  final bool saved;
  final bool skipped;
  final String? primaryUrl;
  final String? secondaryUrl;
}

/// Bottom sheet for broadcasters to paste a public live / VOD watch link.
Future<StreamWatchUrlSheetResult?> showStreamWatchUrlSheet({
  required BuildContext context,
  required String matchId,
  MatchModel? match,
  bool allowSecondary = true,
  String title = 'Add live stream link',
  String? subtitle,
}) {
  return showModalBottomSheet<StreamWatchUrlSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _StreamWatchUrlSheet(
      matchId: matchId,
      match: match,
      allowSecondary: allowSecondary,
      title: title,
      subtitle: subtitle,
    ),
  );
}

class _StreamWatchUrlSheet extends ConsumerStatefulWidget {
  const _StreamWatchUrlSheet({
    required this.matchId,
    this.match,
    this.allowSecondary = true,
    required this.title,
    this.subtitle,
  });

  final String matchId;
  final MatchModel? match;
  final bool allowSecondary;
  final String title;
  final String? subtitle;

  @override
  ConsumerState<_StreamWatchUrlSheet> createState() =>
      _StreamWatchUrlSheetState();
}

class _StreamWatchUrlSheetState extends ConsumerState<_StreamWatchUrlSheet> {
  late final TextEditingController _primaryCtrl;
  late final TextEditingController _secondaryCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final match = widget.match;
    _primaryCtrl = TextEditingController();
    _secondaryCtrl = TextEditingController(
      text: match?.stream.secondaryYoutubeWatchUrl ?? '',
    );
  }

  @override
  void dispose() {
    _primaryCtrl.dispose();
    _secondaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final primary = MatchStreamPlayback.normalizeWatchUrl(_primaryCtrl.text);
    final secondary = widget.allowSecondary
        ? MatchStreamPlayback.normalizeWatchUrl(_secondaryCtrl.text)
        : null;

    if (primary != null && !MatchStreamPlayback.isValidWatchUrl(primary)) {
      setState(() => _error = 'Enter a valid YouTube, Facebook, or stream URL');
      return;
    }
    if (secondary != null &&
        secondary.isNotEmpty &&
        !MatchStreamPlayback.isValidWatchUrl(secondary)) {
      setState(() => _error = 'Secondary link is not a valid URL');
      return;
    }
    if (primary == null && (secondary == null || secondary.isEmpty)) {
      setState(() => _error = 'Paste at least one watch link');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      final uid = ref.read(authStateProvider).value?.uid;
      await ref.read(matchRepositoryProvider).updateStreamWatchUrls(
            widget.matchId,
            primaryUrl: primary,
            secondaryUrl: secondary?.isEmpty == true ? null : secondary,
            addedByUserId: uid,
            addedByName: profile?.effectiveName,
          );
      if (!mounted) return;
      Navigator.of(context).pop(
        StreamWatchUrlSheetResult(
          saved: true,
          primaryUrl: primary,
          secondaryUrl: secondary,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  void _skip() {
    Navigator.of(context).pop(
      const StreamWatchUrlSheetResult(skipped: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: cf.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle ??
                'Paste the public watch link from YouTube, Facebook, or Twitch '
                'so viewers can watch from the scorecard.',
            style: TextStyle(color: cf.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _primaryCtrl,
            decoration: InputDecoration(
              labelText: 'Stream URL',
              hintText: 'https://youtube.com/live/…',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
          ),
          if (widget.allowSecondary) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _secondaryCtrl,
              decoration: const InputDecoration(
                labelText: 'Second angle (optional)',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Each go-live or pasted link is saved separately so viewers can switch '
            'between reconnects and watch the full match.',
            style: TextStyle(color: cf.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            'YouTube Automatic go-live fills this automatically. '
            'Manual RTMP and external encoders (OBS) need a pasted link.',
            style: TextStyle(color: cf.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 20),
          CfButton(
            label: _saving ? 'Saving…' : 'Save link',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : _skip,
            child: const Text('Leave without adding'),
          ),
        ],
      ),
    );
  }
}

/// Prompts for a public watch URL when auto-fetch is not available.
Future<void> promptStreamWatchUrlIfNeeded({
  required BuildContext context,
  required WidgetRef ref,
  required String matchId,
  StreamStudioConfig? config,
}) async {
  final match = ref.read(matchProvider(matchId)).valueOrNull;
  if (match == null) return;
  if (MatchStreamPlayback.hasWatchablePlayback(match)) return;

  final StreamStudioConfig resolvedConfig = config ??
      ref.read(streamStudioConfigProvider(matchId));
  if (!resolvedConfig.needsManualWatchUrl) return;

  final subtitle = _watchUrlPromptSubtitle(resolvedConfig);

  await showStreamWatchUrlSheet(
    context: context,
    matchId: matchId,
    match: match,
    title: 'Add public watch link',
    subtitle: subtitle,
  );
}

String _watchUrlPromptSubtitle(StreamStudioConfig config) {
  if (config.streamingMode == StreamingMode.externalEncoder) {
    return 'Paste the public watch link from YouTube, Facebook, or Twitch '
        '(where OBS is streaming) so viewers can watch from the scorecard.';
  }
  return switch (config.platform) {
    StreamPlatform.youtube =>
      'YouTube manual RTMP does not return a watch link automatically. '
      'Copy it from YouTube Studio → Go live → Share, then paste here.',
    StreamPlatform.facebook =>
      'Facebook manual RTMP does not return a watch link automatically. '
      'Copy the public video URL from your Facebook live post.',
    StreamPlatform.twitch =>
      'Paste your Twitch channel or live VOD URL.',
    StreamPlatform.customRtmp =>
      'Paste the public watch link for this stream.',
  };
}

/// @deprecated Use [promptStreamWatchUrlIfNeeded].
Future<void> promptStreamWatchUrlOnEncoderExit({
  required BuildContext context,
  required WidgetRef ref,
  required String matchId,
}) =>
    promptStreamWatchUrlIfNeeded(
      context: context,
      ref: ref,
      matchId: matchId,
    );
