import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/admob_config.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/ads/cf_sticky_banner_ad.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import 'widgets/home_promotions_carousel.dart';
import 'widgets/matches_near_you_section.dart';
import 'widgets/nearby_tournaments_section.dart';
import '../providers/nearby_matches_provider.dart';
import '../providers/nearby_tournaments_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerFcm());
  }

  Future<void> _registerFcm() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid != null) {
      await ref.read(notificationServiceProvider).registerDevice(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final uid = ref.watch(authStateProvider).value?.uid;
    final isGuest = uid == null;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.valueOrNull;
    final role = profile?.role ?? UserRole.organizer;
    final isViewer = !isGuest && role == UserRole.viewer;
    final unreadCount =
        ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return ShellTabScaffold(
      title: const Text('CrickFlow'),
      actions: [
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search),
          onPressed: () => context.push('/search'),
        ),
        IconButton(
          onPressed: () {
            requireAuthVoid(
              context: context,
              ref: ref,
              returnPath: '/notifications',
              action: () async {
                if (context.mounted) context.push('/notifications');
              },
            );
          },
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            backgroundColor: CfColors.accentRed,
            child: Icon(
              unreadCount > 0
                  ? Icons.notifications
                  : Icons.notifications_outlined,
              color: unreadCount > 0 ? cf.accent : null,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
      // Pinned above the shell NavigationBar; does not scroll with content.
      bottomNavigationBar: const CfStickyBannerAd(
        placement: AdPlacement.home,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(matchesProvider);
          ref.invalidate(tournamentsProvider);
          ref.invalidate(nearbyMatchesProvider);
          ref.invalidate(nearbyTournamentsProvider);
          ref.invalidate(homePromotionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
          children: [
            _WelcomeHeader(profileAsync: profileAsync, isGuest: isGuest),
            if (isViewer) _viewerBanner(context),
            const MatchesNearYouSection(),
            const HomePromotionsCarousel(),
            const NearbyTournamentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _viewerBanner(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Card(
        child: ListTile(
          leading: Icon(Icons.visibility, color: cf.info),
          title: const Text('Viewer mode'),
          subtitle: const Text('Browse scores and scorecards'),
          trailing: TextButton(
            onPressed: () => context.push('/profile'),
            child: const Text('Profile'),
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.profileAsync, required this.isGuest});

  final AsyncValue<UserModel?> profileAsync;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceLg,
      ),
      decoration: BoxDecoration(
        gradient: cf.heroGradient,
        borderRadius: AppDimens.cardRadius,
        border: Border.all(color: cf.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                profileAsync.when(
                  data: (p) => Text(
                    isGuest
                        ? 'Hi, Guest'
                        : 'Hi, ${p?.displayName.isNotEmpty == true ? p!.displayName : p?.effectiveName ?? 'Scorer'}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  loading: () => Text(
                    'Hi',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  error: (_, _) => Text(
                    'Hi',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover nearby matches, live scores, and tournaments.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.sports_cricket,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
