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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1800), _bootstrap);
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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final pending = DeepLinkHandler.takePendingPath();
      context.go(pending ?? '/home');
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
    final pending = DeepLinkHandler.takePendingPath();
    final route = pending ?? homeRouteForRole(profile?.role ?? UserRole.organizer);
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
