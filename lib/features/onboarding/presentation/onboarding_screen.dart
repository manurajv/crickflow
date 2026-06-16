import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/cf_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.scoreboard,
      'Live scoring',
      'Ball-by-ball scoring with real-time scorecards and overlays for your stream.',
    ),
    (
      Icons.videocam,
      'Broadcast live',
      'Send your match to YouTube or any RTMP server with the in-app camera publisher.',
    ),
    (
      Icons.emoji_events,
      'Teams & tournaments',
      'Manage squads, run leagues, and knockout brackets — built for Sri Lankan cricket.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.onboardingComplete, true);
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final p = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceXl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(p.$1, size: 52, color: AppColors.gold),
                          const SizedBox(height: AppDimens.spaceXl),
                          Text(
                            p.$2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: AppDimens.spaceMd),
                          Text(
                            p.$3,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? AppColors.gold : Colors.white24,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimens.spaceLg),
                child: CfButton(
                  label: _page == _pages.length - 1
                      ? 'Get started'
                      : 'Next',
                  isGold: true,
                  onPressed: () {
                    if (_page < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    } else {
                      _finish();
                    }
                  },
                ),
              ),
              Text(
                AppConstants.appName,
                style: TextStyle(
                  color: AppColors.gold.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
