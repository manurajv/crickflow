import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/location_filter_bar.dart';
import '../../../shared/widgets/match_list_card.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _filterCountry = '';
  String _filterCity = '';

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
    final matchesAsync = ref.watch(matchesProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final isGuest = uid == null;
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.valueOrNull;
    final role = profile?.role ?? UserRole.organizer;
    final isViewer = !isGuest && role == UserRole.viewer;
    final showCreateUi = isGuest || !isViewer;
    final unreadCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    Future<void> openCreateMatch() async {
      await requireAuthVoid(
        context: context,
        ref: ref,
        returnPath: '/match/create',
        action: () async {
          if (context.mounted) context.push('/match/create');
        },
      );
    }

    return ShellTabScaffold(
      title: const Text('CrickFlow'),
      floatingActionButton: showCreateUi
          ? FloatingActionButton.extended(
              heroTag: 'home_new_match_fab',
              onPressed: openCreateMatch,
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('New Match'),
            )
          : null,
      actions: [
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
            backgroundColor: AppColors.accentRed,
            child: Icon(
              unreadCount > 0
                  ? Icons.notifications
                  : Icons.notifications_outlined,
              color: unreadCount > 0 ? AppColors.gold : null,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(matchesProvider),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            _WelcomeHeader(profileAsync: profileAsync, isGuest: isGuest),
            if (isViewer) _viewerBanner(context),
            if (showCreateUi)
              _QuickActionsRow(onCreateMatch: openCreateMatch),
            LocationFilterBar(
              onFilterChanged: (country, city) {
                setState(() {
                  _filterCountry = country;
                  _filterCity = city;
                });
              },
            ),
            matchesAsync.when(
              data: (matches) {
                final filtered = matches
                    .where(
                      (m) => locationMatchesFilter(
                        m.location,
                        _filterCountry,
                        _filterCity,
                      ),
                    )
                    .toList();

                if (filtered.isEmpty) {
                  return _emptyState(
                    context,
                    showCreateUi
                        ? 'No matches here yet. Start your first match.'
                        : 'No matches match your filters.',
                    action: showCreateUi
                        ? FilledButton(
                            onPressed: openCreateMatch,
                            child: const Text('Start match'),
                          )
                        : null,
                  );
                }

                final live = filtered
                    .where(
                      (m) =>
                          m.status == MatchStatus.live ||
                          m.status == MatchStatus.inningsBreak,
                    )
                    .toList();
                final rest = filtered
                    .where(
                      (m) =>
                          m.status != MatchStatus.live &&
                          m.status != MatchStatus.inningsBreak,
                    )
                    .take(10)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (live.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Live now',
                        trailing: live.length > 3
                            ? Text(
                                '${live.length} matches',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.liveIndicator),
                              )
                            : null,
                      ),
                      ...live.take(5).map(
                            (m) => MatchListCard(
                              match: m,
                              showQuickLinks: false,
                            ),
                          ),
                    ],
                    _SectionHeader(
                      title: live.isEmpty ? 'Matches' : 'Recent',
                      trailing: TextButton(
                        onPressed: () => context.go('/matches'),
                        child: const Text('My Cricket'),
                      ),
                    ),
                    ...rest.map(
                      (m) => MatchListCard(
                        match: m,
                        showQuickLinks: false,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(AppDimens.spaceXl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppDimens.spaceMd),
                child: Text('Error loading matches: $e'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewerBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.visibility, color: AppColors.gold),
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

  Widget _emptyState(
    BuildContext context,
    String message, {
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceXl),
      child: Column(
        children: [
          Icon(
            Icons.sports_cricket,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppDimens.spaceLg),
            action,
          ],
        ],
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
        gradient: AppColors.heroGradient,
        borderRadius: AppDimens.cardRadius,
        border: Border.all(color: AppColors.border),
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
                  'Score live, follow matches, stream to fans.',
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
              color: AppColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.sports_cricket,
              color: AppColors.gold,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.onCreateMatch});

  final VoidCallback onCreateMatch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        children: [
          _QuickActionChip(
            icon: Icons.sports_cricket,
            label: 'New match',
            color: AppColors.gold,
            onTap: onCreateMatch,
          ),
          _QuickActionChip(
            icon: Icons.emoji_events_outlined,
            label: 'Tournaments',
            onTap: () => context.push('/tournaments'),
          ),
          _QuickActionChip(
            icon: Icons.groups_outlined,
            label: 'Teams',
            onTap: () => context.push('/teams'),
          ),
          _QuickActionChip(
            icon: Icons.person_outline,
            label: 'Players',
            onTap: () => context.push('/players'),
          ),
          _QuickActionChip(
            icon: Icons.sports_esports_outlined,
            label: 'Fantasy',
            onTap: () => context.push('/fantasy'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primaryBlueLight;
    return Padding(
      padding: const EdgeInsets.only(right: AppDimens.spaceSm),
      child: Material(
        color: AppColors.card,
        borderRadius: AppDimens.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDimens.cardRadius,
          child: Container(
            width: 96,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.spaceMd,
            ),
            decoration: BoxDecoration(
              borderRadius: AppDimens.cardRadius,
              border: Border.all(
                color: accent.withValues(alpha: color != null ? 0.5 : 0.25),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
