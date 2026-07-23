import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/location_filter_selection.dart';
import '../../../shared/providers/my_player_provider.dart';
import '../../../shared/providers/notification_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/team_ui_provider.dart';
import 'utils/teams_list_filter.dart';
import 'widgets/create_team_form.dart';
import 'widgets/team_list_scope.dart';
import 'widgets/team_list_tile.dart';
import 'widgets/teams_list_toolbar.dart';

/// Teams hub: list + create.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  TeamListScope _scope = TeamListScope.yours;
  String _query = '';
  List<LocationFilterSelection> _locations = const [];

  @override
  void initState() {
    super.initState();
    _resetFilters();
    final tab = _resolveTabIndex(widget.initialTab);
    _tabs = TabController(length: 2, vsync: this, initialIndex: tab);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teamsTabVisitCounterProvider.notifier).state++;
      final pending = ref.read(teamsInitialTabProvider);
      if (pending > 0) {
        _tabs.animateTo(pending.clamp(0, 1));
        ref.read(teamsInitialTabProvider.notifier).state = 0;
      }
    });
  }

  void _resetFilters() {
    _scope = TeamListScope.yours;
    _query = '';
    _locations = const [];
  }

  /// tab=1 create, tab=2 legacy create alias.
  static int _resolveTabIndex(int tab) {
    if (tab >= 1) return 1;
    return 0;
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onAddTab = _tabs.index == 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text(onAddTab ? 'Create team' : 'Teams'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textSecondary,
          dividerColor: AppColors.border,
          tabs: const [
            Tab(text: 'Teams'),
            Tab(text: 'Add'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TeamsBrowseTab(
            scope: _scope,
            query: _query,
            locations: _locations,
            onScopeChanged: (s) => setState(() => _scope = s),
            onSearchChanged: (v) => setState(() => _query = v),
            onLocationsChanged: (locs) => setState(() => _locations = locs),
          ),
          CreateTeamForm(onCreated: (_) => _tabs.animateTo(0)),
        ],
      ),
    );
  }
}

class _TeamsBrowseTab extends ConsumerWidget {
  const _TeamsBrowseTab({
    required this.scope,
    required this.query,
    required this.locations,
    required this.onScopeChanged,
    required this.onSearchChanged,
    required this.onLocationsChanged,
  });

  final TeamListScope scope;
  final String query;
  final List<LocationFilterSelection> locations;
  final ValueChanged<TeamListScope> onScopeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<List<LocationFilterSelection>> onLocationsChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(allTeamsProvider);
    final matchesAsync = ref.watch(matchesProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final player = ref.watch(myPlayerProvider).valueOrNull;

    return teamsAsync.when(
      data: (teams) {
        final memberIds = TeamsListFilter.memberTeamIds(
          teams: teams,
          uid: uid,
          player: player,
        );
        final opponentIds = TeamsListFilter.opponentTeamIds(
          matches: matchesAsync.valueOrNull ?? [],
          memberTeamIds: memberIds,
        );
        final list = TeamsListFilter.apply(
          teams: teams,
          scope: scope,
          query: query,
          locations: locations,
          memberTeamIds: memberIds,
          opponentTeamIds: opponentIds,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TeamsScopeFilterBar(
              scope: scope,
              locations: locations,
              onScopeChanged: onScopeChanged,
              onLocationsChanged: onLocationsChanged,
            ),
            TeamsSearchBar(query: query, onChanged: onSearchChanged),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(allTeamsProvider),
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          _EmptyList(
                            scope: scope,
                            hasFilters:
                                query.isNotEmpty || locations.isNotEmpty,
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          bottom: AppDimens.spaceLg,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) => TeamListTile(
                              team: list[index],
                              listScope: scope,
                              memberTeamIds: memberIds,
                            ),
                      ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.scope, required this.hasFilters});

  final TeamListScope scope;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final message = hasFilters
        ? 'No teams match your filters'
        : switch (scope) {
            TeamListScope.yours => 'No teams yet — join or create a team',
            TeamListScope.opponents =>
              'No opponent teams — play a match to see opponents here',
            TeamListScope.all => 'No teams registered yet',
          };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceXl,
        56,
        AppDimens.spaceXl,
        AppDimens.spaceXl,
      ),
      child: Column(
        children: [
          Icon(
            Icons.groups_outlined,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
