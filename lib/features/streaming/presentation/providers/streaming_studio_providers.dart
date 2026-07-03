import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/services/stream_service.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../data/models/replay_marker_model.dart';
import '../../data/models/saved_rtmp_server.dart';
import '../../data/models/saved_stream_key.dart';
import '../../data/models/stream_studio_config.dart';
import '../../data/repositories/stream_studio_repository.dart';
import '../../domain/stream_event_detector.dart';
import '../../domain/stream_permission_service.dart';
import '../../domain/streaming_enums.dart';
import '../../data/models/stream_overlay_theme.dart';
import '../../domain/destinations/stream_destination_registry.dart';
import '../../studio/broadcast_session_controller.dart';
import '../../services/stream_platform_service.dart';
import '../../services/stream_youtube_auth_service.dart';

final streamStudioRepositoryProvider =
    Provider((ref) => StreamStudioRepository());

final streamPlatformServiceProvider =
    Provider((ref) => StreamPlatformService());

final streamDestinationRegistryProvider = Provider<StreamDestinationRegistry>(
  (ref) => StreamDestinationRegistry(
    platformService: ref.watch(streamPlatformServiceProvider),
  ),
);

final broadcastSessionControllerProvider =
    Provider<BroadcastSessionController>((ref) {
  return BroadcastSessionController(
    streamService: ref.watch(streamServiceProvider),
    destinationRegistry: ref.watch(streamDestinationRegistryProvider),
    matchRepository: ref.watch(matchRepositoryProvider),
  );
});

final streamYouTubeAuthServiceProvider = Provider(
  (ref) => StreamYouTubeAuthService(
    platformService: ref.watch(streamPlatformServiceProvider),
  ),
);

final streamPermissionServiceProvider =
    Provider((ref) => const StreamPermissionService());

final streamEventDetectorProvider =
    Provider((ref) => const StreamEventDetector());

final savedRtmpServersProvider =
    FutureProvider<List<SavedRtmpServer>>((ref) async {
  return ref.watch(streamStudioRepositoryProvider).loadSavedRtmpServers();
});

final streamKeyHistoryProvider =
    FutureProvider<List<SavedStreamKey>>((ref) async {
  return ref.watch(streamStudioRepositoryProvider).loadStreamKeyHistory();
});

final streamKeyHistoryForPlatformProvider =
    FutureProvider.family<List<SavedStreamKey>, StreamPlatform>((ref, platform) {
  return ref.watch(streamStudioRepositoryProvider).loadStreamKeyHistoryForPlatform(platform);
});

Future<void> rememberStreamKeyForConfig(
  StreamStudioRepository repo,
  StreamStudioConfig config, {
  String? label,
}) async {
  if (config.streamKey.trim().isEmpty) return;
  await repo.rememberStreamKey(
    SavedStreamKey(
      id: _uuid.v4(),
      streamKey: config.streamKey.trim(),
      platform: config.platform,
      rtmpUrl: config.rtmpUrl.trim(),
      label: label ?? config.platform.label,
    ),
  );
}

final replayMarkersProvider =
    StreamProvider.family<List<ReplayMarkerModel>, String>((ref, matchId) {
  return ref.watch(streamStudioRepositoryProvider).watchReplayMarkers(matchId);
});

final streamCanStartProvider =
    Provider.family<bool, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  final uid = ref.watch(authStateProvider).value?.uid;
  final role = ref.watch(currentUserProfileProvider).valueOrNull?.role;
  if (match == null || uid == null) return false;

  var isOrganizer = false;
  final tournamentId = match.tournamentId;
  if (tournamentId != null && tournamentId.isNotEmpty) {
    final tRole = ref.watch(
      tournamentMemberRoleProvider((tournamentId, uid)),
    );
    isOrganizer =
        tRole == TournamentRole.owner || tRole == TournamentRole.admin;
  }

  return ref.watch(streamPermissionServiceProvider).canStartStream(
        match: match,
        userId: uid,
        role: role ?? UserRole.viewer,
        isTournamentOrganizer: isOrganizer,
      );
});

class StreamStudioNotifier extends StateNotifier<StreamStudioConfig> {
  StreamStudioNotifier() : super(const StreamStudioConfig());

  void initFromMatch(MatchModel match) {
    state = state.copyWith(
      title: match.title,
      description: '${match.teamAName} vs ${match.teamBName}',
      rtmpUrl: match.stream.rtmpUrl ?? StreamPlatform.youtube.defaultRtmpUrl,
      streamKey: match.stream.streamKey ?? '',
      youtubeWatchUrl: match.stream.youtubeWatchUrl ?? '',
    );
  }

  void update(StreamStudioConfig Function(StreamStudioConfig) fn) {
    state = fn(state);
  }

  StreamOverlayTheme get overlayTheme => StreamOverlayTheme(
        layout: state.overlayLayout,
        primaryColor: state.overlayPrimaryColor,
        secondaryColor: state.overlaySecondaryColor,
        opacity: state.overlayOpacity,
        roundedCorners: state.overlayRoundedCorners,
        compactMode: state.overlayCompactMode,
        showSponsorBanner: state.showSponsorBanner,
        showTicker: state.showTicker,
        showWatermark: state.showWatermark,
        watermarkOpacity: state.watermarkOpacity,
      );
}

final streamStudioConfigProvider = StateNotifierProvider.autoDispose
    .family<StreamStudioNotifier, StreamStudioConfig, String>((ref, matchId) {
  final match = ref.watch(matchProvider(matchId)).valueOrNull;
  final notifier = StreamStudioNotifier();
  if (match != null) {
    notifier.initFromMatch(match);
  }
  final stream = ref.read(streamServiceProvider);
  if (stream.liveSessionActive || stream.isStreaming) {
    notifier.update(
      (c) => c.copyWith(
        orientation: stream.orientation,
        orientationLocked: true,
      ),
    );
  }
  ref.listen(matchProvider(matchId), (prev, next) {
    final m = next.valueOrNull;
    if (m != null && prev?.valueOrNull?.stream != m.stream) {
      notifier.initFromMatch(m);
    }
  });
  return notifier;
});

final activeEventOverlayProvider = StateProvider.autoDispose
    .family<StreamEventOverlay?, String>((ref, matchId) => null);

final streamHealthProvider = StreamProvider.autoDispose<StreamHealthMetrics>((ref) {
  return ref.watch(streamServiceProvider).healthStream;
});

final youtubeChannelsProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(streamPlatformServiceProvider).fetchYouTubeChannels();
});

const _uuid = Uuid();

Future<void> saveReplayMarker({
  required WidgetRef ref,
  required String matchId,
  required ReplayMarkerKind kind,
  required String label,
  required int streamOffsetMs,
  String? ballEventId,
}) async {
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) return;
  final marker = ReplayMarkerModel(
    id: _uuid.v4(),
    matchId: matchId,
    kind: kind,
    label: label,
    streamOffsetMs: streamOffsetMs,
    createdBy: uid,
    ballEventId: ballEventId,
    createdAt: DateTime.now(),
  );
  await ref.read(streamStudioRepositoryProvider).addReplayMarker(marker);
}
