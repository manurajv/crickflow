import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../../../shared/widgets/location_filter_bar.dart';
import '../../../shared/widgets/scoreboard_card.dart';

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
    final profileAsync = ref.watch(currentUserProfileProvider);
    final role = profileAsync.valueOrNull?.role ?? UserRole.organizer;
    final isViewer = role == UserRole.viewer;
    final canCreate = canCreateMatches(role);

    return ShellTabScaffold(
      title: const Text('CrickFlow'),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/match/create'),
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('New Match'),
            )
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.push('/notifications'),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(matchesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            Container(
              margin: const EdgeInsets.all(AppDimens.spaceMd),
              padding: AppDimens.cardPadding,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: AppDimens.cardRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  profileAsync.when(
                    data: (p) => Text(
                      'Welcome, ${p?.displayName ?? 'Scorer'}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                    loading: () => const Text('Welcome'),
                    error: (_, __) => const Text('Welcome'),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    'Create matches, score live, and stream to your fans.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (isViewer)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
                child: ListTile(
                  leading: const Icon(Icons.visibility, color: AppColors.gold),
                  title: const Text('Viewer mode'),
                  subtitle: const Text(
                    'Browse live scores and scorecards. Change mode in Profile.',
                  ),
                  trailing: TextButton(
                    onPressed: () => context.push('/profile'),
                    child: const Text('Profile'),
                  ),
                ),
              ),
            if (canCreate) _quickActions(context),
            LocationFilterBar(
              onFilterChanged: (country, city) {
                setState(() {
                  _filterCountry = country;
                  _filterCity = city;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceSm,
                AppDimens.spaceMd,
                AppDimens.spaceSm,
              ),
              child: Text(
                'Recent Matches',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            matchesAsync.when(
              data: (matches) {
                if (matches.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppDimens.spaceXl),
                    child: Center(
                      child: Text('No matches yet. Create your first match!'),
                    ),
                  );
                }
                final filtered = matches.where((m) {
                  return locationMatchesFilter(
                    m.location,
                    _filterCountry,
                    _filterCity,
                  );
                }).toList();

                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppDimens.spaceXl),
                    child: Center(child: Text('No matches match your filters.')),
                  );
                }

                return Column(
                  children: filtered.take(10).map((m) {
                    final isLive = m.status == MatchStatus.live;
                    return GestureDetector(
                      onTap: () => context.push('/match/${m.id}'),
                      child: Column(
                        children: [
                          ScoreboardCard(
                            match: m,
                            innings: m.currentInnings,
                            isLive: isLive,
                          ),
                          if (m.scheduledAt != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppDimens.spaceMd,
                                right: AppDimens.spaceMd,
                                bottom: AppDimens.spaceSm,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  AppDateUtils.formatShort(m.scheduledAt!),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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

  Widget _quickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  context,
                  'Single Match',
                  Icons.sports_cricket,
                  () => context.push('/match/create'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionCard(
                  context,
                  'Tournament',
                  Icons.emoji_events,
                  () => context.push('/tournaments'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            children: [
              Expanded(
                child: _actionCard(
                  context,
                  'Teams',
                  Icons.groups,
                  () => context.push('/teams'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionCard(
                  context,
                  'Players',
                  Icons.person,
                  () => context.push('/players'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _actionCard(
            context,
            'Fantasy Cricket',
            Icons.sports_esports,
            () => context.push('/fantasy'),
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool fullWidth = false,
  }) {
    final card = Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimens.cardRadius,
        child: Padding(
          padding: AppDimens.cardPadding,
          child: fullWidth
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.primaryBlueLight, size: AppDimens.iconLg),
                    const SizedBox(width: AppDimens.spaceMd),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                )
              : Column(
                  children: [
                    Icon(icon, color: AppColors.primaryBlueLight, size: AppDimens.iconLg),
                    const SizedBox(height: AppDimens.spaceSm),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
        ),
      ),
    );
    return fullWidth ? card : Expanded(child: card);
  }
}
