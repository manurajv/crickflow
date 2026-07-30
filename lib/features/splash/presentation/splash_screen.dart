import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../core/routing/deep_link_handler.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../data/models/user_model.dart';
import '../../../features/streaming/data/active_stream_session.dart';
import '../../../shared/providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Future<String?> _launchRouteFuture;

  @override
  void initState() {
    super.initState();
    _launchRouteFuture = _resolveLaunchRoute();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1800), _bootstrap);
  }

  Future<String?> _resolveLaunchRoute() async {
    final pending = DeepLinkHandler.takePendingPath();
    if (pending != null && pending.isNotEmpty) return pending;
    return DeepLinkHandler.resolveInitialLocation();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone =
        prefs.getBool(PrefsKeys.onboardingComplete) ?? false;

    if (!onboardingDone) {
      context.go('/onboarding');
      return;
    }

    // Re-read in case the uriLinkStream delivered the link after our first poll.
    final launchRoute = DeepLinkHandler.takePendingPath() ??
        await _launchRouteFuture ??
        await DeepLinkHandler.resolveInitialLocation(retry: true);

    if (!mounted) return;

    final router = GoRouter.of(context);
    final currentPath =
        router.routerDelegate.currentConfiguration.uri.path;

    // Stream/deep-link handler may have navigated off splash already — don't reset to home.
    if (launchRoute == null &&
        currentPath != '/splash' &&
        DeepLinkHandler.isTournamentJoinRoute(currentPath)) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go(launchRoute ?? '/home');
      return;
    }

    if (launchRoute == null) {
      final liveRoute = await ActiveStreamSession.resolveResumeRoute(
        ref.read(matchRepositoryProvider),
      );
      if (liveRoute != null) {
        if (mounted) context.go(liveRoute);
        return;
      }
    }

    UserModel? profile;
    try {
      profile = await ref
          .read(authRepositoryProvider)
          .getCurrentUserProfile()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      profile = null;
    }
    if (!mounted) return;
    if (profile != null && profile.needsPlayerOnboarding) {
      context.go('/player-onboarding');
      return;
    }

    if (launchRoute == null &&
        currentPath != '/splash' &&
        DeepLinkHandler.isTournamentJoinRoute(currentPath)) {
      return;
    }

    final route =
        launchRoute ?? homeRouteForRole(profile?.role ?? UserRole.organizer);
    if (mounted) context.go(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AppConstants.crickflowLogoAsset,
                  height: 168,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: const Color(0xFF0A0E17),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '• Score • Stream • Connect',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF1565C0),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,   
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your complete cricket platform',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF555555),
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(color: CfColors.primaryBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
