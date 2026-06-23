import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/auth/auth_gate.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/my_cricket_ui_provider.dart';
import '../../../../shared/providers/player_social_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../../../shared/widgets/tournament_list_card.dart';
import '../../my_cricket_filters.dart';
import '../widgets/my_cricket_action_banner.dart';

class MyCricketTournamentsTab extends ConsumerStatefulWidget {
  const MyCricketTournamentsTab({super.key});

  @override
  ConsumerState<MyCricketTournamentsTab> createState() =>
      _MyCricketTournamentsTabState();
}

class _MyCricketTournamentsTabState extends ConsumerState<MyCricketTournamentsTab> {
  MyCricketListScope _scope = MyCricketListScope.yours;

  void _registerTournament() {
    requireAuthVoid(
      context: context,
      ref: ref,
      returnPath: '/matches',
      action: () => context.push('/tournaments/create'),
    );
  }

  void _openTournament(TournamentModel tournament, String? uid) {
    if (uid != null && tournament.effectiveOrganizerId == uid) {
      context.push('/tournaments/${tournament.id}');
      return;
    }

    final role = uid == null
        ? TournamentRole.viewer
        : ref.read(tournamentMemberRoleProvider((tournament.id, uid)));
    if (role == TournamentRole.owner || role == TournamentRole.admin) {
      context.push('/tournaments/${tournament.id}');
      return;
    }

    context.push('/tournaments/${tournament.id}/join');
  }

  @override
  Widget build(BuildContext context) {
    final tournamentsAsync = ref.watch(tournamentsProvider);
    final search = ref.watch(myCricketSearchProvider);
    final uid = ref.watch(authStateProvider).value?.uid;
    final userTeams = ref.watch(teamsProvider).valueOrNull ?? [];
    final userTeamIds = userTeams.map((t) => t.id).toSet();
    final following = uid == null
        ? const <UserModel>[]
        : ref.watch(playerFollowingProvider(uid)).valueOrNull ?? [];
    final followedPlayers = FollowedPlayerRefs.fromUsers(following);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyCricketActionBanner(
          title: 'Want to host a tournament?',
          actionLabel: 'Register',
          onAction: _registerTournament,
        ),
        _scopeChips(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(tournamentsProvider),
            child: tournamentsAsync.when(
              data: (all) {
                var list = all
                    .where(
                      (t) => filterTournamentByScope(
                        t,
                        _scope,
                        uid: uid,
                        userTeamIds: userTeamIds,
                        followedPlayers: followedPlayers,
                      ),
                    )
                    .toList();

                if (search.isNotEmpty) {
                  final q = search.toLowerCase();
                  list = list
                      .where((t) => t.name.toLowerCase().contains(q))
                      .toList();
                }

                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 48),
                      Center(
                        child: Text(
                          search.isNotEmpty
                              ? 'No tournaments match your search'
                              : 'No tournaments in this filter',
                          style: TextStyle(color: context.cf.textSecondary),
                        ),
                      ),
                      if (search.isNotEmpty)
                        Center(
                          child: TextButton(
                            onPressed: () {
                              ref.read(myCricketSearchProvider.notifier).state =
                                  '';
                            },
                            child: const Text('Clear search'),
                          ),
                        ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final t = list[i];
                    return TournamentListCard(
                      tournament: t,
                      onTap: () => _openTournament(t, uid),
                      trailing: t.tournamentCode != null
                          ? Text(
                              t.tournamentCode!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: context.cf.accent),
                            )
                          : null,
                    );
                  },
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
