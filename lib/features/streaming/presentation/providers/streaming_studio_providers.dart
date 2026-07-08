import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/enums.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/player_model.dart';
import '../../../../data/services/stream_service.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../data/models/replay_marker_model.dart';
import '../../data/models/saved_rtmp_server.dart';
import '../../data/models/saved_stream_key.dart';
import '../../data/models/saved_stream_studio_preferences.dart';
import '../../data/models/stream_studio_config.dart';
import '../../data/repositories/stream_studio_repository.dart';
import '../../../../shared/providers/match_squads_provider.dart';
import '../../data/models/batter_intro_profile.dart';
import '../../data/models/bowler_intro_profile.dart';
import '../../domain/batter_intro_profile_builder.dart';
import '../../domain/bowler_intro_profile_builder.dart';
import '../../domain/stream_event_detector.dart';
import 'player_intro_lookup.dart';
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
    ref: ref,
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
      // No platform-name fallback — the saved-key UI shows the last 8 key digits.
      label: label ?? '',
    ),
  );
}

Future<void> rememberLastStudioPreferencesForConfig(
  StreamStudioRepository repo,
  StreamStudioConfig config,
) async {
  await repo.rememberLastStudioPreferences(config);
}

StreamStudioConfig applySavedStudioPreferences(
  StreamStudioConfig current,
  SavedStreamStudioPreferences? saved,
) {
  if (saved == null) {
    return current.copyWith(
      orientation: StreamOrientationMode.landscape,
      orientationLocked: true,
    );
  }

  return current.copyWith(
    platform: saved.platform,
    broadcastSetupMode: saved.broadcastSetupMode,
    orientation: saved.orientation,
    orientationLocked: true,
    streamingMode: saved.streamingMode,
    rtmpUrl: saved.rtmpUrl.isNotEmpty ? saved.rtmpUrl : current.rtmpUrl,
    streamKey: saved.streamKey,
    youtubeChannelId: saved.youtubeChannelId,
    youtubeChannelName: saved.youtubeChannelName,
    goLiveImmediately: true,
    resolution: saved.resolution,
  );
}

/// Hydrates studio config when OAuth is linked server-side but [youtubeChannelId]
/// was never written to local config (checklist / Go Live depend on config).
void syncYouTubeChannelToStudioConfig(
  WidgetRef ref,
  String matchId, {
  List<YouTubeChannel>? channels,
}) {
  final list = channels ?? ref.read(youtubeChannelsProvider).valueOrNull;
  if (list == null || list.isEmpty) return;

  final config = ref.read(streamStudioConfigProvider(matchId));
  if (config.youtubeChannelId.isNotEmpty &&
      list.any((c) => c.id == config.youtubeChannelId)) {
    return;
  }

  final linked = list.first;
  ref.read(streamStudioConfigProvider(matchId).notifier).update(
        (c) => c.copyWith(
          youtubeChannelId: linked.id,
          youtubeChannelName: linked.title,
        ),
      );
}

Future<void> persistStudioConfigPreferences(WidgetRef ref, String matchId) async {
  final config = ref.read(streamStudioConfigProvider(matchId));
  await ref.read(streamStudioRepositoryProvider).rememberLastStudioPreferences(
        config,
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

  /// Updates stream metadata from Firestore without resetting locked orientation.
  void syncStreamMetadataFromMatch(MatchModel match) {
    final lockedOrientation = state.orientation;
    final orientationLocked = state.orientationLocked;
    initFromMatch(match);
    if (orientationLocked) {
      state = state.copyWith(
        orientation: lockedOrientation,
        orientationLocked: true,
      );
    }
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
  final notifier = StreamStudioNotifier();
  final match = ref.read(matchProvider(matchId)).valueOrNull;
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
      notifier.syncStreamMetadataFromMatch(m);
    }
  });
  return notifier;
});

final activeEventOverlayProvider = StateProvider.autoDispose
    .family<StreamEventOverlay?, String>((ref, matchId) => null);

/// Side-panel intro queued while a center overlay (e.g. WICKET) is still showing.
final pendingSidePanelOverlayProvider = StateProvider.autoDispose
    .family<StreamEventOverlay?, String>((ref, matchId) => null);

final bowlerIntroProfileProvider = FutureProvider.autoDispose
    .family<BowlerIntroProfile, PlayerIntroLookup>((ref, lookup) async {
  final match = await ref.watch(matchProvider(lookup.matchId).future);
  if (match == null) {
    return BowlerIntroProfile(playerName: lookup.fallbackName);
  }

  final squads =
      await ref.watch(matchDualSquadsProvider(lookup.matchId).future);
  final playerRepo = ref.read(playerRepositoryProvider);

  PlayerModel? player;
  if (lookup.playerId.isNotEmpty) {
    player = await playerRepo.getPlayer(lookup.playerId);
  }

  String? teamName;
  String? teamLogoUrl;
  for (final side in [squads.teamA, squads.teamB]) {
    final inSquad = side.allPlayers.any(
      (p) => p.id == lookup.playerId || p.playerId == lookup.playerId,
    );
    if (inSquad) {
      teamName = side.teamName;
      teamLogoUrl = side.teamLogoUrl;
      break;
    }
  }

  final matches = await ref.watch(matchesProvider.future);
  final completed = matches
      .where((m) => m.status == MatchStatus.completed)
      .toList(growable: false);

  return BowlerIntroProfileBuilder.build(
    match: match,
    playerId: lookup.playerId,
    fallbackName: lookup.fallbackName,
    player: player,
    teamName: teamName,
    teamLogoUrl: teamLogoUrl,
    completedMatches: completed,
  );
});

final batterIntroProfileProvider = FutureProvider.autoDispose
    .family<BatterIntroProfile, PlayerIntroLookup>((ref, lookup) async {
  final match = await ref.watch(matchProvider(lookup.matchId).future);
  if (match == null) {
    return BatterIntroProfile(playerName: lookup.fallbackName);
  }

  final squads =
      await ref.watch(matchDualSquadsProvider(lookup.matchId).future);
  final playerRepo = ref.read(playerRepositoryProvider);

  PlayerModel? player;
  if (lookup.playerId.isNotEmpty) {
    player = await playerRepo.getPlayer(lookup.playerId);
  }

  String? teamName;
  String? teamLogoUrl;
  for (final side in [squads.teamA, squads.teamB]) {
    final inSquad = side.allPlayers.any(
      (p) => p.id == lookup.playerId || p.playerId == lookup.playerId,
    );
    if (inSquad) {
      teamName = side.teamName;
      teamLogoUrl = side.teamLogoUrl;
      break;
    }
  }

  final matches = await ref.watch(matchesProvider.future);
  final completed = matches
      .where((m) => m.status == MatchStatus.completed)
      .toList(growable: false);

  return BatterIntroProfileBuilder.build(
    match: match,
    playerId: lookup.playerId,
    fallbackName: lookup.fallbackName,
    player: player,
    teamName: teamName,
    teamLogoUrl: teamLogoUrl,
    completedMatches: completed,
  );
});

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
