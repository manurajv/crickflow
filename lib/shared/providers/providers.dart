import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/overlay_state_model.dart';
import '../../data/models/team_model.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/match_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/fantasy_repository.dart';
import '../../data/models/fantasy_entry_model.dart';
import '../../data/models/fantasy_league_model.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/stream_service.dart';
import '../../data/services/webrtc_signaling_service.dart';

// Repositories
final authRepositoryProvider = Provider((ref) => AuthRepository());
final userRepositoryProvider = Provider((ref) => UserRepository());
final matchRepositoryProvider = Provider((ref) => MatchRepository());
final teamRepositoryProvider = Provider((ref) => TeamRepository());
final playerRepositoryProvider = Provider((ref) => PlayerRepository());
final tournamentRepositoryProvider = Provider((ref) => TournamentRepository());
final fantasyRepositoryProvider = Provider((ref) => FantasyRepository());
final notificationServiceProvider = Provider((ref) => NotificationService());
final notificationRepositoryProvider = Provider((ref) => NotificationRepository());
final streamServiceProvider = Provider<StreamService>((ref) {
  final service = StreamService();
  ref.onDispose(service.dispose);
  return service;
});
final storageServiceProvider = Provider((ref) => StorageService());

// Auth
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) async {
      if (user == null) return null;
      return ref.watch(userRepositoryProvider).getUser(user.uid);
    },
    loading: () => null,
    error: (_, _) => null,
  );
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
