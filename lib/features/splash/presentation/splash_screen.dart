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
    if (profile != null && !profile.onboardingCompleted) {
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
      body: Container(
        decoration: BoxDecoration(gradient: context.cf.heroGradient),
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_cricket,
                    size: 80, color: CfColors.gold.withValues(alpha: 0.9)),
                const SizedBox(height: 24),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score • Stream • Shine',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CfColors.gold,
                      ),
                ),
                const SizedBox(height: 48),
                CircularProgressIndicator(color: CfColors.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
