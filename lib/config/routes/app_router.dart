import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/discover/presentation/discover_screen.dart';
import '../../features/fantasy/presentation/fantasy_league_screen.dart';
import '../../features/fantasy/presentation/fantasy_screen.dart';
import '../../features/fantasy/presentation/fantasy_squad_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/matches/presentation/add_match_official_screen.dart';
import '../../features/matches/presentation/match_officials_screen.dart';
import '../../features/matches/presentation/match_team_roles_screen.dart';
import '../../features/matches/presentation/match_toss_screen.dart';
import '../../features/matches/presentation/start_innings_screen.dart';
import '../../features/matches/presentation/powerplay_overs_screen.dart';
import '../../features/matches/presentation/select_match_squad_screen.dart';
import '../../features/matches/presentation/select_team_for_match_screen.dart';
import '../../features/matches/presentation/start_match_flow_screen.dart';
import '../../data/models/match_setup_draft_models.dart';
import '../../features/matches/presentation/match_highlights_screen.dart';
import '../../features/matches/presentation/match_hub_screen.dart';
import '../../features/matches/presentation/matches_list_screen.dart';
import '../../features/matches/presentation/scorecard_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/overlay/presentation/live_overlay_screen.dart';
import '../../features/players/presentation/player_detail_screen.dart';
import '../../features/players/presentation/player_screen.dart';
import '../../features/store/presentation/store_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/scoring/presentation/live_scoring_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/main_shell_scaffold.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/streaming/presentation/live_stream_screen.dart';
import '../../features/streaming/presentation/webrtc_viewer_screen.dart';
import '../../features/teams/presentation/team_add_player_directory_screen.dart';
import '../../features/teams/presentation/team_add_player_quick_screen.dart';
import '../../features/teams/presentation/team_add_players_screen.dart';
import '../../features/teams/presentation/team_detail_screen.dart';
import '../../features/teams/presentation/team_screen.dart';
import '../../features/tournaments/presentation/tournament_screen.dart';
import '../../features/wagon_wheel/presentation/wagon_wheel_view_screen.dart';
import '../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../core/routing/deep_link_handler.dart';
import '../../core/utils/deep_link_utils.dart';
import '../../core/utils/match_permissions.dart';
import '../../shared/providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authRepositoryProvider).authStateChanges,
    ),
    redirect: (context, state) {
      // Android/iOS may pass `crickflow://teams/<id>` as the platform route.
      final incomingUri = state.uri;
      String? deepPath;
      if (incomingUri.scheme == DeepLinkUtils.customScheme) {
        deepPath = DeepLinkUtils.pathFromUri(incomingUri);
      } else {
        deepPath = DeepLinkUtils.normalizeLocation(state.matchedLocation);
      }

      if (deepPath != null &&
          deepPath != state.matchedLocation &&
          deepPath != incomingUri.path) {
        final isLoggedIn = authState.valueOrNull != null;
        if (!isLoggedIn) {
          DeepLinkHandler.pendingPath = deepPath;
        }
        return deepPath;
      }

      final isLoggedIn = authState.valueOrNull != null;
      final path = state.matchedLocation;
      final isAuthRoute = path == '/login';
      final isSplash = path == '/splash';
      final isOnboarding = path == '/onboarding';

      if (isSplash || isOnboarding) return null;
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';

      if (isLoggedIn && path == '/match/create') {
        final profile = ref.read(currentUserProfileProvider).valueOrNull;
        if (profile != null && !canCreateMatches(profile.role)) {
          return '/home';
        }
      }

      return null;
    },
    onException: (context, state, router) {
      final path = DeepLinkUtils.pathFromUri(state.uri) ??
          DeepLinkUtils.normalizeLocation(state.uri.toString());
      if (path != null) {
        router.go(path);
        return;
      }
      router.go('/home');
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (_, __) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/matches',
                builder: (_, __) => const MatchesListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (_, __) => const CommunityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/match/create',
        builder: (_, __) => const StartMatchFlowScreen(),
        routes: [
          GoRoute(
            path: 'select-team',
            builder: (_, state) {
              final slot = state.uri.queryParameters['slot'] ?? 'a';
              return SelectTeamForMatchScreen(
                slotLabel: slot == 'b' ? 'team B' : 'team A',
              );
            },
          ),
          GoRoute(
            path: 'squad/:teamSlot',
            builder: (_, state) => SelectMatchSquadScreen(
              teamSlot: state.pathParameters['teamSlot'] ?? 'a',
            ),
          ),
          GoRoute(
            path: 'roles/:teamSlot',
            builder: (_, state) => MatchTeamRolesScreen(
              teamSlot: state.pathParameters['teamSlot'] ?? 'a',
            ),
          ),
          GoRoute(
            path: 'officials',
            builder: (_, __) => const MatchOfficialsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, state) {
                  final extra = state.extra;
                  var title = 'Add official';
                  var slotLabel = '';
                  MatchOfficialEntry? initial;
                  if (extra is Map<String, dynamic>) {
                    title = extra['title'] as String? ?? title;
                    slotLabel = extra['slotLabel'] as String? ?? slotLabel;
                    initial = extra['initial'] as MatchOfficialEntry?;
                  }
                  return AddMatchOfficialScreen(
                    title: title,
                    slotLabel: slotLabel,
                    initial: initial,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'toss',
            builder: (_, __) => const MatchTossScreen(),
          ),
          GoRoute(
            path: 'powerplay',
            builder: (_, state) {
              final extra = state.extra;
              var totalOvers = 20;
              var slots = <List<int>>[[], [], []];
              if (extra is Map<String, dynamic>) {
                totalOvers = extra['totalOvers'] as int? ?? 20;
                final raw = extra['slots'];
                if (raw is List<List<int>>) {
                  slots = raw;
                } else if (raw is List) {
                  slots = raw
                      .map((e) => List<int>.from(e as List))
                      .toList(growable: false);
                }
              }
              while (slots.length < 3) {
                slots = [...slots, <int>[]];
              }
              return PowerplayOversScreen(
                totalOvers: totalOvers,
                initialSlots: slots.take(3).toList(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/match/:id',
        builder: (_, state) => MatchHubScreen(
          matchId: state.pathParameters['id']!,
          initialTab: state.uri.queryParameters['tab'] ?? 'summary',
        ),
      ),
      GoRoute(
        path: '/match/:id/start-innings',
        builder: (_, state) =>
            StartInningsScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/score',
        builder: (_, state) =>
            LiveScoringScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/scorecard',
        builder: (_, state) => ScorecardScreen(
          matchId: state.pathParameters['id']!,
          exitToHomeOnBack: state.uri.queryParameters['from'] == 'complete',
        ),
      ),
      GoRoute(
        path: '/match/:id/highlights',
        builder: (_, state) =>
            MatchHighlightsScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/stream',
        builder: (_, state) =>
            LiveStreamScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/webrtc',
        builder: (_, state) =>
            WebrtcViewerScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/overlay',
        builder: (_, state) =>
            LiveOverlayScreen(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/tournaments',
        builder: (_, __) => const TournamentScreen(),
      ),
      GoRoute(
        path: '/teams',
        builder: (_, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return TeamScreen(initialTab: tab.clamp(0, 2));
        },
      ),
      GoRoute(
        path: '/teams/:id',
        builder: (_, state) =>
            TeamDetailScreen(teamId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'add-players',
            builder: (_, state) => TeamAddPlayersScreen(
              teamId: state.pathParameters['id']!,
            ),
            routes: [
              GoRoute(
                path: 'quick',
                builder: (_, state) => TeamAddPlayerQuickScreen(
                  teamId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'directory',
                builder: (_, state) => TeamAddPlayerDirectoryScreen(
                  teamId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(path: '/players', builder: (_, __) => const PlayerScreen()),
      GoRoute(
        path: '/players/:id',
        builder: (_, state) =>
            PlayerDetailScreen(playerId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/store', builder: (_, __) => const StoreScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(
        path: '/wagon-wheel',
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return WagonWheelViewScreen(
            title: q['title'] ?? 'Wagon wheel',
            initialFilter: WagonWheelFilter(
              batterId: q['batterId'],
              bowlerId: q['bowlerId'],
              teamId: q['teamId'],
              matchId: q['matchId'],
              tournamentId: q['tournamentId'],
              inningsNumber: int.tryParse(q['innings'] ?? ''),
            ),
          );
        },
      ),
      GoRoute(path: '/fantasy', builder: (_, __) => const FantasyScreen()),
      GoRoute(
        path: '/fantasy/:id',
        builder: (_, state) =>
            FantasyLeagueScreen(leagueId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/fantasy/:id/squad',
        builder: (_, state) =>
            FantasySquadScreen(leagueId: state.pathParameters['id']!),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
