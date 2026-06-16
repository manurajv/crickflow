import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/team_ui_provider.dart';
import '../../../teams/presentation/utils/teams_list_filter.dart';
import '../../../teams/presentation/widgets/team_list_scope.dart';
import '../../../teams/presentation/widgets/team_list_tile.dart';
import '../../../teams/presentation/widgets/teams_list_toolbar.dart';

class MyCricketTeamsTab extends ConsumerStatefulWidget {
  const MyCricketTeamsTab({super.key});

  @override
  ConsumerState<MyCricketTeamsTab> createState() => _MyCricketTeamsTabState();
}

class _MyCricketTeamsTabState extends ConsumerState<MyCricketTeamsTab> {
  TeamListScope _scope = TeamListScope.yours;
  String _search = '';
  String _country = '';
  String _city = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null && !profile.location.isEmpty) {
        setState(() {
          _country = profile.location.country;
          _city = profile.location.city;
        });
      }
    });
  }

  void _openCreateTeam() {
    ref.read(teamsInitialTabProvider.notifier).state = 1;
    context.push('/teams?tab=1');
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(allTeamsProvider);
    final uid = ref.watch(authStateProvider).value?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surfaceElevated,
          child: ListTile(
            dense: true,
            title: const Text('Want to create a team?'),
            trailing: FilledButton(
              onPressed: _openCreateTeam,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Create'),
            ),
          ),
        ),
        TeamsSearchBar(
          query: _search,
          debounceMs: 0,
          onChanged: (v) => setState(() => _search = v),
        ),
        TeamsScopeFilterBar(
          scope: _scope,
          country: _country,
          city: _city,
          onScopeChanged: (s) => setState(() => _scope = s),
          onLocationChanged: (c, city) => setState(() {
            _country = c;
            _city = city;
          }),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(allTeamsProvider),
            child: teamsAsync.when(
              data: (allTeams) {
                var list = TeamsListFilter.apply(
                  teams: allTeams,
                  query: _search,
                  country: _country,
                  city: _city,
                  uid: uid,
                  yoursOnly: _scope == TeamListScope.yours && uid != null,
                  opponentsOnly:
                      _scope == TeamListScope.opponents && uid != null,
                );

                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _EmptyTeamsState(
                        scope: _scope,
                        hasFilters: _search.isNotEmpty ||
                            _country.isNotEmpty ||
                            _city.isNotEmpty,
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
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) =>
                      TeamListTile(team: list[index]),
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
    final (title, subtitle) = hasFilters
        ? (
            'No teams match your filters',
            'Try a different scope, location, or search term',
          )
        : switch (scope) {
            TeamListScope.yours => (
                'No teams yet',
                'Create a team to add players and join matches',
              ),
            TeamListScope.opponents => (
                'No opponent teams',
                'Teams you have not joined will appear here',
              ),
            TeamListScope.all => (
                'No teams found',
                'Teams registered on CrickFlow will show here',
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
            color: AppColors.textSecondary.withValues(alpha: 0.45),
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
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasFilters && scope == TeamListScope.yours) ...[
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Create team'),
            ),
          ],
        ],
      ),
    );
  }
}
