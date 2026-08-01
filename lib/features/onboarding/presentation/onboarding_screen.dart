import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/prefs_keys.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/widgets/cf_button.dart';

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.highlights,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> highlights;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.sports_cricket_rounded,
      eyebrow: 'Live scoring',
      title: 'Score every ball\nwith clarity',
      body:
          'Professional ball-by-ball scoring, live scorecards, and match insights — built for local and club cricket.',
      highlights: ['Real-time scorecards', 'Custom match rules', 'Undo & offline sync'],
    ),
    _OnboardingPage(
      icon: Icons.videocam_rounded,
      eyebrow: 'Broadcast',
      title: 'Go live with\nscore overlays',
      body:
          'Stream matches to YouTube or any RTMP destination with camera controls and on-screen scorebugs.',
      highlights: ['YouTube & RTMP', 'Live score overlay', 'Highlights & markers'],
    ),
    _OnboardingPage(
      icon: Icons.emoji_events_rounded,
      eyebrow: 'Compete & connect',
      title: 'Teams, tournaments\n& community',
      body:
          'Build squads, run leagues and knockouts, follow players, and grow your cricket network in one place.',
      highlights: ['League & knockout', 'Player profiles', 'Discover & chat'],
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.onboardingComplete, true);
    if (mounted) context.go('/home');
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: cf.background,
      body: Stack(
        children: [
          const _OnboardingBackdrop(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceLg,
                    AppDimens.spaceSm,
                    AppDimens.spaceSm,
                    0,
                  ),
                  child: Row(
                    children: [
                      _BrandMark(cf: cf),
                      const Spacer(),
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: cf.textMuted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spaceMd,
                            vertical: AppDimens.spaceSm,
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _OnboardingPageView(
                      page: _pages[i],
                      cf: cf,
                      theme: theme,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceXl,
                    0,
                    AppDimens.spaceXl,
                    AppDimens.spaceLg,
                  ),
                  child: Column(
                    children: [
                      _PageIndicators(
                        count: _pages.length,
                        index: _page,
                        active: cf.accent,
                        inactive: cf.border,
                      ),
                      const SizedBox(height: AppDimens.spaceXl),
                      CfButton(
                        label: isLast ? 'Get started' : 'Continue',
                        isGold: true,
                        icon: isLast
                            ? Icons.arrow_forward_rounded
                            : Icons.arrow_forward_ios_rounded,
                        onPressed: _next,
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(
                        AppConstants.appTagline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cf.textMuted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.cf});

  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cf.accent.withValues(alpha: cf.isLight ? 0.12 : 0.2),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Icon(
            Icons.sports_cricket_rounded,
            size: 18,
            color: cf.accent,
          ),
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cf.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
        ),
      ],
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(color: cf.background),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -60,
                child: _Blob(
                  size: 220,
                  color: cf.accent.withValues(alpha: cf.isLight ? 0.08 : 0.12),
                ),
              ),
              Positioned(
                bottom: 120,
                left: -70,
                child: _Blob(
                  size: 180,
                  color: CfColors.primaryBlueLight
                      .withValues(alpha: cf.isLight ? 0.07 : 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({
    required this.page,
    required this.cf,
    required this.theme,
  });

  final _OnboardingPage page;
  final CfColors cf;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceXl),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _HeroIcon(icon: page.icon, cf: cf),
          const SizedBox(height: AppDimens.spaceXl + 4),
          Text(
            page.eyebrow.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: cf.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: cf.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cf.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
          Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceSm,
            alignment: WrapAlignment.center,
            children: [
              for (final h in page.highlights) _FeatureChip(label: h, cf: cf),
            ],
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.cf});

  final IconData icon;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: cf.surface,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: cf.border),
        boxShadow: [
          BoxShadow(
            color: cf.cardShadow,
            blurRadius: cf.isLight ? 24 : 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cf.accent.withValues(alpha: cf.isLight ? 0.14 : 0.22),
                  CfColors.primaryBlueLight
                      .withValues(alpha: cf.isLight ? 0.08 : 0.12),
                ],
              ),
            ),
          ),
          Icon(icon, size: 44, color: cf.accent),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, required this.cf});

  final String label;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: cf.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cf.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: cf.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cf.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicators extends StatelessWidget {
  const _PageIndicators({
    required this.count,
    required this.index,
    required this.active,
    required this.inactive,
  });

  final int count;
  final int index;
  final Color active;
  final Color inactive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: selected ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? active : inactive,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}
