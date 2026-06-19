import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/location_filter_bar.dart';
import '../../../../shared/widgets/tournament_list_card.dart';
import '../../my_cricket_filters.dart';
import '../widgets/my_cricket_action_banner.dart';

class MyCricketTournamentsTab extends ConsumerStatefulWidget {
  const MyCricketTournamentsTab({super.key});

  @override
  ConsumerState<MyCricketTournamentsTab> createState() =>
      _MyCricketTournamentsTabState();
}

class _MyCricketTournamentsTabState
    extends ConsumerState<MyCricketTournamentsTab> {
  MyCricketListScope _scope = MyCricketListScope.yours;
  String _country = '';
  String _city = '';

  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(tournamentsProvider);
    final search = ref.watch(myCricketSearchProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
    final userTeamIds = userTeams.map((t) => t.id).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyCricketActionBanner(
          title: 'Want to host a tournament?',
          actionLabel: 'Register',
          onAction: () => context.push('/tournaments'),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            0,
          ),
          child: Row(
            children: [
              _scopeChip('Your', MyCricketListScope.yours),
              const SizedBox(width: AppDimens.spaceXs),
              _scopeChip('Played', MyCricketListScope.played),
              const SizedBox(width: AppDimens.spaceXs),
              _scopeChip('All', MyCricketListScope.all),
            ],
          ),
        ),
        LocationFilterBar(
          onFilterChanged: (c, city) => setState(() {
            _country = c;
            _city = city;
          }),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(tournamentsProvider),
            child: tournamentsAsync.when(
              data: (all) {
                var list = all.where((t) {
                  if (!locationMatchesFilter(t.location, _country, _city)) {
                    return false;
                  }
                  return filterTournamentByScope(
                    t,
                    _scope,
                    uid: uid,
                    userTeamIds: userTeamIds,
                  );
                }).toList();

                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  list = list
                      .where((t) => t.name.toLowerCase().contains(q))
                      .toList();
                }

                if (list.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 48),
                      Center(child: Text('No tournaments in this filter')),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => TournamentListCard(
                    tournament: list[i],
                    onTap: () => context.push('/tournaments'),
                    trailing: TextButton(
                      onPressed: () => context.push('/tournaments'),
                      child: const Text('Manage'),
                    ),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scopeChip(String label, MyCricketListScope scope) {
    final cf = context.cf;
    final selected = _scope == scope;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _scope = scope),
      selectedColor: cf.accent.withValues(alpha: 0.15),
      checkmarkColor: cf.accent,
      labelStyle: TextStyle(
        color: selected ? cf.accent : cf.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
