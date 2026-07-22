import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../data/models/match_model.dart';
import '../../../shared/providers/my_player_provider.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../../my_cricket_profile/presentation/widgets/profile_match_filter_button.dart';
import '../my_cricket_filters.dart';
import 'tabs/my_cricket_highlights_tab.dart';
import 'tabs/my_cricket_matches_tab.dart';
import 'tabs/my_cricket_stats_tab.dart';
import 'tabs/my_cricket_teams_tab.dart';
import 'tabs/my_cricket_tournaments_tab.dart';

/// Unified My Cricket hub: Matches · Tournaments · Teams · Stats (one screen).
class MyCricketScreen extends ConsumerStatefulWidget {
  const MyCricketScreen({super.key});

  @override
  ConsumerState<MyCricketScreen> createState() => _MyCricketScreenState();
}

class _MyCricketScreenState extends ConsumerState<MyCricketScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  var _routeTabApplied = false;

  void _onTabChanged() {
    if (_tabs.index == 2) {
      ref.read(teamsTabVisitCounterProvider.notifier).state++;
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _applyPendingTab(int tab) {
    if (tab < 0 || tab >= _tabs.length) return;
    if (_tabs.index != tab) {
      _tabs.animateTo(tab);
    }
    ref.read(myCricketInitialTabProvider.notifier).state = -1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeTabApplied) return;
    _routeTabApplied = true;
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    final index = int.tryParse(tab ?? '');
    if (index != null && index >= 0 && index < _tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyPendingTab(index);
      });
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(myCricketInitialTabProvider, (previous, next) {
      _applyPendingTab(next);
    });

    final pendingTab = ref.watch(myCricketInitialTabProvider);
    if (pendingTab >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyPendingTab(pendingTab);
      });
    }

    final cf = context.cf;
    final uid = ref.watch(authStateProvider).value?.uid;
    final isGuest = uid == null;
    final canCreate = !isGuest &&
        canCreateMatches(
          ref.watch(currentUserProfileProvider).valueOrNull?.role ??
              UserRole.organizer,
        );

    final player = ref.watch(myPlayerProvider).valueOrNull;
    final matches = ref.watch(matchesProvider).valueOrNull ?? [];
    final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
    final userTeamIds = userTeams.map((t) => t.id).toSet();
    final participated = uid == null
        ? const <MatchModel>[]
        : matches
            .where(
              (m) => userParticipatedInMatch(
                m,
                uid: uid,
                player: player,
                userTeamIds: userTeamIds,
              ),
            )
            .toList();

    return ShellTabScaffold(
      title: const Text('My Cricket'),
      actions: [
        if (!isGuest && (_tabs.index == 0 || _tabs.index == 3))
          ProfileMatchFilterButton(
            matches: participated,
            iconOnly: true,
          ),
        if (_tabs.index == 0 || _tabs.index == 1)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => _showSearch(context),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: cf.accent,
          labelColor: cf.accent,
          unselectedLabelColor: cf.textSecondary,
          dividerColor: cf.border,
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Tournaments'),
            Tab(text: 'Teams'),
            Tab(text: 'Stats'),
            Tab(text: 'Highlights'),
          ],
        ),
      ),
      floatingActionButton: isGuest
          ? null
          : switch (_tabs.index) {
              0 when canCreate => FloatingActionButton.extended(
                  heroTag: 'my_cricket_start_match_fab',
                  onPressed: () => context.push('/match/create'),
                  backgroundColor: cf.fabBackground,
                  foregroundColor: cf.fabForeground,
                  icon: const Icon(Icons.sports_cricket),
                  label: const Text('Start match'),
                ),
              1 => FloatingActionButton.extended(
                  heroTag: 'my_cricket_create_tournament_fab',
                  onPressed: () => requireAuthVoid(
                    context: context,
                    ref: ref,
                    returnPath: '/matches',
                    action: () => context.push('/tournaments/create'),
                  ),
                  backgroundColor: cf.fabBackground,
                  foregroundColor: cf.fabForeground,
                  icon: const Icon(Icons.app_registration_outlined),
                  label: const Text('Register'),
                ),
              _ => null,
            },
      body: TabBarView(
        controller: _tabs,
        children: const [
          MyCricketMatchesTab(),
          MyCricketTournamentsTab(),
          MyCricketTeamsTab(),
          MyCricketStatsTab(),
          MyCricketHighlightsTab(),
        ],
      ),
    );
  }

  Future<void> _showSearch(BuildContext context) async {
    final current = ref.read(myCricketSearchProvider);
    final controller = TextEditingController(text: current);
    final hints = [
      'Team or match name',
      'Tournament name',
      'Team name',
      'Your stats',
      'Completed matches',
    ];
    final hint = hints[_tabs.index.clamp(0, hints.length - 1)];

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != null) {
      ref.read(myCricketSearchProvider.notifier).state = result.trim();
    }
  }
}
