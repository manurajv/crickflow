import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_revision_model.dart';
import '../../data/models/overlay_state_model.dart';
import '../../data/models/team_model.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/match_repository.dart';
import '../../data/repositories/match_target_revision_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/team_join_request_repository.dart';
import '../../data/repositories/team_roster_report_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/match_follower_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/fantasy_repository.dart';
import '../../data/models/fantasy_entry_model.dart';
import '../../data/models/fantasy_league_model.dart';
import '../../data/services/google_maps_location_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/team_qr_service.dart';
import '../../data/services/stream_service.dart';
import '../../data/services/user_profile_cache_service.dart';
import '../../data/services/webrtc_signaling_service.dart';
import 'offline_sync_provider.dart';

// Repositories
final authRepositoryProvider = Provider((ref) => AuthRepository());
final userRepositoryProvider = Provider((ref) => UserRepository());
final matchRepositoryProvider = Provider((ref) => MatchRepository(
      localStore: ref.watch(matchLocalStoreProvider),
      syncService: ref.watch(offlineSyncServiceProvider),
    ));
final matchTargetRevisionRepositoryProvider =
    Provider((ref) => MatchTargetRevisionRepository(
          localStore: ref.watch(matchLocalStoreProvider),
          syncService: ref.watch(offlineSyncServiceProvider),
        ));
final teamQrServiceProvider = Provider(
  (ref) => TeamQrService(storage: ref.watch(storageServiceProvider)),
);
final teamRepositoryProvider = Provider(
  (ref) => TeamRepository(qrService: ref.watch(teamQrServiceProvider)),
);
final playerRepositoryProvider = Provider(
  (ref) => PlayerRepository(
    notificationRepository: ref.watch(notificationRepositoryProvider),
  ),
);
final teamJoinRequestRepositoryProvider = Provider(
  (ref) => TeamJoinRequestRepository(
    playerRepository: ref.watch(playerRepositoryProvider),
    notificationRepository: ref.watch(notificationRepositoryProvider),
  ),
);
final tournamentRepositoryProvider = Provider((ref) => TournamentRepository());
final fantasyRepositoryProvider = Provider((ref) => FantasyRepository());
final notificationServiceProvider = Provider((ref) => NotificationService());
final notificationRepositoryProvider = Provider((ref) => NotificationRepository());
final matchFollowerRepositoryProvider =
    Provider((ref) => MatchFollowerRepository());
final notificationPreferencesRepositoryProvider =
    Provider((ref) => NotificationPreferencesRepository());
final teamRosterReportRepositoryProvider =
    Provider((ref) => TeamRosterReportRepository());
final streamServiceProvider = Provider<StreamService>((ref) {
  final service = StreamService();
  ref.onDispose(service.dispose);
  return service;
});
final storageServiceProvider = Provider((ref) => StorageService());
final userProfileCacheServiceProvider =
    Provider((ref) => UserProfileCacheService());
final googleMapsLocationServiceProvider =
    Provider((ref) => GoogleMapsLocationService());

// Auth
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authUser = await ref.watch(authStateProvider.future);
  if (authUser == null) return null;
  var profile = await ref.read(userRepositoryProvider).getUser(authUser.uid);
  if (profile == null) {
    profile =
        await ref.read(authRepositoryProvider).ensureProfileForAuthUser(authUser);
  }
  return profile;
});

// Matches — global feed (live first) so players/viewers see all public matches
final matchesProvider = StreamProvider<List<MatchModel>>((ref) {
  return ref.watch(matchRepositoryProvider).watchMatchFeed();
});

final matchProvider = StreamProvider.family<MatchModel?, String>((ref, id) {
  return ref.watch(matchRepositoryProvider).watchMatch(id);
});

final ballEventsProvider =
    StreamProvider.family<List<BallEventModel>, String>((ref, matchId) {
  return ref.watch(matchRepositoryProvider).watchBallEvents(matchId);
});

final matchRevisionsProvider =
    StreamProvider.family<List<MatchRevisionModel>, String>((ref, matchId) {
  return ref
      .watch(matchTargetRevisionRepositoryProvider)
      .watchMatchRevisions(matchId);
});

final webrtcSignalingProvider = Provider((ref) => WebrtcSignalingService());

final webrtcRoomProvider =
    StreamProvider.family<WebrtcRoomState?, String>((ref, matchId) {
  return ref.watch(webrtcSignalingProvider).watchRoom(matchId);
});

final overlayProvider =
    StreamProvider.family<OverlayStateModel?, String>((ref, matchId) {
  return ref.watch(matchRepositoryProvider).watchOverlay(matchId);
});

// Teams & Tournaments
final teamsProvider = StreamProvider<List<TeamModel>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  return ref.watch(teamRepositoryProvider).watchTeams(createdBy: uid);
});

final allTeamsProvider = StreamProvider<List<TeamModel>>((ref) {
  return ref.watch(teamRepositoryProvider).watchTeams();
});

final tournamentsProvider = StreamProvider<List<TournamentModel>>((ref) {
  return ref.watch(tournamentRepositoryProvider).watchTournaments();
});

// Fantasy
final fantasyUserEntriesProvider =
    StreamProvider<List<FantasyEntryWithLeague>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(fantasyRepositoryProvider).watchUserEntries(uid);
});

final fantasyLeagueProvider =
    StreamProvider.family<FantasyLeagueModel?, String>((ref, leagueId) {
  return ref.watch(fantasyRepositoryProvider).watchLeague(leagueId);
});

final fantasyLeaderboardProvider =
    StreamProvider.family<List<FantasyEntryModel>, String>((ref, leagueId) {
  return ref.watch(fantasyRepositoryProvider).watchLeaderboard(leagueId);
});

final fantasyMyEntryProvider = StreamProvider.family<FantasyEntryModel?,
    (String leagueId, String userId)>((ref, params) {
  return ref.watch(fantasyRepositoryProvider).watchUserEntry(
        leagueId: params.$1,
        userId: params.$2,
      );
});
