import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/widgets/location_filter_bar.dart';
import '../../../shared/widgets/tournament_list_card.dart';
import 'widgets/tournament_join_code_sheet.dart';

/// Tournament discovery — My / Participating / Nearby / Trending / Upcoming / Completed.
class TournamentDiscoveryScreen extends ConsumerStatefulWidget {
  const TournamentDiscoveryScreen({super.key});

  @override
  ConsumerState<TournamentDiscoveryScreen> createState() =>
      _TournamentDiscoveryScreenState();
}

class _TournamentDiscoveryScreenState
    extends ConsumerState<TournamentDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _filterCountry = '';
  String _filterCity = '';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        actions: [
          IconButton(
            tooltip: 'Join with code',
            icon: const Icon(Icons.qr_code_scanner_outlined),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const TournamentJoinCodeSheet(),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          onTap: (_) => setState(() {}),
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
      body: Column(
        children: [
          LocationFilterBar(
            initialCountry: _filterCountry,
            initialCity: _filterCity,
            onFilterChanged: (country, city) => setState(() {
              _filterCountry = country;
              _filterCity = city;
            }),
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
                      padding: const EdgeInsets.only(bottom: 88),
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
      ),
    );
  }
}

/// Legacy export — routes still import [TournamentScreen].
typedef TournamentScreen = TournamentDiscoveryScreen;
