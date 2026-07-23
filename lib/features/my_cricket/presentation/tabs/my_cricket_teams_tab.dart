import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/cf_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/location_filter_selection.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../teams/presentation/utils/teams_list_filter.dart';
import '../../../teams/presentation/widgets/team_list_scope.dart';
import '../../../teams/presentation/widgets/team_list_tile.dart';
import '../../../teams/presentation/widgets/teams_list_toolbar.dart';
import '../widgets/my_cricket_action_banner.dart';
import '../widgets/my_cricket_guest_sign_in_prompt.dart';

class MyCricketTeamsTab extends ConsumerStatefulWidget {
  const MyCricketTeamsTab({super.key});

  @override
  ConsumerState<MyCricketTeamsTab> createState() => _MyCricketTeamsTabState();
}

class _MyCricketTeamsTabState extends ConsumerState<MyCricketTeamsTab> {
  TeamListScope _scope = TeamListScope.yours;
  String _search = '';
  List<LocationFilterSelection> _locations = const [];

  @override
  void initState() {
    super.initState();
    _resetLocationFilters();
  }

  void _resetLocationFilters() {
    setState(() {
      _locations = const [];
      _scope = TeamListScope.yours;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(teamsTabVisitCounterProvider, (previous, next) {
      if (next > (previous ?? 0)) {
        _resetLocationFilters();
      }
    });

    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) {
      return const MyCricketGuestSignInPrompt(
        title: 'Sign in to view your teams',
        subtitle:
            'Sign in with a CrickFlow account to see teams you belong to '
            'and opponents you have played.',
      );
    }

    final teamsAsync = ref.watch(allTeamsProvider);
    final matchesAsync = ref.watch(matchesProvider);
    final player = ref.watch(myPlayerProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyCricketActionBanner(
          title: 'Want to create a team?',
          actionLabel: 'Create',
          onAction: _openCreateTeam,
        ),
        TeamsScopeFilterBar(
          scope: _scope,
          locations: _locations,
          onScopeChanged: (s) => setState(() => _scope = s),
          onLocationsChanged: (locs) => setState(() => _locations = locs),
        ),
        TeamsSearchBar(
          query: _search,
          debounceMs: 0,
          onChanged: (v) => setState(() => _search = v),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(allTeamsProvider),
            child: teamsAsync.when(
              data: (allTeams) {
                final memberIds = TeamsListFilter.memberTeamIds(
                  teams: allTeams,
                  uid: uid,
                  player: player,
                );
                final opponentIds = TeamsListFilter.opponentTeamIds(
                  matches: matchesAsync.valueOrNull ?? [],
                  memberTeamIds: memberIds,
                );
                var list = TeamsListFilter.apply(
                  teams: allTeams,
                  scope: _scope,
                  query: _search,
                  locations: _locations,
                  memberTeamIds: memberIds,
                  opponentTeamIds: opponentIds,
                );

                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _EmptyTeamsState(
                        scope: _scope,
                        hasFilters: _search.isNotEmpty || _locations.isNotEmpty,
                        onCreate: _openCreateTeam,
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: AppDimens.spaceLg),
                  itemCount: list.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: context.cf.border),
                  itemBuilder: (context, index) => TeamListTile(
                        team: list[index],
                        listScope: _scope,
                        memberTeamIds: memberIds,
                      ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                  Center(child: Text('$e')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openCreateTeam() {
    context.push('/teams/create');
  }
}

class _EmptyTeamsState extends StatelessWidget {
  const _EmptyTeamsState({
    required this.scope,
    required this.hasFilters,
    required this.onCreate,
  });

  final TeamListScope scope;
  final bool hasFilters;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cf = context.cf;
    final (title, subtitle) = hasFilters
        ? (
            'No teams match your filters',
            'Try a different scope, location, or search term',
          )
        : switch (scope) {
            TeamListScope.yours => (
                'No teams yet',
                'Teams you join will appear here',
              ),
            TeamListScope.opponents => (
                'No opponent teams',
                'Teams your squad has played against will appear here',
              ),
            TeamListScope.all => (
                'No teams found',
                'Registered teams on CrickFlow will show here',
              ),
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
            color: cf.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cf.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasFilters && scope == TeamListScope.yours) ...[
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: cf.accent,
                foregroundColor: cf.onAccent,
              ),
              child: const Text('Create team'),
            ),
          ],
        ],
      ),
    );
  }
}
