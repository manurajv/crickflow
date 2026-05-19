import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/providers/providers.dart';
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
    final role = profileAsync.valueOrNull?.role ?? UserRole.viewer;
    final canCreate = canCreateMatches(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CrickFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(matchesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  profileAsync.when(
                    data: (p) => Text(
                      'Welcome, ${p?.displayName ?? 'Scorer'}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    loading: () => const Text('Welcome'),
                    error: (_, __) => const Text('Welcome'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create matches, score live, and stream to your fans.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!canCreate)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ListTile(
                  leading: Icon(
                    role == UserRole.player ? Icons.sports : Icons.visibility,
                    color: AppColors.gold,
                  ),
                  title: Text(
                    role == UserRole.player
                        ? 'Player mode'
                        : 'Viewer mode',
                  ),
                  subtitle: Text(
                    role == UserRole.player
                        ? 'Browse matches and squads. Scoring is for organizers.'
                        : 'Browse live scores and scorecards.',
                  ),
                  trailing: role == UserRole.player
                      ? TextButton(
                          onPressed: () => context.push('/players'),
                          child: const Text('My squads'),
                        )
                      : null,
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Recent Matches',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            matchesAsync.when(
              data: (matches) {
                if (matches.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
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
                    padding: EdgeInsets.all(32),
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
                                  left: 16, right: 16, bottom: 8),
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
                padding: const EdgeInsets.all(16),
                child: Text('Error loading matches: $e'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/match/create'),
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('New Match'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              break;
            case 1:
              context.push('/tournaments');
            case 2:
              context.push('/teams');
            case 3:
              context.push('/analytics');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events), label: 'Tournaments'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Teams'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Stats'),
        ],
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
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
    );
  }

  Widget _actionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryBlueLight, size: 32),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
