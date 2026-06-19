import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/match_permissions.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/player_model.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/my_player_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/match_list_card.dart';
import '../../../teams/presentation/utils/teams_list_filter.dart';
import '../../my_cricket_filters.dart';
import '../widgets/my_cricket_action_banner.dart';

class MyCricketMatchesTab extends ConsumerStatefulWidget {
  const MyCricketMatchesTab({super.key});

  @override
  ConsumerState<MyCricketMatchesTab> createState() =>
      _MyCricketMatchesTabState();
}

class _MyCricketMatchesTabState extends ConsumerState<MyCricketMatchesTab> {
  MyCricketListScope _scope = MyCricketListScope.yours;

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(matchesProvider);
    final search = ref.watch(myCricketSearchProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final player = ref.watch(myPlayerProvider).valueOrNull;
    final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
    final userTeamIds = userTeams.map((t) => t.id).toSet();
    final memberTeamIds = TeamsListFilter.memberTeamIds(
      teams: userTeams,
      uid: uid,
      player: player,
    );
    final networkTeamIds = TeamsListFilter.opponentTeamIds(
      matches: matchesAsync.valueOrNull ?? [],
      memberTeamIds: memberTeamIds,
    );
    final canCreate = canCreateMatches(
      ref.watch(currentUserProfileProvider).valueOrNull?.role ??
          UserRole.organizer,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCreate)
          MyCricketActionBanner(
            title: 'Want to start a match?',
            actionLabel: 'Start',
            onAction: () => context.push('/match/create'),
          ),
        _scopeChips(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(matchesProvider),
            child: matchesAsync.when(
              data: (matches) {
                var list = _filter(
                  matches,
                  uid: uid,
                  player: player,
                  userTeamIds: userTeamIds,
                  networkTeamIds: networkTeamIds,
                );
                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  list = list
                      .where(
                        (m) =>
                            m.title.toLowerCase().contains(q) ||
                            m.teamAName.toLowerCase().contains(q) ||
                            m.teamBName.toLowerCase().contains(q),
                      )
                      .toList();
                }
                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      MatchListEmptyState(
                        message: 'No matches found',
                        onCreateMatch: canCreate
                            ? () => context.push('/match/create')
                            : null,
                        onClearFilters: search.isNotEmpty
                            ? () {
                                ref
                                    .read(myCricketSearchProvider.notifier)
                                    .state = '';
                              }
                            : null,
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => MatchListCard(match: list[i]),
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

  Widget _scopeChips(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          _scopeChip(context, 'Your', MyCricketListScope.yours),
          const SizedBox(width: AppDimens.spaceXs),
          _scopeChip(context, 'Played', MyCricketListScope.played),
          const SizedBox(width: AppDimens.spaceXs),
          _scopeChip(context, 'Network', MyCricketListScope.network),
          const SizedBox(width: AppDimens.spaceXs),
          _scopeChip(context, 'All', MyCricketListScope.all),
        ],
      ),
    );
  }

  List<MatchModel> _filter(
    List<MatchModel> matches, {
    String? uid,
    PlayerModel? player,
    required Set<String> userTeamIds,
    required Set<String> networkTeamIds,
  }) {
    return matches
        .where(
          (m) => filterMatchByScope(
            m,
            _scope,
            uid: uid,
            player: player,
            userTeamIds: userTeamIds,
            networkTeamIds: networkTeamIds,
          ),
        )
        .toList();
  }

  Widget _scopeChip(
    BuildContext context,
    String label,
    MyCricketListScope scope,
  ) {
    final cf = context.cf;
    final selected = _scope == scope;
    return Material(
      color: selected ? cf.accent : cf.sectionBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => setState(() => _scope = scope),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? cf.onAccent : cf.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
