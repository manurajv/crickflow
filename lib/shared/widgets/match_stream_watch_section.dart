import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cf_colors.dart';
import '../../data/models/match_model.dart';
import '../../domain/streaming/match_stream_playback.dart';
import '../../features/streaming/data/models/stream_studio_config.dart';
import '../../features/streaming/domain/streaming_enums.dart';
import '../../features/streaming/domain/streaming_mode.dart';
import '../../features/streaming/presentation/providers/match_stream_seek_provider.dart';
import '../../features/streaming/presentation/providers/streaming_studio_providers.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/cf_button.dart';
import 'match_stream_player.dart';

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
  String? _pendingSeekLabel;
  int? _lastAppliedSeekNonce;
  bool _checkedInitialSeek = false;

  String _playbackSignature(List<MatchStreamSource> sources) {
    final key = _selectedSessionKey;
    if (key == null) {
      final first = sources.isNotEmpty ? sources.first : null;
      return first == null ? '' : '${first.effectiveSessionKey}|${first.url}';
    }
    for (final source in sources) {
      if (source.effectiveSessionKey == key) {
        return '${source.effectiveSessionKey}|${source.url}';
      }
    }
    return '';
  }

  bool _awaitingWatchUrl(MatchStreamSource source, MatchModel match) {
    if (!source.isLive) return false;
    if (!MatchStreamPlayback.isStreamActive(match)) return false;
    return !source.hasPlayableUrl;
  }

  Widget _sessionBarRow({
    required CfColors cf,
    required MatchStreamSource source,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(
          source.platformIcon,
          size: 18,
          color: cf.accent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${MatchStreamPlayback.platformLabel(source.platform)} • ${source.statusLabel}',
                style: TextStyle(
                  color: cf.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (source.startTimeLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Started ${source.startTimeLabel}',
                  style: TextStyle(
                    color: cf.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }

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
                leading: Icon(source.platformIcon, color: cf.accent),
                title: Text(
                  source.label,
                  style: TextStyle(
                    color: cf.textPrimary,
                    fontWeight: source.effectiveSessionKey == _selectedSessionKey
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                subtitle: source.endedAt != null
                    ? Text(
                        'Ended ${MatchStreamPlayback.formatSessionStartTime(source.endedAt)}',
                        style: TextStyle(color: cf.textMuted, fontSize: 12),
                      )
                    : source.startTimeLabel.isNotEmpty
                        ? Text(
                            'Started ${source.startTimeLabel}',
                            style: TextStyle(color: cf.textMuted, fontSize: 12),
                          )
                        : null,
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

  void _applySeekRequest(
    MatchStreamSeekRequest request,
    List<MatchStreamSource> sources,
    MatchModel match,
  ) {
    if (request.nonce == _lastAppliedSeekNonce) return;
    _lastAppliedSeekNonce = request.nonce;

    final offset = Duration(milliseconds: request.offsetMs);
    final resolved = MatchStreamPlayback.resolveSessionForHighlight(
      match,
      sessionId: request.sessionId,
      eventTime: request.eventTime,
    );
    String? targetKey = resolved?.effectiveSessionKey;

    if (targetKey == null) {
      final sessionId = request.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        for (final source in sources) {
          if (source.sessionId == sessionId ||
              source.sessionKey == sessionId ||
              source.effectiveSessionKey == sessionId) {
            targetKey = source.effectiveSessionKey;
            break;
          }
        }
      }
    }

    targetKey ??= _selectedSessionKey;
    if (targetKey != null &&
        !sources.any((s) => s.effectiveSessionKey == targetKey)) {
      targetKey = sources.isNotEmpty ? sources.first.effectiveSessionKey : null;
    }

    if (targetKey != null && targetKey != _selectedSessionKey) {
      setState(() {
        _selectedSessionKey = targetKey;
        _pendingSeekAfterSwitch = offset;
        _pendingSeekLabel = request.label;
      });
      return;
    }

    unawaited(
      _playerKey.currentState?.seekToOffset(
        offset,
        seekLabel: request.label,
      ),
    );
    if (request.label != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jumped to ${request.label}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<MatchModel?>>(
      matchProvider(widget.match.id),
      (previous, next) {
        final match = next.valueOrNull ?? widget.match;
        final sources = MatchStreamPlayback.sourcesFor(match);
        if (sources.isEmpty) return;
        final prevMatch = previous?.valueOrNull;
        final prevSources = prevMatch != null
            ? MatchStreamPlayback.sourcesFor(prevMatch)
            : null;
        final newestStart = sources.first.addedAt?.millisecondsSinceEpoch;
        final signature = _playbackSignature(sources);
        final prevSignature =
            prevSources != null ? _playbackSignature(prevSources) : null;
        if (_trackedNewestStartMs == newestStart &&
            signature == prevSignature &&
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

    ref.listen<MatchStreamSeekRequest?>(
      matchStreamSeekProvider(widget.match.id),
      (previous, next) {
        if (next == null) return;
        final sources = MatchStreamPlayback.sourcesFor(match);
        if (sources.isEmpty) return;
        _applySeekRequest(next, sources, match);
      },
    );

    if (!_checkedInitialSeek) {
      _checkedInitialSeek = true;
      final pendingSeek = ref.read(matchStreamSeekProvider(widget.match.id));
      if (pendingSeek != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final latestMatch =
              ref.read(matchProvider(widget.match.id)).valueOrNull ?? match;
          final latestSources = MatchStreamPlayback.sourcesFor(latestMatch);
          if (latestSources.isEmpty) return;
          _applySeekRequest(pendingSeek, latestSources, latestMatch);
        });
      }
    }

    final selectedIndex = _indexForSources(sources);
    final current = sources[selectedIndex];
    final playableSources = MatchStreamPlayback.playableSourcesFor(match);
    final cf = context.cf;
    final studioConfig = ref.watch(streamStudioConfigProvider(widget.match.id));
    final landscapeFullscreen = MatchStreamPlayback.isLandscapeBroadcast(
      match,
      studioOrientation: studioConfig.orientation,
    );
    final horizontalPad = widget.edgeToEdge ? 0.0 : 16.0;
    final showPicker = playableSources.length > 1;
    final showSessionBar = sources.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSessionBar)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad + 12, 4, horizontalPad + 12, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cf.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cf.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: showPicker
                    ? InkWell(
                        onTap: () =>
                            _pickStreamSession(context, playableSources, cf),
                        borderRadius: BorderRadius.circular(6),
                        child: _sessionBarRow(
                          cf: cf,
                          source: current,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cf.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${playableSources.length}',
                                  style: TextStyle(
                                    color: cf.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.unfold_more,
                                size: 18,
                                color: cf.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _sessionBarRow(cf: cf, source: current),
              ),
            ),
          ),
        MatchStreamPlayer(
          key: _playerKey,
          source: current,
          edgeToEdge: widget.edgeToEdge,
          awaitingWatchUrl: _awaitingWatchUrl(current, match),
          landscapeFullscreen: landscapeFullscreen,
          pendingSeek: _pendingSeekAfterSwitch,
          onPendingSeekApplied: () {
            final label = _pendingSeekLabel;
            if (_pendingSeekAfterSwitch != null) {
              setState(() {
                _pendingSeekAfterSwitch = null;
                _pendingSeekLabel = null;
              });
            }
            if (label != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Jumped to $label'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
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
    this.watchUrl,
  });

  final bool saved;
  final bool skipped;
  final String? watchUrl;
}

/// Bottom sheet for broadcasters to paste a public live / VOD watch link.
Future<StreamWatchUrlSheetResult?> showStreamWatchUrlSheet({
  required BuildContext context,
  required String matchId,
  MatchModel? match,
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
      title: title,
      subtitle: subtitle,
    ),
  );
}

class _StreamWatchUrlSheet extends ConsumerStatefulWidget {
  const _StreamWatchUrlSheet({
    required this.matchId,
    this.match,
    required this.title,
    this.subtitle,
  });

  final String matchId;
  final MatchModel? match;
  final String title;
  final String? subtitle;

  @override
  ConsumerState<_StreamWatchUrlSheet> createState() =>
      _StreamWatchUrlSheetState();
}

class _StreamWatchUrlSheetState extends ConsumerState<_StreamWatchUrlSheet> {
  late final TextEditingController _urlCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final watchUrl = MatchStreamPlayback.canonicalWatchUrl(_urlCtrl.text);

    if (watchUrl == null || !MatchStreamPlayback.isValidWatchUrl(watchUrl)) {
      setState(() => _error = 'Enter a valid YouTube, Facebook, or stream URL');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      final uid = ref.read(authStateProvider).value?.uid;
      await ref.read(matchRepositoryProvider).addStreamWatchUrl(
            widget.matchId,
            watchUrl: watchUrl,
            addedByUserId: uid,
            addedByName: profile?.effectiveName,
          );
      if (!mounted) return;
      Navigator.of(context).pop(
        StreamWatchUrlSheetResult(
          saved: true,
          watchUrl: watchUrl,
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
                'Paste the public watch link from YouTube Studio (Share) or your '
                'streaming platform. Viewers will see it on the scorecard like '
                'YouTube automatic go-live.',
            style: TextStyle(color: cf.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: 'Watch URL',
              hintText: 'https://www.youtube.com/watch?v=…',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onSubmitted: (_) => _saving ? null : _save(),
          ),
          const SizedBox(height: 8),
          Text(
            'Saved to the same stream list as automatic YouTube go-live — each '
            'go-live or pasted link is kept so viewers can switch sessions.',
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
