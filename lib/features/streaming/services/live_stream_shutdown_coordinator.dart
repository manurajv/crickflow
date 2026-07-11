import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../data/models/match_model.dart';
import '../../../data/repositories/match_repository.dart';
import '../../../domain/streaming/stream_playback_merger.dart';
import '../../../shared/providers/providers.dart';
import '../data/active_stream_session.dart';
import 'stream_lifecycle_log.dart';

/// Global app-level guard: ends ghost streams when the process is removed from Recents.
class LiveStreamShutdownCoordinator extends ConsumerStatefulWidget {
  const LiveStreamShutdownCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveStreamShutdownCoordinator> createState() =>
      _LiveStreamShutdownCoordinatorState();
}

class _LiveStreamShutdownCoordinatorState
    extends ConsumerState<LiveStreamShutdownCoordinator>
    with WidgetsBindingObserver {
  bool _emergencyStopInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = ref.read(streamServiceProvider);
    if (!service.liveSessionActive && !service.isStreaming) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        StreamLifecycleLog.background();
        return;
      case AppLifecycleState.resumed:
        StreamLifecycleLog.foreground();
        return;
      case AppLifecycleState.detached:
        unawaited(_emergencyStopLive('APP_REMOVED'));
        return;
      case AppLifecycleState.hidden:
        return;
    }
  }

  Future<void> _emergencyStopLive(String reason) async {
    if (_emergencyStopInFlight) return;
    _emergencyStopInFlight = true;

    if (reason == 'APP_REMOVED') {
      StreamLifecycleLog.appRemoved();
    }

    final service = ref.read(streamServiceProvider);
    if (!service.liveSessionActive && !service.isStreaming) {
      _emergencyStopInFlight = false;
      return;
    }

    final matchId = await ActiveStreamSession.readMatchId();
    await service.emergencyStopLive();

    if (matchId != null && matchId.isNotEmpty) {
      try {
        final repo = ref.read(matchRepositoryProvider);
        final match = await repo.getMatch(matchId);
        if (match != null) {
          await _markStreamEnded(repo, matchId, match);
        }
      } catch (_) {}
    }

    await ActiveStreamSession.clear();
    _emergencyStopInFlight = false;
  }

  Future<void> _markStreamEnded(
    MatchRepository repo,
    String matchId,
    MatchModel match,
  ) async {
    final endedAt = DateTime.now();
    var entries = StreamPlaybackMerger.endAllLiveSessions(
      existing: match.stream.playbackEntries,
      endedAt: endedAt,
    );
    entries = StreamPlaybackMerger.finalizeEndedSessionUrls(
      entries: entries,
      canonicalWatchUrl: match.stream.youtubeWatchUrl,
    );
    await repo.updateStreamMetadata(
      matchId,
      match.stream.copyWith(
        status: StreamStatus.ended,
        playbackEntries: entries,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Ends an active live session without UI — used when the app is killed from Recents.
Future<void> emergencyStopLiveSession(WidgetRef ref) async {
  final service = ref.read(streamServiceProvider);
  if (!service.liveSessionActive && !service.isStreaming) return;

  StreamLifecycleLog.appRemoved();
  final matchId = await ActiveStreamSession.readMatchId();
  await service.emergencyStopLive();

  if (matchId != null && matchId.isNotEmpty) {
    try {
      final repo = ref.read(matchRepositoryProvider);
      final match = await repo.getMatch(matchId);
      if (match != null) {
        final endedAt = DateTime.now();
        var entries = StreamPlaybackMerger.endAllLiveSessions(
          existing: match.stream.playbackEntries,
          endedAt: endedAt,
        );
        entries = StreamPlaybackMerger.finalizeEndedSessionUrls(
          entries: entries,
          canonicalWatchUrl: match.stream.youtubeWatchUrl,
        );
        await repo.updateStreamMetadata(
          matchId,
          match.stream.copyWith(
            status: StreamStatus.ended,
            playbackEntries: entries,
          ),
        );
      }
    } catch (_) {}
  }
  await ActiveStreamSession.clear();
}
