import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/cf_colors.dart';
import '../../data/models/match_model.dart';
import '../../domain/streaming/match_stream_playback.dart';
import '../../domain/streaming/replay_marker_session_utils.dart';
import '../../features/streaming/data/models/stream_studio_config.dart';
import '../../features/streaming/domain/streaming_enums.dart';
import '../../features/streaming/domain/streaming_mode.dart';
import '../../features/streaming/presentation/providers/streaming_studio_providers.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/cf_button.dart';
import 'match_stream_player.dart';
import 'stream_replay_marker_bar.dart';

/// Watch panel pinned below the app bar with a stream picker when multiple URLs exist.
class MatchStreamWatchSection extends ConsumerStatefulWidget {
  const MatchStreamWatchSection({
    super.key,
    required this.match,
    this.edgeToEdge = false,
  });

  final MatchModel match;
  final bool edgeToEdge;

  @override
  ConsumerState<MatchStreamWatchSection> createState() =>
      _MatchStreamWatchSectionState();
}

class _MatchStreamWatchSectionState extends ConsumerState<MatchStreamWatchSection> {
  String? _selectedSessionKey;
  int? _trackedNewestStartMs;
  final _playerKey = GlobalKey<MatchStreamPlayerState>();
  Duration? _pendingSeekAfterSwitch;
  ResolvedReplayMarker? _pendingResolvedAfterSwitch;

  void _syncSelectionWithSources(List<MatchStreamSource> sources) {
    if (sources.isEmpty) return;

    final newestStart = sources.first.addedAt?.millisecondsSinceEpoch;
    final newestChanged = _trackedNewestStartMs != newestStart;
    if (newestChanged) {
      _trackedNewestStartMs = newestStart;
      _selectedSessionKey = sources.first.effectiveSessionKey;
      return;
    }

    final selected = _selectedSessionKey;
    if (selected == null ||
        !sources.any((s) => s.effectiveSessionKey == selected)) {
      _selectedSessionKey = sources.first.effectiveSessionKey;
    }
  }

  int _indexForSources(List<MatchStreamSource> sources) {
    final selected = _selectedSessionKey;
    if (selected != null) {
      final idx = sources.indexWhere((s) => s.effectiveSessionKey == selected);
      if (idx >= 0) return idx;
    }
    return 0;
  }

  Future<void> _pickStreamSession(
    BuildContext context,
    List<MatchStreamSource> sources,
    CfColors cf,
  ) async {
    if (sources.length <= 1) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Choose stream',
                style: TextStyle(
                  color: cf.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final source in sources)
              ListTile(
                title: Text(
                  source.label,
                  style: TextStyle(
                    color: cf.textPrimary,
                    fontWeight: source.effectiveSessionKey == _selectedSessionKey
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                trailing: source.effectiveSessionKey == _selectedSessionKey
                    ? Icon(Icons.check, color: cf.accent)
                    : null,
                onTap: () => Navigator.of(ctx).pop(source.effectiveSessionKey),
              ),
          ],
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() => _selectedSessionKey = picked);
    }
  }

  @override
  void didUpdateWidget(covariant MatchStreamWatchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final match =
        ref.read(matchProvider(widget.match.id)).valueOrNull ?? widget.match;
    final sources = MatchStreamPlayback.sourcesFor(match);
    if (sources.isEmpty) return;
    setState(() => _syncSelectionWithSources(sources));
  }

  void _onMarkerTap(
    ResolvedReplayMarker resolved,
    List<MatchStreamSource> sources,
  ) {
    final offset = Duration(milliseconds: resolved.seekOffsetMs);
    if (resolved.sourceIndex != _indexForSources(sources)) {
      setState(() {
        _selectedSessionKey = sources[resolved.sourceIndex.clamp(0, sources.length - 1)]
            .effectiveSessionKey;
        _pendingSeekAfterSwitch = offset;
        _pendingResolvedAfterSwitch = resolved;
      });
      return;
    }
    _playerKey.currentState?.seekToOffset(
      offset,
      seekLabel: resolved.commentary,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<MatchModel?>>(
      matchProvider(widget.match.id),
      (previous, next) {
        final match = next.valueOrNull ?? widget.match;
        final sources = MatchStreamPlayback.sourcesFor(match);
        if (sources.isEmpty) return;
        final newestStart = sources.first.addedAt?.millisecondsSinceEpoch;
        if (_trackedNewestStartMs == newestStart &&
            _selectedSessionKey != null &&
            sources.any((s) => s.effectiveSessionKey == _selectedSessionKey)) {
          return;
        }
        setState(() => _syncSelectionWithSources(sources));
      },
    );

    final match =
        ref.watch(matchProvider(widget.match.id)).valueOrNull ?? widget.match;
    final sources = MatchStreamPlayback.sourcesFor(match);
    if (sources.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedIndex = _indexForSources(sources);
    final current = sources[selectedIndex];
    final cf = context.cf;
    final horizontalPad = widget.edgeToEdge ? 0.0 : 16.0;
    final showPicker = sources.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPicker)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad + 12, 8, horizontalPad + 12, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cf.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cf.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      child: InkWell(
                        onTap: sources.length <= 1
                            ? null
                            : () => _pickStreamSession(context, sources, cf),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  current.label,
                                  style: TextStyle(
                                    color: cf.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (sources.length > 1)
                                Icon(
                                  Icons.unfold_more,
                                  size: 18,
                                  color: cf.textSecondary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Consumer(
          builder: (context, ref, _) {
            final markers =
                ref.watch(replayMarkersProvider(widget.match.id)).valueOrNull ??
                    const [];
            final ballEvents =
                ref.watch(ballEventsProvider(widget.match.id)).valueOrNull ??
                    const [];
            final ballEventsById = {
              for (final event in ballEvents) event.id: event,
            };
            final resolved = ReplayMarkerSessionUtils.resolve(
              markers: markers,
              sources: sources,
              ballEventsById: ballEventsById,
            );
            final sessions = ReplayMarkerSessionUtils.buildSessions(sources);
            final totalDurationMs =
                ReplayMarkerSessionUtils.totalTimelineDurationMs(sessions);
            final horizontalPadding =
                widget.edgeToEdge ? 12.0 : AppDimens.spaceMd;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MatchStreamPlayer(
                  key: _playerKey,
                  source: current,
                  edgeToEdge: widget.edgeToEdge,
                  pendingSeek: _pendingSeekAfterSwitch,
                  onPendingSeekApplied: () {
                    final pending = _pendingResolvedAfterSwitch;
                    if (_pendingSeekAfterSwitch != null) {
                      setState(() {
                        _pendingSeekAfterSwitch = null;
                        _pendingResolvedAfterSwitch = null;
                      });
                    }
                    if (pending != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Jumped to ${pending.commentary}'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                if (resolved.isNotEmpty && totalDurationMs > 0)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cf.surface,
                      border: widget.edgeToEdge
                          ? null
                          : Border(
                              left: BorderSide(color: cf.border),
                              right: BorderSide(color: cf.border),
                              bottom: BorderSide(color: cf.border),
                            ),
                      borderRadius: widget.edgeToEdge
                          ? null
                          : const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                    ),
                    child: StreamReplayMarkerBar(
                      resolvedMarkers: resolved,
                      totalDurationMs: totalDurationMs,
                      sessions: sessions,
                      activeSourceIndex: selectedIndex,
                      horizontalPadding: horizontalPadding,
                      onMarkerTap: (item) => _onMarkerTap(item, sources),
                    ),
                  ),
              ],
            );
          },
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
      'Paste the share link (facebook.com/share/v/…), watch URL, or Embed code '
      'from your live post.',
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
