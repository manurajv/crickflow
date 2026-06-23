import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/navigation/tournament_join_navigation.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/widgets/tournament_list_card.dart';

/// Shared tournaments list with discovery tabs (My / Participating / …).
class TournamentDiscoveryPanel extends ConsumerStatefulWidget {
  const TournamentDiscoveryPanel({
    super.key,
    this.bottomPadding = 88,
  });

  final double bottomPadding;
  @override
  ConsumerState<TournamentDiscoveryPanel> createState() =>
      _TournamentDiscoveryPanelState();
}

class _TournamentDiscoveryPanelState
    extends ConsumerState<TournamentDiscoveryPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  static const _tabLabels = [
    'My Tournaments',
    'Participating',
    'Nearby',
    'Trending',
    'Upcoming',
    'Completed',
  ];

  static const _tabValues = [
    TournamentDiscoveryTab.myTournaments,
    TournamentDiscoveryTab.participating,
    TournamentDiscoveryTab.nearby,
    TournamentDiscoveryTab.trending,
    TournamentDiscoveryTab.upcoming,
    TournamentDiscoveryTab.completed,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final tab = _tabValues[_tabs.index];
    final list = ref.watch(filteredTournamentsProvider(tab));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: cf.accent,
          labelColor: cf.accent,
          unselectedLabelColor: cf.textSecondary,
          dividerColor: cf.border,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          onTap: (_) => setState(() {}),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(tournamentsProvider),
            child: list.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 64),
                      Center(
                        child: Text(
                          'No tournaments here yet',
                          style: TextStyle(color: cf.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(bottom: widget.bottomPadding),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final t = list[i];
                      return TournamentListCard(
                        tournament: t,
                        onTap: () => context.push('/tournaments/${t.id}'),
                        trailing: t.tournamentCode != null
                            ? Text(
                                t.tournamentCode!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: cf.accent),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen tournaments discovery.
class TournamentDiscoveryScreen extends ConsumerWidget {
  const TournamentDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              goToMyCricketTournamentsTab(ref, context);
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => requireAuthVoid(
          context: context,
          ref: ref,
          returnPath: '/tournaments',
          action: () => context.push('/tournaments/create'),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: const TournamentDiscoveryPanel(),
    );
  }
}

/// Legacy export — routes still import [TournamentScreen].
typedef TournamentScreen = TournamentDiscoveryScreen;
